// Prints the CGWindowID of the largest on-screen window owned by a process.
// Usage: swift window-id.swift <pid | owner name>
import CoreGraphics
import Foundation

let arg = CommandLine.arguments.dropFirst().first ?? "NativeSteam"
let pid = Int32(arg)
let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
let matches = info.filter { w in
    guard (w[kCGWindowLayer as String] as? Int) == 0 else { return false }
    if let pid { return (w[kCGWindowOwnerPID as String] as? Int32) == pid }
    return (w[kCGWindowOwnerName as String] as? String) == arg
}
let best = matches.max { a, b in
    let ra = a[kCGWindowBounds as String] as? [String: CGFloat] ?? [:]
    let rb = b[kCGWindowBounds as String] as? [String: CGFloat] ?? [:]
    return (ra["Width"] ?? 0) * (ra["Height"] ?? 0) < (rb["Width"] ?? 0) * (rb["Height"] ?? 0)
}
if let best, let id = best[kCGWindowNumber as String] as? Int {
    let r = best[kCGWindowBounds as String] as? [String: CGFloat] ?? [:]
    FileHandle.standardError.write("window \(id) \(Int(r["Width"] ?? 0))x\(Int(r["Height"] ?? 0))\n".data(using: .utf8)!)
    print(id)
} else {
    FileHandle.standardError.write("no window found for \(arg)\n".data(using: .utf8)!)
    exit(1)
}
