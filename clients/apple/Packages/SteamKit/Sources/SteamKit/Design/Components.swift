import SwiftUI

// MARK: - Section header

/// UPPERCASE tracked section header with an optional trailing "See all ›".
public struct SectionHeader<Trailing: View>: View {
    let title: String
    var count: Int?
    @ViewBuilder var trailing: Trailing

    public init(_ title: String, count: Int? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.count = count
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.xs) {
            Text(title).sectionHeaderStyle()
            if let count {
                Text("(\(count))").sectionHeaderStyle().opacity(0.55)
            }
            Spacer(minLength: Space.xs)
            trailing
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

extension SectionHeader where Trailing == EmptyView {
    public init(_ title: String, count: Int? = nil) {
        self.init(title, count: count) { EmptyView() }
    }
}

public struct SeeAllLabel: View {
    public init() {}
    public var body: some View {
        Text("See all ›")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Steam.textSecondary)
    }
}

// MARK: - Price block

/// Discount badge + struck-through original + final price; or just the final label;
/// or "Coming soon" / release date when there's no price yet (DESIGN §4.1).
public struct PriceBlock: View {
    let price: Price?
    var releaseDate: String?
    var large = false

    public init(price: Price?, releaseDate: String? = nil, large: Bool = false) {
        self.price = price
        self.releaseDate = releaseDate
        self.large = large
    }

    public var body: some View {
        if let price {
            if let discount = price.discountLabel {
                HStack(spacing: 0) {
                    Text(discount)
                        .font(.system(size: large ? 22 : 15, weight: .bold))
                        .foregroundStyle(Steam.discountText)
                        .padding(.horizontal, large ? 10 : 6)
                        .frame(maxHeight: .infinity)
                        .background(Steam.discountBg)
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(price.initialLabel)
                            .font(.system(size: large ? 12 : 10))
                            .strikethrough(true, color: Steam.priceOriginal)
                            .foregroundStyle(Steam.priceOriginal)
                        Text(price.finalLabel)
                            .font(.system(size: large ? 16 : 13, weight: .medium))
                            .foregroundStyle(Steam.discountText)
                    }
                    .padding(.horizontal, large ? 10 : 6)
                    .frame(maxHeight: .infinity)
                    .background(Steam.priceBg)
                }
                .fixedSize(horizontal: true, vertical: false)
                .frame(height: large ? 44 : 32)
                .clipShape(RoundedRectangle(cornerRadius: 2))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(discount), was \(price.initialLabel), now \(price.finalLabel)")
            } else {
                Text(price.finalLabel)
                    .font(.system(size: large ? 15 : 13, weight: .medium))
                    .foregroundStyle(Steam.textBody)
                    .padding(.horizontal, large ? 10 : 6)
                    .frame(height: large ? 44 : 26)
                    .background(Steam.priceBg, in: RoundedRectangle(cornerRadius: 2))
                    .fixedSize()
            }
        } else {
            Text(releaseDate.map { "Coming \($0)" } ?? "Coming soon")
                .font(.system(size: large ? 14 : 12, weight: .medium))
                .foregroundStyle(Steam.textSecondary)
                .padding(.horizontal, large ? 10 : 6)
                .frame(height: large ? 44 : 26)
                .background(Steam.priceBg, in: RoundedRectangle(cornerRadius: 2))
                .fixedSize()
        }
    }
}

/// Just the green "-40%" badge (for compact overlays).
public struct DiscountBadge: View {
    let label: String
    public init(_ label: String) { self.label = label }
    public var body: some View {
        Text(label)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(Steam.discountText)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Steam.discountBg, in: RoundedRectangle(cornerRadius: 2))
    }
}

// MARK: - Buttons

/// Big gradient action button (PLAY / INSTALL / Add to Cart). Purely visual.
public struct GradientButtonLabel: View {
    let title: String
    let systemImage: String?
    let gradient: LinearGradient
    var subtitle: String?
    var height: CGFloat
    var expands: Bool

    public init(_ title: String, systemImage: String? = nil, gradient: LinearGradient, subtitle: String? = nil,
                height: CGFloat = 48, expands: Bool = false) {
        self.title = title
        self.systemImage = systemImage
        self.gradient = gradient
        self.subtitle = subtitle
        self.height = height
        self.expands = expands
    }

