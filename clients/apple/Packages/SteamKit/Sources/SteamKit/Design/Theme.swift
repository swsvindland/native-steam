import SwiftUI

// Brand tokens from docs/DESIGN.md §1.

extension Color {
    public init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    /// Parses "#rrggbb" (as used by `levelColor` and badge colours).
    public init(hexString: String, fallback: Color = .gray) {
        var s = hexString.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else {
            self = fallback
            return
        }
        self.init(hex: v)
    }
}

public enum Steam {
    // Backgrounds
    public static let bgChrome = Color(hex: 0x171A21)
    public static let storeTop = Color(hex: 0x1B2838)
    public static let storeBottom = Color(hex: 0x0E1620)
    public static let libraryTop = Color(hex: 0x1E2329)
    public static let libraryBottom = Color(hex: 0x0E1014)

    // Surfaces
    public static let surface = Color(hex: 0x16202D)
    public static let surfaceNeutral = Color(hex: 0x23262E)
    public static let surfaceHover = Color(hex: 0x2A475E)
    public static let divider = Color.white.opacity(0.08)

    // Text
    public static let textTitle = Color.white
    public static let textBody = Color(hex: 0xC7D5E0)
    public static let textSecondary = Color(hex: 0x8F98A0)
    public static let textMuted = Color(hex: 0x67707B)

    // Accents
    public static let accent = Color(hex: 0x1A9FFF)
    public static let accentLink = Color(hex: 0x66C0F4)

    public static var play: LinearGradient {
        LinearGradient(colors: [Color(hex: 0x75B022), Color(hex: 0x588A1B)], startPoint: .top, endPoint: .bottom)
    }
    public static var install: LinearGradient {
        LinearGradient(colors: [Color(hex: 0x47BFFF), Color(hex: 0x1A44C2)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // Prices
    public static let discountBg = Color(hex: 0x4C6B22)
    public static let discountText = Color(hex: 0xBEEE11)
    public static let priceBg = Color.black.opacity(0.25)
    public static let priceOriginal = Color(hex: 0x738895)

    // Reviews
    public static let reviewPositive = Color(hex: 0x66C0F4)
    public static let reviewMixed = Color(hex: 0xB9A074)
    public static let reviewNegative = Color(hex: 0xA34C25)

    // Presence
    public static let statusInGame = Color(hex: 0x90BA3C)
    public static let statusOnline = Color(hex: 0x57CBDE)
    public static let statusAway = Color(hex: 0x57CBDE, opacity: 0.5)
    public static let statusOffline = Color(hex: 0x898989)

    public static func reviewColor(_ tone: String) -> Color {
        switch tone {
        case "positive": reviewPositive
        case "mixed": reviewMixed
        default: reviewNegative
        }
    }

    public static func statusColor(_ status: String) -> Color {
        switch status {
        case "inGame": statusInGame
        case "online": statusOnline
        case "away": statusAway
        default: statusOffline
        }
    }

    public static var storeBackground: LinearGradient {
        LinearGradient(colors: [storeTop, storeBottom], startPoint: .top, endPoint: .bottom)
    }

    public static var libraryBackground: LinearGradient {
        LinearGradient(colors: [libraryTop, libraryBottom], startPoint: .top, endPoint: .bottom)
    }
}

/// Spacing scale: 4 · 8 · 12 · 16 · 24 · 32 · 48.
public enum Space {
    public static let xxs: CGFloat = 4
    public static let xs: CGFloat = 8
    public static let s: CGFloat = 12
    public static let m: CGFloat = 16
    public static let l: CGFloat = 24
    public static let xl: CGFloat = 32
    public static let xxl: CGFloat = 48
}

public enum Radius {
    public static let card: CGFloat = 6
    public static let button: CGFloat = 4
    public static let avatar: CGFloat = 4
}

/// Artwork aspect ratios (width / height).
public enum Aspect {
    public static let portrait: CGFloat = 2.0 / 3.0
    public static let header: CGFloat = 460.0 / 215.0
    public static let capsule: CGFloat = 616.0 / 353.0
    public static let smallCapsule: CGFloat = 231.0 / 87.0
    public static let hero: CGFloat = 3.1
    public static let screenshot: CGFloat = 16.0 / 9.0
}

// MARK: - Layout environment

public enum SizeClass: Sendable {
    case compact, regular
}

public struct LayoutMetrics: Sendable, Equatable {
    public var width: CGFloat
    public var isCompact: Bool { width < 700 }
    public var gutter: CGFloat { isCompact ? Space.m : (width < 1100 ? Space.l : Space.xl) }

    public init(width: CGFloat) { self.width = width }
}

extension EnvironmentValues {
    @Entry public var layout = LayoutMetrics(width: 1024)
}

// MARK: - Typography helpers

extension Text {
    /// UPPERCASE, semibold, tracked section header (DESIGN §1 Type).
    public func sectionHeaderStyle(size: CGFloat = 14) -> some View {
        self.font(.system(size: size, weight: .semibold))
            .tracking(size * 0.06)
            .foregroundStyle(Steam.textTitle.opacity(0.9))
            .textCase(.uppercase)
    }

    /// Small uppercase caption used under stats.
    public func captionCaps(size: CGFloat = 11, color: Color = Steam.textSecondary) -> some View {
        self.font(.system(size: size, weight: .medium))
            .tracking(size * 0.08)
            .foregroundStyle(color)
            .textCase(.uppercase)
    }
}
