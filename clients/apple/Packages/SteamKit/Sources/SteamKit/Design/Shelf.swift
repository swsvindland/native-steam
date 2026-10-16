import SwiftUI

/// Horizontal shelf: swipe/snap on touch, hover-revealed page arrows for the pointer,
/// focus auto-scroll with lookahead for keyboard / gamepad.
public struct Shelf<Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable {
    let items: Data
    var spacing: CGFloat
    let content: (Data.Element) -> Content

    @Environment(\.layout) private var layout
    @Environment(FocusEngine.self) private var engine
    @State private var position = ScrollPosition()
    @State private var geometry: ScrollGeometry?
    @State private var hovering = false

    /// Vertical breathing room so the focus ring + scale aren't clipped.
    private let ringPad: CGFloat = 14

    public init(_ items: Data, spacing: CGFloat = 16, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.items = items
        self.spacing = spacing
        self.content = content
    }

    public var body: some View {
        ScrollView(.horizontal) {
            // Lazy: only on-screen cards (plus the focus look-ahead card) are built,
            // which keeps cold start fast with long shelves.
            LazyHStack(alignment: .top, spacing: spacing) {
                ForEach(items) { item in
                    content(item)
                }
            }
            .scrollTargetLayout()
            .padding(.vertical, ringPad)
        }
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, layout.gutter, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .onScrollGeometryChange(for: ScrollGeometry.self, of: { $0 }) { _, new in geometry = new }
        .focusScrollContainer(.horizontal, margin: layout.gutter, position: $position)
        .mask {
            // Soft edges where the shelf runs into the page gutters.
            if layout.isCompact {
                Rectangle()
            } else {
                HStack(spacing: 0) {
                    LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing)
                        .frame(width: layout.gutter)
                    Rectangle()
                    LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: layout.gutter)
                }
            }
        }
        .overlay { if !layout.isCompact { pagingArrows } }
        .onHover { hovering = $0 }
        .padding(.horizontal, -layout.gutter)
        .padding(.vertical, -ringPad)
    }

    @ViewBuilder
    private var pagingArrows: some View {
        let show = hovering && engine.input == .pointer
        HStack {
            arrow("chevron.left", enabled: canScroll(-1)) { page(-1) }
            Spacer()
            arrow("chevron.right", enabled: canScroll(1)) { page(1) }
        }
        .padding(.horizontal, layout.gutter - 14)
        .opacity(show ? 1 : 0)
        .animation(.easeOut(duration: 0.15), value: show)
        .allowsHitTesting(show)
    }

    private func arrow(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 64)
                .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.white.opacity(0.12)))
        }
        .buttonStyle(.pressable)
        .opacity(enabled ? 1 : 0)
        .disabled(!enabled)
    }

    private func canScroll(_ dir: Int) -> Bool {
        guard let g = geometry else { return false }
        let maxX = g.contentSize.width - g.containerSize.width + g.contentInsets.trailing
        return dir < 0 ? g.contentOffset.x > -g.contentInsets.leading + 2 : g.contentOffset.x < maxX - 2
    }

    private func page(_ dir: Int) {
        guard let g = geometry else { return }
        let minX = -g.contentInsets.leading
        let maxX = max(minX, g.contentSize.width - g.containerSize.width + g.contentInsets.trailing)
        let target = min(max(g.contentOffset.x + CGFloat(dir) * g.containerSize.width * 0.8, minX), maxX)
        withAnimation(.easeInOut(duration: 0.35)) { position.scrollTo(x: target) }
    }
}