    public var body: some View {
        HStack(spacing: 10) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: height * 0.36, weight: .bold))
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: height * 0.34, weight: .bold))
                    .tracking(1.2)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .opacity(0.85)
                }
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 26)
        .frame(maxWidth: expands ? .infinity : nil)
        .frame(height: height)
        .background(gradient, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
    }
}

/// Square-ish secondary button with an SF Symbol (favorite, settings, info…).
public struct IconButtonLabel: View {
    let systemImage: String
    var active = false
    var size: CGFloat
    @Environment(\.cardHighlighted) private var highlighted

    public init(_ systemImage: String, active: Bool = false, size: CGFloat = 48) {
        self.systemImage = systemImage
        self.active = active
        self.size = size
    }

    public var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.38, weight: .semibold))
            .foregroundStyle(active ? Color(hex: 0xFFC82C) : Steam.textBody)
            .frame(width: size, height: size)
            .background(highlighted ? Steam.surfaceHover : Color.white.opacity(0.1),
                        in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
    }
}

/// Secondary text button (Wishlist, Edit Profile…).
public struct SecondaryButtonLabel: View {
    let title: String
    var systemImage: String?
    var height: CGFloat
    @Environment(\.cardHighlighted) private var highlighted

    public init(_ title: String, systemImage: String? = nil, height: CGFloat = 44) {
        self.title = title
        self.systemImage = systemImage
        self.height = height
    }

    public var body: some View {
        HStack(spacing: 8) {
            if let systemImage { Image(systemName: systemImage) }
            Text(title)
        }
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(highlighted ? .white : Steam.accentLink)
        .padding(.horizontal, 18)
        .frame(height: height)
        .background(highlighted ? Steam.surfaceHover : Color(hex: 0x66C0F4, opacity: 0.12),
                    in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
    }
}

/// Plain button style with press feedback (touch) and no system chrome.
public struct PressableStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.97
    public init(pressedScale: CGFloat = 0.97) { self.pressedScale = pressedScale }
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableStyle {
    public static var pressable: PressableStyle { PressableStyle() }
}

// MARK: - Chips

public struct ChipLabel: View {
    let title: String
    var selected = false
    var count: Int?
    @Environment(\.cardHighlighted) private var highlighted

    public init(_ title: String, selected: Bool = false, count: Int? = nil) {
        self.title = title
        self.selected = selected
        self.count = count
    }

    public var body: some View {
        HStack(spacing: 6) {
            Text(title)
            if let count {
                Text("\(count)").foregroundStyle(selected ? .white.opacity(0.8) : Steam.textMuted)
            }
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(selected ? .white : Steam.textBody)
        .padding(.horizontal, 14)
        .frame(minHeight: 32)
        .background(
            Capsule().fill(selected ? Steam.accent : (highlighted ? Steam.surfaceHover : Color.white.opacity(0.08)))
        )
        .contentShape(Capsule())
    }
}

// MARK: - People

/// Square avatar (4 pt radius) with a presence-coloured border.
public struct AvatarView: View {
    let url: String?
    var status: String?
    var size: CGFloat
    var borderWidth: CGFloat

    public init(_ url: String?, status: String? = nil, size: CGFloat = 40, borderWidth: CGFloat? = nil) {
        self.url = url
        self.status = status
        self.size = size
        self.borderWidth = borderWidth ?? max(1.5, size / 24)
    }

    public var body: some View {
        RemoteImage(url, maxPixel: Int(size * 3), placeholderColor: Steam.surfaceNeutral)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: Radius.avatar, style: .continuous))
            .padding(status == nil ? 0 : borderWidth + 1)
            .overlay {
                if let status {
                    RoundedRectangle(cornerRadius: Radius.avatar + 1, style: .continuous)
                        .strokeBorder(Steam.statusColor(status), lineWidth: borderWidth)
                }
            }
    }
}

/// Steam level ring: a circle outlined in `levelColor` with the number.
public struct LevelRing: View {
    let level: Int
    let color: String
    var size: CGFloat

    public init(level: Int, color: String, size: CGFloat = 36) {
        self.level = level
        self.color = color
        self.size = size
    }

