import SwiftUI

/// Xbox-style controller glyph drawn in SwiftUI (no assets needed).
public struct ControllerGlyph: View {
    public enum Kind: String, Sendable {
        case a = "A", b = "B", x = "X", y = "Y", lb = "LB", rb = "RB", lt = "LT", rt = "RT", menu = "≡"
    }

    let kind: Kind
    var size: CGFloat

    public init(_ kind: Kind, size: CGFloat = 22) {
        self.kind = kind
        self.size = size
    }

    private var color: Color {
        switch kind {
        case .a: Color(hex: 0x5DB43A)
        case .b: Color(hex: 0xE04B3A)
        case .x: Color(hex: 0x2F8CF0)
        case .y: Color(hex: 0xF2C12E)
        default: Color(hex: 0x3D4450)
        }
    }

    public var body: some View {
        switch kind {
        case .a, .b, .x, .y:
            Text(kind.rawValue)
                .font(.system(size: size * 0.55, weight: .heavy, design: .rounded))
                .foregroundStyle(kind == .y ? Color.black.opacity(0.8) : .white)
                .frame(width: size, height: size)
                .background(Circle().fill(color))
                .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1))
        default:
            Text(kind.rawValue)
                .font(.system(size: size * 0.45, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, size * 0.28)
                .frame(minWidth: size * 1.35, minHeight: size * 0.82)
                .background(
                    UnevenRoundedRectangle(
                        topLeadingRadius: kind == .lb || kind == .lt ? size * 0.4 : 4,
                        bottomLeadingRadius: 4,
                        bottomTrailingRadius: 4,
                        topTrailingRadius: kind == .rb || kind == .rt ? size * 0.4 : 4,
                        style: .continuous
                    )
                    .fill(color)
                )
                .overlay(
                    UnevenRoundedRectangle(
                        topLeadingRadius: kind == .lb || kind == .lt ? size * 0.4 : 4,
                        bottomLeadingRadius: 4,
                        bottomTrailingRadius: 4,
                        topTrailingRadius: kind == .rb || kind == .rt ? size * 0.4 : 4,
                        style: .continuous
                    )
                    .strokeBorder(.white.opacity(0.25), lineWidth: 1)
                )
        }
    }
}

/// Big-Picture-style button hints, pinned to the bottom when the gamepad is the last input.
public struct HintsBar: View {
    @Environment(AppModel.self) private var model
    @Environment(\.layout) private var layout

    public init() {}

    private struct Hint: Identifiable {
        let glyphs: [ControllerGlyph.Kind]
        let label: String
        var id: String { label }
    }

    private var hints: [Hint] {
        var list: [Hint] = [Hint(glyphs: [.a], label: "Select")]
        list.append(Hint(glyphs: [.b], label: "Back"))
        if model.tab == .store || model.tab == .library {
            list.append(Hint(glyphs: [.y], label: "Search"))
        }
        if model.tab == .library {
            list.append(Hint(glyphs: [.x], label: "Favorite"))
        } else if model.tab == .store {
            list.append(Hint(glyphs: [.x], label: "Wishlist"))
        }
        return list
    }

    private var trailingHints: [Hint] {
        var list: [Hint] = []
        if model.tab == .library && model.currentPath.isEmpty {
            list.append(Hint(glyphs: [.lt, .rt], label: "Collections"))
        } else if model.tab == .community && model.currentPath.isEmpty {
            list.append(Hint(glyphs: [.lt, .rt], label: "Sections"))
        }
        list.append(Hint(glyphs: [.lb, .rb], label: "Switch tab"))
        return list
    }

    public var body: some View {
        Group {
            if layout.isCompact {
                ViewThatFits(in: .horizontal) {
                    compactRow(labels: true)
                    compactRow(labels: false)
                }
            } else {
                HStack(spacing: 28) {
                    ForEach(hints) { hint in hintView(hint) }
                    Spacer(minLength: 8)
                    ForEach(trailingHints) { hint in hintView(hint) }
                }
            }
        }
        .padding(.horizontal, layout.isCompact ? 16 : 28)
        .frame(height: layout.isCompact ? 44 : 52)
        .frame(maxWidth: .infinity)
        .background(Steam.bgChrome.opacity(0.95))
        .overlay(alignment: .top) { Rectangle().fill(Steam.divider).frame(height: 1) }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Controller hints")
    }

    /// Phone width: glyph + short label for face buttons, bare LB/RB at the end.
    private func compactRow(labels: Bool) -> some View {
        HStack(spacing: 12) {
            ForEach(hints) { hint in
                HStack(spacing: 5) {
                    ForEach(hint.glyphs, id: \.self) { ControllerGlyph($0, size: 18) }
                    if labels || hint.glyphs == [.a] || hint.glyphs == [.b] {
                        Text(hint.label)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Steam.textBody)
                            .fixedSize()
                    }
                }
            }
            Spacer(minLength: 6)
            HStack(spacing: 4) {
                ControllerGlyph(.lb, size: 18)
                ControllerGlyph(.rb, size: 18)
            }
        }
    }

    private func hintView(_ hint: Hint) -> some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(hint.glyphs, id: \.self) { ControllerGlyph($0, size: layout.isCompact ? 20 : 24) }
            }
            Text(hint.label)
                .font(.system(size: layout.isCompact ? 12 : 14, weight: .medium))
                .foregroundStyle(Steam.textBody)
                .fixedSize()
        }
    }
}
