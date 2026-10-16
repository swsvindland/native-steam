import SwiftUI

// MARK: - Environment

extension EnvironmentValues {
    /// IDs of the enclosing focus-scroll containers (outermost first).
    @Entry var focusContainers: [String] = []
    /// True while the enclosing focusable card is hovered (pointer) or focused (keyboard/gamepad).
    @Entry public var cardHighlighted: Bool = false
    /// False for tabs kept alive in the background (regular layout): their screens
    /// must not offer focus targets to the engine.
    @Entry public var tabIsActive: Bool = true
}

#if os(macOS)
private struct SystemFocusBindingKey: EnvironmentKey {
    static var defaultValue: FocusState<String?>.Binding? { nil }
}

extension EnvironmentValues {
    /// Root `@FocusState` binding, mirrored from/to the spatial `FocusEngine`.
    var systemFocusBinding: FocusState<String?>.Binding? {
        get { self[SystemFocusBindingKey.self] }
        set { self[SystemFocusBindingKey.self] = newValue }
    }
}
#endif

// MARK: - Focus ring

/// 2 px white inner ring + 4 px accent @ 55% outer glow (DESIGN §3).
public struct FocusRing: View {
    var cornerRadius: CGFloat

    public init(cornerRadius: CGFloat) { self.cornerRadius = cornerRadius }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius + 4, style: .continuous)
                .strokeBorder(Steam.accent.opacity(0.55), lineWidth: 4)
                .padding(-4)
                .shadow(color: Steam.accent.opacity(0.7), radius: 10)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.white, lineWidth: 2)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Focusable

struct SteamFocusableModifier: ViewModifier {
    let id: String
    var cornerRadius: CGFloat
    var scales: Bool
    var lifts: Bool
    var isDefault: Bool
    var isChrome: Bool
    var action: (() -> Void)?
    var secondary: (() -> Void)?
    var onMove: ((MoveDirection) -> Bool)?

    @Environment(FocusEngine.self) private var engine
    @Environment(\.focusContainers) private var containers
    @State private var hovering = false

    func body(content: Content) -> some View {
        let focused = engine.showsFocus && engine.focusedID == id
        let hovered = hovering && engine.input == .pointer
        content
            .environment(\.cardHighlighted, focused || hovered || (hovering && isTouchPlatform))
            .brightness(focused ? 0.06 : 0)
            .overlay {
                if focused { FocusRing(cornerRadius: cornerRadius) }
            }
            .scaleEffect(focused && scales ? 1.04 : 1)
            .offset(y: hovered && lifts ? -3 : 0)
            .shadow(color: .black.opacity(hovered && lifts ? 0.45 : 0), radius: 12, y: 8)
            .zIndex(focused ? 2 : (hovered ? 1 : 0))
            .animation(.easeOut(duration: 0.12), value: focused)
            .animation(.easeOut(duration: 0.15), value: hovered)
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: FocusFramesKey.self,
                        value: [id: FocusFrame(
                            rect: proxy.frame(in: .global),
                            containers: containers,
                            isDefault: isDefault,
                            isChrome: isChrome
                        )]
                    )
                }
            }
            .onHover { hovering = $0 }
            #if os(iOS)
            .hoverEffect(lifts ? .lift : .highlight)
            #endif
            .onAppear {
                engine.registerActions(id, FocusActions(primary: action, secondary: secondary, move: onMove))
            }
            .onDisappear { engine.unregisterActions(id) }
            #if os(macOS)
            .modifier(SystemFocusModifier(id: id))
            #endif
    }

    private var isTouchPlatform: Bool {
        #if os(iOS)
        true
        #else
        false
        #endif
    }
}

#if os(macOS)
/// Mirrors the engine's focus into SwiftUI focus so Tab/Shift-Tab and accessibility work.
private struct SystemFocusModifier: ViewModifier {
    let id: String
    @Environment(\.systemFocusBinding) private var binding

    @ViewBuilder
    func body(content: Content) -> some View {
        if let binding {
            content
                .focusable()
                .focused(binding, equals: id)
                .focusEffectDisabled()
        } else {
            content
        }
    }
}
#endif

extension View {
    /// Makes a view a spatial-focus target: custom focus ring + scale for keyboard/gamepad,
    /// hover lift for pointer, frame registration for D-pad/arrow navigation.
    public func steamFocusable(
        _ id: String,
        cornerRadius: CGFloat = Radius.card,
        scales: Bool = true,
        lifts: Bool = true,
        isDefault: Bool = false,
        isChrome: Bool = false,
        action: (() -> Void)? = nil,
        secondary: (() -> Void)? = nil,
        onMove: ((MoveDirection) -> Bool)? = nil
    ) -> some View {
        modifier(SteamFocusableModifier(
            id: id, cornerRadius: cornerRadius, scales: scales, lifts: lifts,
            isDefault: isDefault, isChrome: isChrome,
            action: action, secondary: secondary, onMove: onMove
        ))
    }