    public var body: some View {
        Text("\(level)")
            .font(.system(size: size * 0.4, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .overlay(Circle().strokeBorder(Color(hexString: color), lineWidth: max(2, size / 14)))
            .accessibilityLabel("Level \(level)")
    }
}

// MARK: - Misc

public struct ProgressBar: View {
    let fraction: Double
    var tint: Color
    var height: CGFloat

    public init(_ fraction: Double, tint: Color = Steam.accent, height: CGFloat = 4) {
        self.fraction = fraction
        self.tint = tint
        self.height = height
    }

    public var body: some View {
        Capsule()
            .fill(Color.white.opacity(0.12))
            .overlay(alignment: .leading) {
                GeometryReader { g in
                    Capsule()
                        .fill(LinearGradient(colors: [tint.opacity(0.85), tint], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(height, g.size.width * min(max(fraction, 0), 1)))
                }
            }
            .frame(height: height)
            .accessibilityValue("\(Int(fraction * 100)) percent")
    }
}

public struct PlatformIcons: View {
    let platforms: Platforms
    var size: CGFloat = 12

    public init(_ platforms: Platforms, size: CGFloat = 12) {
        self.platforms = platforms
        self.size = size
    }

    public var body: some View {
        HStack(spacing: 6) {
            if platforms.windows { Image(systemName: "pc").accessibilityLabel("Windows") }
            if platforms.mac { Image(systemName: "laptopcomputer").accessibilityLabel("macOS") }
            if platforms.linux { Image(systemName: "terminal").accessibilityLabel("SteamOS + Linux") }
        }
        .font(.system(size: size, weight: .medium))
        .foregroundStyle(Steam.textSecondary)
    }
}

/// Coloured dot for a review tone.
public struct ToneDot: View {
    let tone: String
    public init(_ tone: String) { self.tone = tone }
    public var body: some View {
        Circle().fill(Steam.reviewColor(tone)).frame(width: 7, height: 7)
    }
}

/// Pulsing green "live" dot.
public struct LiveDot: View {
    @State private var on = false
    public init() {}
    public var body: some View {
        Circle()
            .fill(Steam.statusInGame)
            .frame(width: 7, height: 7)
            .background(Circle().fill(Steam.statusInGame.opacity(0.35)).scaleEffect(on ? 2.2 : 1).opacity(on ? 0 : 1))
            .onAppear {
                withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) { on = true }
            }
    }
}

/// Card background that reacts to hover/focus (surface → surfaceHover).
public struct CardBackground: View {
    var neutral = false
    @Environment(\.cardHighlighted) private var highlighted

    public init(neutral: Bool = false) { self.neutral = neutral }

    public var body: some View {
        RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
            .fill(highlighted ? Steam.surfaceHover : (neutral ? Steam.surfaceNeutral : Steam.surface))
    }
}

/// The plain text wordmark — never Valve's logo.
public struct SteamWordmark: View {
    var size: CGFloat
    public init(size: CGFloat = 17) { self.size = size }
    public var body: some View {
        Text("STEAM")
            .font(.system(size: size, weight: .black))
            .tracking(size * 0.22)
            .foregroundStyle(Steam.textBody)
            .accessibilityLabel("Native Steam")
    }
}

/// Medallion for a profile badge: a circle filled with `color`, a symbol and the level.
public struct BadgeMedallion: View {
    let badge: Badge
    var size: CGFloat

    public init(_ badge: Badge, size: CGFloat = 64) {
        self.badge = badge
        self.size = size
    }

    static func symbol(for icon: String) -> String {
        switch icon {
        case "years": "calendar"
        case "sale": "tag.fill"
        case "collector": "square.stack.3d.up.fill"
        case "community": "person.3.fill"
        case "awards": "rosette"
        case "deck": "gamecontroller.fill"
        case "trophy": "trophy.fill"
        default: "seal.fill"
        }
    }

    public var body: some View {
        let color = Color(hexString: badge.color)
        ZStack {
            Circle().fill(
                RadialGradient(colors: [color.opacity(1), color.opacity(0.55)], center: .topLeading, startRadius: 0, endRadius: size)
            )
            Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: 1.5).padding(3)
            Image(systemName: Self.symbol(for: badge.icon))
                .font(.system(size: size * 0.36, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
        }
        .frame(width: size, height: size)
        .overlay(alignment: .bottomTrailing) {
            Text("\(badge.level)")
                .font(.system(size: size * 0.18, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(Capsule().fill(Steam.bgChrome))
                .overlay(Capsule().strokeBorder(color, lineWidth: 1))
                .offset(x: 2, y: 2)
        }
    }
}
