import Observation
import SwiftUI

/// The last input modality the user touched (DESIGN §3). The UI adapts to it:
/// focus ring for keyboard/gamepad, hover for pointer, hints bar for gamepad.
public enum InputKind: String, Sendable {
    case pointer, touch, keyboard, gamepad
}

public enum MoveDirection: Sendable {
    case up, down, left, right
}

/// A focusable item's geometry, reported through `FocusFramesKey` preferences.
public struct FocusFrame: Equatable, Sendable {
    public var rect: CGRect
    /// IDs of the focus-scroll containers this item lives in (outermost first).
    public var containers: [String]
    /// Preferred initial focus target for its screen.
    public var isDefault: Bool
    /// Part of the window chrome (top nav bar) rather than page content.
    public var isChrome: Bool
}

/// Collects the frames of focusable items. Each screen ("focus scope") reduces the
/// preferences of its subtree and hands them to the `FocusEngine`.
public struct FocusFramesKey: PreferenceKey {
    public static let defaultValue: [String: FocusFrame] = [:]
    public static func reduce(value: inout [String: FocusFrame], nextValue: () -> [String: FocusFrame]) {
        value.merge(nextValue()) { _, new in new }
    }
}

/// Actions a focusable item exposes to keyboard / gamepad.
struct FocusActions {
    var primary: (() -> Void)?
    var secondary: (() -> Void)?
    /// Lets an item consume a direction (e.g. the featured carousel pages left/right).
    var move: ((MoveDirection) -> Bool)?
}

/// Small shared spatial focus engine.
///
/// Items register their frames (window coordinates) via preferences; D-pad / arrow keys
/// pick the nearest item in the requested direction. The engine is the source of truth
/// for "what is focused"; SwiftUI's `@FocusState` is mirrored from it on macOS so Tab
/// order, VoiceOver and the system keyboard loop stay in sync.
@Observable
@MainActor
public final class FocusEngine {
    public init() {}

    /// The focused item, if any. Only one thing is ever focused.
    public private(set) var focusedID: String? {
        didSet {
            if Self.debug, oldValue != focusedID {
                FileHandle.standardError.write("[focus] \(oldValue ?? "nil") -> \(focusedID ?? "nil")\n".data(using: .utf8)!)
            }
        }
    }

    /// Set `NATIVE_STEAM_DEBUG_FOCUS=1` to log focus changes to stderr.
    @ObservationIgnored nonisolated static let debug = ProcessInfo.processInfo.environment["NATIVE_STEAM_DEBUG_FOCUS"] != nil

    /// Last-used input modality.
    public var input: InputKind = .pointer {
        didSet {
            if input == .gamepad || input == .keyboard, focusedID == nil {
                pendingDefaultFocus = true
                focusDefaultIfPossible()
            }
        }
    }

    /// A game controller is connected (shows LB/RB glyphs on the tab bar).
    public var gamepadConnected = false

    /// The focus ring is only shown for keyboard and gamepad.
    public var showsFocus: Bool { input == .keyboard || input == .gamepad }

    /// Hints bar is shown when the gamepad was the last input.
    public var showsHints: Bool { input == .gamepad }

    /// Direction of the last move (used for shelf lookahead).
    public private(set) var lastMove: MoveDirection?

    /// Until this time, SwiftUI focus changes are treated as Tab-key navigation and adopted.
    @ObservationIgnored public var acceptsSystemFocusUntil: Date = .distantPast

    /// Set while a text field is being edited so arrows/space go to the field.
    @ObservationIgnored public var textInputActive = false

    @ObservationIgnored private var scopes: [String: [String: FocusFrame]] = [:]
    @ObservationIgnored private var scopeOrder: [String] = []
    @ObservationIgnored private var actions: [String: FocusActions] = [:]
    @ObservationIgnored private var pendingDefaultFocus = false
    @ObservationIgnored private var awaitingTransition = false
    @ObservationIgnored private var defaultFocusTask: Task<Void, Never>?

    /// Window bounds in global coordinates (set by the root view).
    @ObservationIgnored public var viewport: CGRect = .zero

    /// Called when "up" finds nothing (or B at a root): move focus to the tab bar.
    @ObservationIgnored public var focusTabBar: (() -> Void)?

    // MARK: Registration

    func setFrames(_ frames: [String: FocusFrame], scope: String) {
        scopes[scope] = frames
        if !scopeOrder.contains(scope) { scopeOrder.append(scope) }
        if pendingDefaultFocus { focusDefaultIfPossible() }
    }

    /// Marks a screen as the active page (most recently appeared). Only the active page
    /// and the window chrome take part in navigation, so a screen still alive underneath
    /// a pushed page can't steal focus.
    func activateScope(_ scope: String) {
        scopeOrder.removeAll { $0 == scope }
        scopeOrder.append(scope)
    }

    func removeScope(_ scope: String) {
        scopes[scope] = nil
        scopeOrder.removeAll { $0 == scope }
    }

    func registerActions(_ id: String, _ value: FocusActions) {
        actions[id] = value
    }

    func unregisterActions(_ id: String) {
        actions[id] = nil
    }

    static let chromeScope = "chrome"

    /// Frames that can currently receive focus: the window chrome plus the active page.
    var allFrames: [String: FocusFrame] {
        var result: [String: FocusFrame] = scopes[Self.chromeScope] ?? [:]
        if let page = scopeOrder.last(where: { $0 != Self.chromeScope }), let frames = scopes[page] {
            result.merge(frames) { _, new in new }
        }
        return result
    }

    public func frame(for id: String) -> FocusFrame? {
        allFrames[id]
    }

    // MARK: Focus changes

