// launchbench — black-box launch benchmarks for macOS apps.
//
// Measures any app the same way, with no cooperation from it:
//   • time to window (TTW): launch → first on-screen window of "main" size
//   • time to first content (TFC): launch → first frame with real content
//     (luminance contrast above a flat splash/spinner screen)
//   • time to visually complete (TVC): launch → last change touching ≥6% of
//     the window before it holds still for --quiet-ms with content showing
//     (small perpetual animations and spinners are ignored)
//
//   Frames come from a 60 fps ScreenCaptureKit recording of the display that
//   starts *before* each launch and filters out every other app (and the Dock's
//   wallpaper), so the app under test is recorded alone on black with no
//   capture set-up delay. Each frame is cropped to the app's main window.
//   • memory: summed `footprint` of the app's processes plus every process
//     macOS attributes to it (e.g. WebKit helpers behind a WKWebView)
//
// Modes
//   cold     quit the app completely, launch it, measure TTW + TVC + memory
//   reopen   app running with its window closed → Dock-style reopen
//   click    click a text label found by OCR (e.g. "LIBRARY") → measure TVC
//
// Build:  swiftc -O launchbench.swift -o launchbench
// Usage:  launchbench cold --app /Applications/Steam.app \
//           --match "~/Library/Application Support/Steam/Steam.AppBundle" \
//           --label steam --runs 10 --out results.jsonl --frames frames/

import AppKit
import ApplicationServices
import CoreGraphics
import Darwin
import Foundation
import CoreMedia
import ScreenCaptureKit
import VideoToolbox
import Vision

// MARK: - Options

struct Options {
    var mode = "cold"
    var app = ""
    var label = ""
    var matches: [String] = []
    var args: [String] = []
    var runs = 5
    var out: String?
    var frames: String?
    var quietMs = 2500.0
    var timeoutS = 30.0
    var minChange = 0.06
    var minContrast = 22.0
    var minWindow = CGSize(width: 700, height: 450)
    var cooldownS = 4.0
    var settleS = 6.0
    var clickText: [String] = []
    var quitURL: String?
    var allFrames = false

    static func parse() -> Options {
        var o = Options()
        var it = CommandLine.arguments.dropFirst().makeIterator()
        o.mode = it.next() ?? "cold"
        while let a = it.next() {
            func next() -> String { it.next() ?? "" }
            switch a {
            case "--app": o.app = expand(next())
            case "--label": o.label = next()
            case "--match": o.matches.append(expand(next()))
            case "--arg": o.args.append(next())
            case "--runs": o.runs = Int(next()) ?? 5
            case "--out": o.out = expand(next())
            case "--frames": o.frames = expand(next())
            case "--quiet-ms": o.quietMs = Double(next()) ?? 2500
            case "--timeout": o.timeoutS = Double(next()) ?? 30
            case "--min-change": o.minChange = Double(next()) ?? 0.06
            case "--min-contrast": o.minContrast = Double(next()) ?? 22
            case "--cooldown": o.cooldownS = Double(next()) ?? 4
            case "--settle": o.settleS = Double(next()) ?? 6
            case "--click-text": o.clickText.append(next())
            case "--quit-url": o.quitURL = next()
            case "--all-frames": o.allFrames = true   // debug: save every captured frame
            case "--min-window":
                let p = next().split(separator: "x").compactMap { Double($0) }
                if p.count == 2 { o.minWindow = CGSize(width: p[0], height: p[1]) }
            default: fail("unknown argument \(a)")
            }
        }
        if o.app.isEmpty { fail("--app is required") }
        if o.matches.isEmpty { o.matches = [o.app] }
        if o.label.isEmpty { o.label = URL(fileURLWithPath: o.app).deletingPathExtension().lastPathComponent }
        return o
    }
}

func expand(_ p: String) -> String { (p as NSString).expandingTildeInPath }
func fail(_ msg: String) -> Never {
    FileHandle.standardError.write(Data("launchbench: \(msg)\n".utf8))
    exit(2)
}
func log(_ msg: String) { FileHandle.standardError.write(Data("\(msg)\n".utf8)) }

// MARK: - Clock

func nowMs() -> Double { Double(DispatchTime.now().uptimeNanoseconds) / 1_000_000 }
func sleepMs(_ ms: Double) { usleep(useconds_t(max(0, ms) * 1000)) }

// MARK: - Processes