    /// Groups focusable children for SwiftUI's directional focus (macOS); no-op on iOS,
    /// where the spatial `FocusEngine` handles directional movement on its own.
    @ViewBuilder
    public func steamFocusSection() -> some View {
        #if os(macOS) || os(tvOS)
        focusSection()
        #else
        self
        #endif
    }

    /// Declares a screen as a focus scope: collects its items' frames and hands them to the engine.
    public func focusScope(_ scope: String) -> some View {
        modifier(FocusScopeModifier(scope: scope))
    }

    /// Lets a ScrollView auto-scroll so the focused item stays visible (with lookahead on shelves).
    public func focusScrollContainer(
        _ axis: Axis,
        margin: CGFloat = 24,
        bottomMargin: CGFloat? = nil,
        position: Binding<ScrollPosition>? = nil
    ) -> some View {
        modifier(FocusScrollContainerModifier(axis: axis, margin: margin, bottomMargin: bottomMargin, external: position))
    }
}

// MARK: - Scope

struct FocusScopeModifier: ViewModifier {
    let scope: String
    @Environment(FocusEngine.self) private var engine
    @Environment(\.tabIsActive) private var tabIsActive
    @State private var lastFrames: [String: FocusFrame] = [:]
    @State private var onScreen = false

    func body(content: Content) -> some View {
        content
            .onPreferenceChange(FocusFramesKey.self) { frames in
                MainActor.assumeIsolated {
                    lastFrames = frames
                    if tabIsActive && onScreen { engine.setFrames(frames, scope: scope) }
                }
            }
            .onAppear {
                onScreen = true
                if tabIsActive { activate() }
            }
            .onDisappear {
                onScreen = false
                engine.removeScope(scope)
            }
            .onChange(of: tabIsActive) { _, active in
                // A kept-alive tab coming back (or going to the background).
                guard onScreen else { return }
                if active { activate() } else { engine.removeScope(scope) }
            }
    }

    private func activate() {
        engine.activateScope(scope)
        engine.setFrames(lastFrames, scope: scope)
    }
}

// MARK: - Auto-scroll

struct FocusScrollContainerModifier: ViewModifier {
    let axis: Axis
    var margin: CGFloat
    var bottomMargin: CGFloat?
    var external: Binding<ScrollPosition>?

    @Environment(FocusEngine.self) private var engine
    @Environment(\.focusContainers) private var parents
    @State private var containerID = UUID().uuidString
    @State private var internalPosition = ScrollPosition()

    private var position: Binding<ScrollPosition> { external ?? $internalPosition }
    @State private var geometry: ScrollGeometry?
    @State private var viewport: CGRect = .zero

    func body(content: Content) -> some View {
        content
            .environment(\.focusContainers, parents + [containerID])
            .scrollPosition(position)
            .onScrollGeometryChange(for: ScrollGeometry.self, of: { $0 }) { _, new in
                geometry = new
            }
            .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .global) }) { new in
                viewport = new
            }
            .onChange(of: engine.focusedID) { _, id in
                reveal(id)
            }
    }

    private func reveal(_ id: String?) {
        guard engine.showsFocus, let id, let item = engine.frame(for: id),
              item.containers.contains(containerID), let geo = geometry else { return }
        let r = item.rect
        let insets = geo.contentInsets
        if axis == .vertical {
            let hintsPad: CGFloat = engine.showsHints ? 56 : 0
            let top = viewport.minY + insets.top + margin
            let bottom = viewport.maxY - insets.bottom - (bottomMargin ?? margin) - hintsPad
            var delta: CGFloat = 0
            if r.minY < top {
                delta = r.minY - top
            } else if r.maxY > bottom {
                delta = min(r.maxY - bottom, r.minY - top)
            }
            guard abs(delta) > 0.5 else { return }
            let minOffset = -insets.top
            let maxOffset = max(minOffset, geo.contentSize.height - geo.containerSize.height + insets.bottom)
            let target = min(max(geo.contentOffset.y + delta, minOffset), maxOffset)
            withAnimation(.easeOut(duration: 0.22)) { position.wrappedValue.scrollTo(y: target) }
        } else {
            // ~1 card of lookahead in the direction of travel.
            let look = min(r.width * 0.6 + 12, max(0, (viewport.width - r.width) / 2))
            let leading = viewport.minX + max(insets.leading, margin) + (engine.lastMove == .left ? look : 0)
            let trailing = viewport.maxX - max(insets.trailing, margin) - (engine.lastMove == .right ? look : 0)
            var delta: CGFloat = 0
            if r.minX < leading {
                delta = r.minX - leading
            } else if r.maxX > trailing {
                delta = r.maxX - trailing
            }
            guard abs(delta) > 0.5 else { return }
            let minOffset = -insets.leading
            let maxOffset = max(minOffset, geo.contentSize.width - geo.containerSize.width + insets.trailing)
            let target = min(max(geo.contentOffset.x + delta, minOffset), maxOffset)
            withAnimation(.easeOut(duration: 0.22)) { position.wrappedValue.scrollTo(x: target) }
        }
    }
}