    public func focus(_ id: String?) {
        guard focusedID != id else { return }
        focusedID = id
    }

    /// Requests that the next registered screen gets its default item focused.
    /// Waits for the incoming screen to lay out (navigation / tab transitions), then
    /// focuses its default item.
    public func requestDefaultFocus() {
        pendingDefaultFocus = true
        focusedID = nil
        defaultFocusTask?.cancel()
        defaultFocusTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(380))
            guard !Task.isCancelled, let self else { return }
            self.awaitingTransition = false
            self.focusDefaultIfPossible()
        }
        awaitingTransition = true
    }

    func focusDefaultIfPossible() {
        guard !awaitingTransition, showsFocus || pendingDefaultFocus else { return }
        let content = allFrames.filter { !$0.value.isChrome && $0.value.rect.width > 1 }
        guard !content.isEmpty else { return }
        let defaults = content.filter(\.value.isDefault)
        let pool = defaults.isEmpty ? content : defaults
        let best = pool.min { a, b in
            let ay = a.value.rect.minY.rounded(), by = b.value.rect.minY.rounded()
            if abs(ay - by) > 4 { return ay < by }
            return a.value.rect.minX < b.value.rect.minX
        }
        if let best {
            pendingDefaultFocus = false
            focusedID = best.key
        }
    }

    public func move(_ direction: MoveDirection) {
        lastMove = direction
        if Self.debug { FileHandle.standardError.write("[focus] move \(direction) from \(focusedID ?? "nil")\n".data(using: .utf8)!) }
        let frames = allFrames
        guard let current = focusedID, let origin = frames[current] else {
            pendingDefaultFocus = true
            focusDefaultIfPossible()
            return
        }
        if let consume = actions[current]?.move, consume(direction) { return }
        let viewport = self.viewport
        let shelf = origin.containers.last
        let candidates = frames.filter { id, frame in
            guard id != current, frame.rect.width > 1 else { return false }
            // Items scrolled out of view sideways (in other shelves) are not reachable;
            // within the same shelf they are (the shelf scrolls to reveal them).
            if viewport.width > 0, frame.rect.maxX < viewport.minX + 2 || frame.rect.minX > viewport.maxX - 2 {
                return shelf != nil && frame.containers.last == shelf
            }
            return true
        }
        if let next = Self.nearest(from: origin.rect, direction: direction, candidates: candidates) {
            // Entering the tab strip from the page lands on the active tab (Big Picture style).
            if direction == .up, !origin.isChrome, next.hasPrefix("chrome.tab."), let focusTabBar {
                focusTabBar()
                return
            }
            focusedID = next
        } else if direction == .up, !origin.isChrome {
            focusTabBar?()
        }
    }

    public func activate() {
        guard let id = focusedID else {
            pendingDefaultFocus = true
            focusDefaultIfPossible()
            return
        }
        actions[id]?.primary?()
    }

    public func secondary() {
        guard let id = focusedID else { return }
        actions[id]?.secondary?()
    }

    // MARK: Spatial search

    /// Picks the closest candidate in `direction`. Items overlapping on the orthogonal
    /// axis are strongly preferred, so moving down a grid goes straight down.
    nonisolated static func nearest(from a: CGRect, direction: MoveDirection, candidates: [String: FocusFrame]) -> String? {
        var best: (id: String, score: CGFloat)?
        for (id, frame) in candidates {
            let b = frame.rect
            guard let score = score(from: a, to: b, direction: direction) else { continue }
            if best == nil || score < best!.score || (score == best!.score && id < best!.id) {
                best = (id, score)
            }
        }
        return best?.id
    }

    nonisolated static func score(from a: CGRect, to b: CGRect, direction: MoveDirection) -> CGFloat? {
        let tolerance: CGFloat = 6
        let primary: CGFloat
        let orthoGap: CGFloat
        let orthoCenter: CGFloat
        switch direction {
        case .right:
            guard b.minX >= a.maxX - tolerance, b.midX > a.midX else { return nil }
            primary = max(0, b.minX - a.maxX)
            orthoGap = gap(a.minY...a.maxY, b.minY...b.maxY)
            orthoCenter = abs(b.midY - a.midY)
        case .left:
            guard b.maxX <= a.minX + tolerance, b.midX < a.midX else { return nil }
            primary = max(0, a.minX - b.maxX)
            orthoGap = gap(a.minY...a.maxY, b.minY...b.maxY)
            orthoCenter = abs(b.midY - a.midY)
        case .down:
            guard b.minY >= a.maxY - tolerance, b.midY > a.midY else { return nil }
            primary = max(0, b.minY - a.maxY)
            orthoGap = gap(a.minX...a.maxX, b.minX...b.maxX)
            orthoCenter = abs(b.minX - a.minX) * 0.5 + abs(b.midX - a.midX) * 0.5
        case .up:
            guard b.maxY <= a.minY + tolerance, b.midY < a.midY else { return nil }
            primary = max(0, a.minY - b.maxY)
            orthoGap = gap(a.minX...a.maxX, b.minX...b.maxX)
            orthoCenter = abs(b.minX - a.minX) * 0.5 + abs(b.midX - a.midX) * 0.5
        }
        // Aligned items win; then distance; then centre alignment as tie-breaker.
        return primary + orthoGap * 2 + orthoCenter * 0.15 + (orthoGap > 0 ? 160 : 0)
    }

    nonisolated private static func gap(_ a: ClosedRange<CGFloat>, _ b: ClosedRange<CGFloat>) -> CGFloat {
        if a.overlaps(b) { return 0 }
        return a.upperBound < b.lowerBound ? b.lowerBound - a.upperBound : a.lowerBound - b.upperBound
    }
}