/// Every pid whose executable lives under one of the match prefixes.
func appPids(_ prefixes: [String]) -> [pid_t] {
    let count = proc_listallpids(nil, 0)
    var pids = [pid_t](repeating: 0, count: Int(count) * 2)
    let n = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.size))
    var out: [pid_t] = []
    var buf = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
    for pid in pids.prefix(Int(n)) where pid > 0 {
        let len = proc_pidpath(pid, &buf, UInt32(buf.count))
        guard len > 0 else { continue }
        let path = String(cString: buf)
        if prefixes.contains(where: { path.hasPrefix($0) }) { out.append(pid) }
    }
    return out
}

/// macOS attributes helper processes (e.g. WebKit's WebContent/GPU/Networking
/// XPC services behind a WKWebView) to the app that caused them. This is what
/// Activity Monitor uses to group them under the app.
private let responsibleFor: (@convention(c) (pid_t) -> pid_t)? = {
    guard let sym = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "responsibility_get_pid_responsible_for_pid")
    else { return nil }
    return unsafeBitCast(sym, to: (@convention(c) (pid_t) -> pid_t).self)
}()

/// The app's own processes plus every process it is responsible for.
func attributedPids(_ prefixes: [String]) -> [pid_t] {
    let own = Set(appPids(prefixes))
    guard let responsibleFor, !own.isEmpty else { return Array(own) }
    let count = proc_listallpids(nil, 0)
    var pids = [pid_t](repeating: 0, count: Int(count) * 2)
    let n = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.size))
    var out = own
    for pid in pids.prefix(Int(n)) where pid > 0 && own.contains(responsibleFor(pid)) { out.insert(pid) }
    return Array(out)
}

func quitApp(_ o: Options) {
    var pids = appPids(o.matches)
    guard !pids.isEmpty else { return }
    if let url = o.quitURL, let u = URL(string: url) {
        NSWorkspace.shared.open(u)
    } else {
        for pid in pids { NSRunningApplication(processIdentifier: pid)?.terminate() }
    }
    let deadline = nowMs() + 12_000
    while nowMs() < deadline {
        pids = appPids(o.matches)
        if pids.isEmpty { return }
        sleepMs(200)
    }
    log("  [\(o.label)] graceful quit timed out; killing \(pids)")
    for pid in pids { kill(pid, SIGKILL) }
    sleepMs(1000)
}

/// Summed physical footprint (MiB) and process count, via /usr/bin/footprint.
func footprintMiB(_ pids: [pid_t]) -> (Double, Int) {
    guard !pids.isEmpty else { return (0, 0) }
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/footprint")
    p.arguments = pids.flatMap { ["-p", String($0)] } + ["-f", "bytes"]
    let pipe = Pipe()
    p.standardOutput = pipe
    p.standardError = Pipe()
    try? p.run()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    let text = String(decoding: data, as: UTF8.self)
    var total = 0.0
    var procs = 0
    let re = try! NSRegularExpression(pattern: #"\[(\d+)\]: \d+-bit\s+Footprint: (\d+) B"#)
    for m in re.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
        if let r = Range(m.range(at: 2), in: text), let b = Double(text[r]) {
            total += b
            procs += 1
        }
    }
    return (total / 1_048_576, procs)
}

// MARK: - Windows

struct Win {
    let id: CGWindowID
    let pid: pid_t
    let bounds: CGRect
}

func appWindows(_ pids: Set<pid_t>) -> [Win] {
    guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
        as? [[String: Any]] else { return [] }
    return list.compactMap { w in
        guard let pid = w[kCGWindowOwnerPID as String] as? pid_t, pids.contains(pid),
              (w[kCGWindowLayer as String] as? Int) == 0,
              (w[kCGWindowAlpha as String] as? Double ?? 1) > 0.5,
              let b = w[kCGWindowBounds as String] as? [String: Double],
              let id = w[kCGWindowNumber as String] as? CGWindowID
        else { return nil }
        return Win(id: id, pid: pid, bounds: CGRect(x: b["X"] ?? 0, y: b["Y"] ?? 0,
                                                     width: b["Width"] ?? 0, height: b["Height"] ?? 0))
    }
}

func mainWindow(_ o: Options, _ pids: Set<pid_t>) -> Win? {
    appWindows(pids)
        .filter { $0.bounds.width >= o.minWindow.width && $0.bounds.height >= o.minWindow.height }
        .max { $0.bounds.width * $0.bounds.height < $1.bounds.width * $1.bounds.height }
}

// MARK: - Capture

final class Capturer {
    private var filter: SCContentFilter?
    private var filterWindow: CGWindowID = 0

    func capture(_ win: Win, width: Int) async -> CGImage? {
        if filterWindow != win.id || filter == nil {
            guard let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true),
                  let w = content.windows.first(where: { $0.windowID == win.id }) else { return nil }
            filter = SCContentFilter(desktopIndependentWindow: w)
            filterWindow = win.id
        }
        let cfg = SCStreamConfiguration()
        cfg.width = width
        cfg.height = max(1, Int(Double(width) * win.bounds.height / max(1, win.bounds.width)))
        cfg.showsCursor = false
        return try? await SCScreenshotManager.captureImage(contentFilter: filter!, configuration: cfg)
    }
}

/// Records the main display continuously (60 fps, only changed frames are
/// delivered) from *before* the app is launched, so there's no capture set-up
/// delay once its window appears. Frames are cropped to the app's window.
final class DisplayRecorder: NSObject, SCStreamOutput, @unchecked Sendable {
    private var stream: SCStream?
    private let queue = DispatchQueue(label: "launchbench.frames")
    private let lock = NSLock()
    private var buffer: CVPixelBuffer?
    private var bufferTime = 0.0
    private(set) var seq = 0
    private(set) var displayFrame = CGRect.zero

    /// Starts recording the main display with every *other* app filtered out
    /// (including the Dock, which draws the wallpaper), so only the app under
    /// test is visible, on black. Apps launched after this are captured.
    func start(isolating prefixes: [String]) async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            guard let display = content.displays.first(where: { $0.displayID == CGMainDisplayID() }) ?? content.displays.first
            else { fail("no display to record") }
            let target = Set(attributedPids(prefixes))
            let others = content.applications.filter { !target.contains($0.processID) }
            displayFrame = display.frame
            let cfg = SCStreamConfiguration()
            cfg.width = Int(display.frame.width)
            cfg.height = Int(display.frame.height)
            cfg.minimumFrameInterval = CMTime(value: 1, timescale: 60)
            cfg.pixelFormat = kCVPixelFormatType_32BGRA
            cfg.showsCursor = false
            cfg.backgroundColor = .black
            cfg.queueDepth = 6
            let filter = SCContentFilter(display: display, excludingApplications: others, exceptingWindows: [])
            let s = SCStream(filter: filter, configuration: cfg, delegate: nil)
            try s.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
            reset()
            try await s.startCapture()
            stream = s
            // Wait for the first frame so t0 starts with a live recording.
            let deadline = nowMs() + 1000
            while seq == 0 && nowMs() < deadline { usleep(5000) }
        } catch {
            fail("couldn't start screen recording: \(error)")
        }
    }

    func stop() async {
        try? await stream?.stopCapture()
        stream = nil
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sb: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen,
              let info = (CMSampleBufferGetSampleAttachmentsArray(sb, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]])?.first,
              let raw = info[.status] as? Int, SCFrameStatus(rawValue: raw) == .complete,
              let pb = CMSampleBufferGetImageBuffer(sb) else { return }
        let t = nowMs()
        lock.lock()
        buffer = pb
        bufferTime = t
        seq += 1
        lock.unlock()
    }

    private func reset() {
        lock.withLock { buffer = nil; seq = 0 }
    }

    /// Latest frame (sequence number, arrival time, pixels).
    func latest() -> (Int, Double, CVPixelBuffer)? {
        lock.lock(); defer { lock.unlock() }
        guard let b = buffer else { return nil }
        return (seq, bufferTime, b)
    }

    /// Window rect (global points) → pixel rect inside the recorded buffer.
    func pixelRect(_ r: CGRect, in pb: CVPixelBuffer) -> CGRect {
        let sx = Double(CVPixelBufferGetWidth(pb)) / displayFrame.width
        let sy = Double(CVPixelBufferGetHeight(pb)) / displayFrame.height
        let px = CGRect(x: (r.minX - displayFrame.minX) * sx, y: (r.minY - displayFrame.minY) * sy,
                        width: r.width * sx, height: r.height * sy)
        return px.intersection(CGRect(x: 0, y: 0, width: CVPixelBufferGetWidth(pb), height: CVPixelBufferGetHeight(pb)))
    }
}

/// 128×80 grayscale thumbnail of a region of a BGRA frame (area-sampled 2×2).
func thumb(_ pb: CVPixelBuffer, _ rect: CGRect) -> [UInt8] {
    let w = 128, h = 80
    var px = [UInt8](repeating: 0, count: w * h)
    guard rect.width >= 2, rect.height >= 2 else { return px }
    CVPixelBufferLockBaseAddress(pb, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(pb, .readOnly) }
    guard let base = CVPixelBufferGetBaseAddress(pb)?.assumingMemoryBound(to: UInt8.self) else { return px }
    let stride = CVPixelBufferGetBytesPerRow(pb)
    let maxX = CVPixelBufferGetWidth(pb) - 1, maxY = CVPixelBufferGetHeight(pb) - 1
    for j in 0..<h {
        for i in 0..<w {
            var sum = 0
            for (dx, dy) in [(0.25, 0.25), (0.75, 0.25), (0.25, 0.75), (0.75, 0.75)] {
                let x = min(maxX, Int(rect.minX + (Double(i) + dx) * rect.width / Double(w)))
                let y = min(maxY, Int(rect.minY + (Double(j) + dy) * rect.height / Double(h)))
                let p = base + y * stride + x * 4   // BGRA
                sum += (Int(p[2]) * 299 + Int(p[1]) * 587 + Int(p[0]) * 114) / 1000
            }
            px[j * w + i] = UInt8(sum / 4)
        }
    }
    return px
}

func cropImage(_ pb: CVPixelBuffer, _ rect: CGRect) -> CGImage? {
    var cg: CGImage?
    VTCreateCGImageFromCVPixelBuffer(pb, options: nil, imageOut: &cg)
    return cg?.cropping(to: rect.integral)
}

/// 128×80 grayscale thumbnail used for frame diffing.
func thumb(_ img: CGImage) -> [UInt8] {
    let w = 128, h = 80
    var px = [UInt8](repeating: 0, count: w * h)
    let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                        space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
    ctx.interpolationQuality = .medium
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
    return px
}

/// Fraction of thumbnail pixels that changed by more than ~5% luminance.
func changed(_ a: [UInt8], _ b: [UInt8]) -> Double {
    var n = 0
    for i in 0..<min(a.count, b.count) where abs(Int(a[i]) - Int(b[i])) > 12 { n += 1 }
    return Double(n) / Double(max(1, a.count))
}

/// Luminance standard deviation of a thumbnail. Splash/loading screens (flat
/// colour plus a spinner) score low; real content with artwork scores high.
func contrast(_ t: [UInt8]) -> Double {
    let n = Double(t.count)
    let mean = t.reduce(0.0) { $0 + Double($1) } / n
    let v = t.reduce(0.0) { $0 + (Double($1) - mean) * (Double($1) - mean) } / n
    return v.squareRoot()
}

func savePNG(_ img: CGImage, _ path: String) {
    let url = URL(fileURLWithPath: path)
    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else { return }
    CGImageDestinationAddImage(dest, img, nil)
    CGImageDestinationFinalize(dest)
}

// MARK: - Measurement

struct Observation {
    var ttw: Double?
    var tfc: Double?
    var tvc: Double?
    var changes: [[Double]] = []   // [t, fraction]
    var frames = 0
    var window: CGRect = .zero
}

/// Watches from t0 until the main window has been still for quietMs.
func observe(_ o: Options, t0: Double, frameTag: String?, requireNewWindow: Bool = false,
             knownWindow: Win? = nil) async -> Observation {
    var obs = Observation()
    var pids = Set(appPids(o.matches))
    var lastPidRefresh = nowMs()
    var lastWindowCheck = 0.0
    var win: Win? = knownWindow
    var prev: [UInt8]?
    var lastSeq = -1
    var lastChange = t0
    var lastFrame: (CVPixelBuffer, CGRect)?
    var tvcFrame: (CVPixelBuffer, CGRect)?
    let deadline = t0 + o.timeoutS * 1000

    while nowMs() < deadline {
        let waitingForWindow = obs.ttw == nil && knownWindow == nil
        if nowMs() - lastPidRefresh > 50 { pids = Set(appPids(o.matches)); lastPidRefresh = nowMs() }
        // Poll the window list every few ms until the window appears (precise
        // TTW), then every ~50 ms to follow a splash → main window switch.
        if waitingForWindow || nowMs() - lastWindowCheck > 50 {
            lastWindowCheck = nowMs()
            // Follow the largest main-sized window (e.g. splash → main window).
            if let w = mainWindow(o, pids) {
                if win == nil || requireNewWindow && obs.ttw == nil || w.id != win!.id || w.bounds != win!.bounds {
                    if win?.id != w.id { prev = nil }
                    win = w
                }
                if obs.ttw == nil && (requireNewWindow || knownWindow == nil) {
                    obs.ttw = nowMs() - t0
                    lastChange = nowMs()
                }
            }
        }
        guard let w = win, let (seq, t, pb) = recorder.latest(), seq != lastSeq else {
            // The screen hasn't changed: still counts towards stillness.
            if let p = prev, contrast(p) >= o.minContrast, nowMs() - lastChange >= o.quietMs { break }
            usleep(2000)
            continue
        }
        lastSeq = seq
        let rect = recorder.pixelRect(w.bounds, in: pb)
        obs.frames += 1
        let th = thumb(pb, rect)
        let hasContent = contrast(th) >= o.minContrast
        if obs.tfc == nil && hasContent { obs.tfc = max(0, t - t0) }
        if let p = prev {
            let c = changed(p, th)
            if c >= 0.01 {
                obs.changes.append([((t - t0) * 10).rounded() / 10, (c * 1000).rounded() / 1000])
            }
            if c >= o.minChange {
                lastChange = t
                tvcFrame = (pb, rect)
            }
        } else {
            tvcFrame = (pb, rect)
        }
        if o.allFrames, let dir = o.frames, let tag = frameTag, let img = cropImage(pb, rect) {
            savePNG(img, String(format: "%@/%@-%@-f%03d-%05.0fms.png", dir, o.label, tag, obs.frames, t - t0))
        }
        prev = th
        lastFrame = (pb, rect)
        // Done once the window has held still for quietMs *and* shows real
        // content (not a flat splash with a spinner).
        if hasContent && nowMs() - lastChange >= o.quietMs { break }
    }
    // Content that was already on screen and never changed (e.g. an instant
    // tab switch) is complete at its first frame.
    let measured = obs.ttw != nil || knownWindow != nil
    obs.tvc = measured ? max(lastChange - t0, obs.tfc ?? 0) : nil
    obs.window = win?.bounds ?? .zero
    if let dir = o.frames, let tag = frameTag {
        if let (pb, r) = tvcFrame, let i = cropImage(pb, r) { savePNG(i, "\(dir)/\(o.label)-\(tag)-tvc.png") }
        if let (pb, r) = lastFrame, let i = cropImage(pb, r) { savePNG(i, "\(dir)/\(o.label)-\(tag)-final.png") }
    }
    return obs
}

func launch(_ o: Options) {
    let cfg = NSWorkspace.OpenConfiguration()
    cfg.activates = true
    cfg.arguments = o.args
    cfg.createsNewApplicationInstance = false
    NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: o.app), configuration: cfg) { _, err in
        if let err { log("  launch error: \(err)") }
    }
}

// MARK: - OCR click

func findText(_ img: CGImage, _ needle: String) -> CGPoint? {
    let req = VNRecognizeTextRequest()
    req.recognitionLevel = .accurate
    req.usesLanguageCorrection = false
    try? VNImageRequestHandler(cgImage: img).perform([req])
    // Text recognition groups a whole line ("STORE LIBRARY COMMUNITY"), so find
    // the word inside each line and take the box of just that word.
    let hits = (req.results ?? []).compactMap { obs -> CGRect? in
        guard let c = obs.topCandidates(1).first else { return nil }
        let text = c.string
        var search = text.startIndex..<text.endIndex
        while let r = text.range(of: needle, options: [.caseInsensitive], range: search) {
            let before = r.lowerBound == text.startIndex ? " " : text[text.index(before: r.lowerBound)]
            let after = r.upperBound == text.endIndex ? " " : text[r.upperBound]
            if !before.isLetter && !after.isLetter {
                return (try? c.boundingBox(for: r))?.boundingBox ?? obs.boundingBox
            }
            search = r.upperBound..<text.endIndex
        }
        return nil
    }
    // Prefer the top-most match (navigation lives at the top).
    guard let box = hits.max(by: { $0.midY < $1.midY }) else { return nil }
    return CGPoint(x: box.midX, y: 1 - box.midY)   // normalized, origin top-left
}

/// Clicks at `p`; returns the time the mouse-up was posted (when apps act).
@discardableResult
func click(at p: CGPoint) -> Double {
    let src = CGEventSource(stateID: .hidSystemState)
    CGEvent(mouseEventSource: src, mouseType: .mouseMoved, mouseCursorPosition: p, mouseButton: .left)?.post(tap: .cghidEventTap)
    usleep(30_000)
    CGEvent(mouseEventSource: src, mouseType: .leftMouseDown, mouseCursorPosition: p, mouseButton: .left)?.post(tap: .cghidEventTap)
    usleep(20_000)
    let t = nowMs()
    CGEvent(mouseEventSource: src, mouseType: .leftMouseUp, mouseCursorPosition: p, mouseButton: .left)?.post(tap: .cghidEventTap)
    return t
}

/// Close the main window like a user would: press its close button through
/// Accessibility; for apps that draw their own title bar (e.g. Steam's CEF
/// window), click the red close dot found in the window's corner; last resort ⌘W.
func closeMainWindow(_ win: Win, _ o: Options) async -> Bool {
    func closed() -> Bool { !appWindows([win.pid]).contains { $0.id == win.id } }
    if pressCloseButton(win) { return true }

    // Activate the app's regular (Dock) process so its traffic lights are coloured.
    let regular = appPids(o.matches).compactMap { NSRunningApplication(processIdentifier: $0) }
        .first { $0.activationPolicy == .regular }
    regular?.activate()
    usleep(500_000)
    if let img = await Capturer().capture(win, width: Int(win.bounds.width)),
       let dot = redDot(img) {
        click(at: CGPoint(x: win.bounds.minX + dot.x, y: win.bounds.minY + dot.y))
        usleep(800_000)
        if closed() { return true }
    }

    let src = CGEventSource(stateID: .hidSystemState)
    for down in [true, false] {
        let e = CGEvent(keyboardEventSource: src, virtualKey: 13 /* W */, keyDown: down)
        e?.flags = .maskCommand
        e?.postToPid(regular?.processIdentifier ?? win.pid)
        usleep(30_000)
    }
    usleep(800_000)
    return closed()
}

/// Centroid of the red close dot in a window's top-left corner (window points).
func redDot(_ img: CGImage) -> CGPoint? {
    let rep = NSBitmapImageRep(cgImage: img)
    var xs = 0, ys = 0, n = 0
    for y in 0..<min(44, rep.pixelsHigh) {
        for x in 0..<min(90, rep.pixelsWide) {
            guard let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
            if c.redComponent > 0.8 && c.greenComponent < 0.45 && c.blueComponent < 0.45 { xs += x; ys += y; n += 1 }
        }
    }
    guard n >= 3 else { return nil }
    let scale = Double(img.width) / Double(max(1, rep.size.width))
    return CGPoint(x: Double(xs) / Double(n) / scale, y: Double(ys) / Double(n) / scale)
}

func pressCloseButton(_ win: Win) -> Bool {
    let app = AXUIElementCreateApplication(win.pid)
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success,
          let windows = value as? [AXUIElement] else { return false }
    for w in windows {
        var btn: CFTypeRef?
        if AXUIElementCopyAttributeValue(w, kAXCloseButtonAttribute as CFString, &btn) == .success, let b = btn {
            // swiftlint:disable:next force_cast
            if AXUIElementPerformAction(b as! AXUIElement, kAXPressAction as CFString) == .success { return true }
        }
    }
    return false
}

// MARK: - Output

func emit(_ o: Options, _ record: [String: Any]) {
    var r = record
    r["app"] = o.label
    r["mode"] = o.mode
    let data = try! JSONSerialization.data(withJSONObject: r, options: [.sortedKeys])
    let line = String(decoding: data, as: UTF8.self)
    print(line)
    if let out = o.out {
        let url = URL(fileURLWithPath: out)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let h = try? FileHandle(forWritingTo: url) {
            h.seekToEndOfFile()
            h.write(Data((line + "\n").utf8))
            try? h.close()
        } else {
            try? (line + "\n").write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

func fmt(_ v: Double?) -> String { v.map { String(format: "%.0f ms", $0) } ?? "—" }

// MARK: - Modes

func runCold(_ o: Options) async {
    for run in 1...o.runs {
        quitApp(o)
        sleepMs(o.cooldownS * 1000)
        await recorder.start(isolating: o.matches)
        let t0 = nowMs()
        launch(o)
        let obs = await observe(o, t0: t0, frameTag: "cold\(run)", requireNewWindow: true)
        await recorder.stop()
        sleepMs(o.settleS * 1000)
        let pids = attributedPids(o.matches)
        let (mem, procs) = footprintMiB(pids)
        log("  [\(o.label)] cold #\(run): window \(fmt(obs.ttw)), content \(fmt(obs.tfc)), visually complete \(fmt(obs.tvc)), "
            + String(format: "%.0f MiB in %d processes", mem, procs))
        emit(o, ["run": run, "ttw_ms": obs.ttw ?? NSNull(), "tfc_ms": obs.tfc ?? NSNull(), "tvc_ms": obs.tvc ?? NSNull(),
                 "frames": obs.frames, "changes": obs.changes, "footprint_mib": (mem * 10).rounded() / 10,
                 "processes": procs, "window": [obs.window.width, obs.window.height]])
    }
}

func runReopen(_ o: Options) async {
    // Make sure the app is up with a main window.
    if mainWindow(o, Set(appPids(o.matches))) == nil {
        await recorder.start(isolating: o.matches)
        launch(o)
        _ = await observe(o, t0: nowMs(), frameTag: nil, requireNewWindow: true)
        await recorder.stop()
    }
    for run in 1...o.runs {
        guard let win = mainWindow(o, Set(appPids(o.matches))) else { log("  no window"); return }
        guard await closeMainWindow(win, o) else { log("  [\(o.label)] couldn't close the window"); return }
        sleepMs(3000)
        if appPids(o.matches).isEmpty { log("  [\(o.label)] app quit when its window closed"); return }
        await recorder.start(isolating: o.matches)
        let t0 = nowMs()
        launch(o)   // same as clicking the Dock icon: sends a reopen event
        let obs = await observe(o, t0: t0, frameTag: "reopen\(run)", requireNewWindow: true)
        await recorder.stop()
        log("  [\(o.label)] reopen #\(run): window \(fmt(obs.ttw)), content \(fmt(obs.tfc)), visually complete \(fmt(obs.tvc))")
        emit(o, ["run": run, "ttw_ms": obs.ttw ?? NSNull(), "tfc_ms": obs.tfc ?? NSNull(), "tvc_ms": obs.tvc ?? NSNull(),
                 "frames": obs.frames, "changes": obs.changes])
        sleepMs(1500)
    }
}

func runClick(_ o: Options) async {
    guard o.clickText.count >= 1 else { fail("click mode needs --click-text (twice to alternate)") }
    let cap = Capturer()
    for run in 1...o.runs {
        for target in o.clickText {
            guard let win = mainWindow(o, Set(appPids(o.matches))) else { log("  no window"); return }
            NSRunningApplication(processIdentifier: win.pid)?.activate()
            sleepMs(800)
            guard let full = await cap.capture(win, width: Int(win.bounds.width) * 2),
                  let p = findText(full, target) else {
                log("  [\(o.label)] couldn't find \"\(target)\" on screen")
                return
            }
            let pt = CGPoint(x: win.bounds.minX + p.x * win.bounds.width, y: win.bounds.minY + p.y * win.bounds.height)
            await recorder.start(isolating: o.matches)
            let t0 = click(at: pt)
            let obs = await observe(o, t0: t0, frameTag: "\(target.lowercased())\(run)", knownWindow: win)
            await recorder.stop()
            log("  [\(o.label)] click \(target) #\(run): visually complete \(fmt(obs.tvc))")
            emit(o, ["run": run, "target": target, "tvc_ms": obs.tvc ?? NSNull(),
                     "frames": obs.frames, "changes": obs.changes])
            sleepMs(1000)
        }
    }
}

let recorder = DisplayRecorder()

@main
struct LaunchBench {
    static func main() async {
        let o = Options.parse()
        _ = NSApplication.shared   // AppKit/ScreenCaptureKit want an app object
        guard CGPreflightScreenCaptureAccess() else { fail("needs Screen Recording permission") }
        switch o.mode {
        case "cold": await runCold(o)
        case "reopen": await runReopen(o)
        case "click": await runClick(o)
        default: fail("unknown mode \(o.mode)")
        }
    }
}
