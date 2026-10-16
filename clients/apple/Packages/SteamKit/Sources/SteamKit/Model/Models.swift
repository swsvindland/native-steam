import Foundation

// Swift mirror of `core/crates/steam-model/src/lib.rs`.
// JSON keys are camelCase, so the property names map 1:1 with no CodingKeys.
// `*Label` fields are pre-formatted display strings and are rendered as-is.

public struct Snapshot: Codable, Sendable {
    public let schemaVersion: Int
    public let generatedAt: String
    public let region: String
    public let user: UserProfile
    public let store: Store
    public let library: Library
    public let community: Community
    public let friends: [Friend]
}

// MARK: - Shared building blocks

public struct Images: Codable, Hashable, Sendable {
    /// 460x215 store header.
    public let header: String
    /// 616x353 large store capsule.
    public let capsule: String
    /// 231x87 small capsule.
    public let smallCapsule: String
    /// 600x900 library portrait cover.
    public let portrait: String?
    /// 1920x620 library hero (no text).
    public let hero: String?
    /// Transparent title logo for overlaying on `hero`.
    public let logo: String?
    /// Full-bleed store page background.
    public let background: String?
}

public struct Platforms: Codable, Hashable, Sendable {
    public let windows: Bool
    public let mac: Bool
    public let linux: Bool
}

public struct Price: Codable, Hashable, Sendable {
    public let currency: String
    public let initial: Int
    public let finalPrice: Int
    public let discountPercent: Int
    public let initialLabel: String
    public let finalLabel: String
    public let discountLabel: String?
    public let isFree: Bool
}

public struct Screenshot: Codable, Hashable, Sendable {
    public let thumbnail: String
    public let full: String
}

public struct ReviewSummary: Codable, Hashable, Sendable {
    public let label: String
    public let percentPositive: Int
    public let total: Int
    public let totalLabel: String
    /// "positive" | "mixed" | "negative"
    public let tone: String
}

public struct Achievement: Codable, Hashable, Sendable {
    public let name: String
    public let iconUrl: String
    public let unlocked: Bool
    public let unlockedLabel: String?
}

// MARK: - Store

public struct StoreItem: Codable, Hashable, Sendable, Identifiable {
    public let appId: Int
    public let name: String
    public let images: Images
    public let price: Price?
    public let platforms: Platforms
    /// "full" | "partial" | nil
    public let controllerSupport: String?
    public let shortDescription: String?
    public let genres: [String]
    public let developers: [String]
    public let releaseDate: String?
    public let comingSoon: Bool
    public let review: ReviewSummary?
    public let screenshots: [Screenshot]
    public let metacritic: Int?
    public let discountEndsLabel: String?

    public var id: Int { appId }
}

public struct ChartEntry: Codable, Hashable, Sendable, Identifiable {
    public let rank: Int
    public let appId: Int
    public let name: String
    public let images: Images
    public let currentPlayers: Int
    public let currentPlayersLabel: String
    public let peakToday: Int
    public let peakTodayLabel: String
    public let price: Price?

    public var id: Int { appId }
}

public struct Tag: Codable, Hashable, Sendable, Identifiable {
    public let id: Int
    public let name: String
}

public struct Store: Codable, Sendable {
    public let featured: [StoreItem]
    public let specials: [StoreItem]
    public let topSellers: [StoreItem]
    public let newReleases: [StoreItem]
    public let comingSoon: [StoreItem]
    public let mostPlayed: [ChartEntry]
    public let popularTags: [Tag]
}

// MARK: - Library

public struct AchievementProgress: Codable, Hashable, Sendable {
    public let unlocked: Int
    public let total: Int
    public let fraction: Double
    public let highlighted: [Achievement]
}

public struct LibraryGame: Codable, Hashable, Sendable, Identifiable {
    public let appId: Int
    public let name: String
    public let images: Images
    public let playtimeMinutes: Int
    public let playtimeLabel: String
    public let playtimeTwoWeeksMinutes: Int
    public let playtimeTwoWeeksLabel: String?
    public let lastPlayed: String?
    public let lastPlayedLabel: String
    public let installed: Bool
    public let sizeOnDiskBytes: Int
    public let sizeLabel: String
    public let favorite: Bool
    public let updateAvailable: Bool
    public let achievements: AchievementProgress?
    public let controllerSupport: String?
    public let genres: [String]
    public let developers: [String]
    public let shortDescription: String?
    public let releaseDate: String?
    public let screenshots: [Screenshot]
    public let friendsPlaying: [String]

    public var id: Int { appId }
}

/// `Collection` in the Rust model (renamed to avoid clashing with `Swift.Collection`).
public struct GameCollection: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let name: String
    /// "dynamic" | "user"
    public let kind: String
    public let appIds: [Int]
}

public struct Library: Codable, Sendable {
    public let games: [LibraryGame]
    public let collections: [GameCollection]
    public let recentAppIds: [Int]
}

// MARK: - Community

public struct ActivityReview: Codable, Hashable, Sendable {
    public let recommended: Bool
    public let body: String
    public let hoursLabel: String
}

public struct ActivityItem: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    /// "achievement" | "screenshot" | "review" | "nowPlaying" | "newGame"
    public let kind: String
    public let friendId: String
    public let friendName: String
    public let friendAvatarUrl: String
    public let appId: Int
    public let appName: String
    public let appImages: Images
    public let timestamp: String
    public let timeLabel: String
    public let headline: String
    public let achievement: Achievement?
    public let imageUrl: String?
    public let review: ActivityReview?
    public let likes: Int
    public let comments: Int
}

public struct NewsItem: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let appId: Int
    public let appName: String
    public let appImages: Images
    public let title: String
    public let author: String?
    public let url: String
    public let date: String
    public let dateLabel: String
    public let excerpt: String
    public let imageUrl: String?
    public let feedLabel: String
}

public struct Hub: Codable, Hashable, Sendable, Identifiable {
    public let appId: Int
    public let name: String
    public let images: Images
    public let currentPlayers: Int
    public let currentPlayersLabel: String
    public let rank: Int

    public var id: Int { appId }
}

public struct Community: Codable, Sendable {
    public let activity: [ActivityItem]
    public let news: [NewsItem]
    public let hubs: [Hub]
}

// MARK: - People

public struct GameRef: Codable, Hashable, Sendable {
    public let appId: Int
    public let name: String
}

public struct Friend: Codable, Hashable, Sendable, Identifiable {
    public let steamId: String
    public let personaName: String
    public let avatarUrl: String
    public let level: Int
    public let levelColor: String
    /// "inGame" | "online" | "away" | "offline"
    public let status: String
    public let statusLabel: String
    public let game: GameRef?

    public var id: String { steamId }
}

public struct Badge: Codable, Hashable, Sendable, Identifiable {
    public let name: String
    public let description: String
    public let level: Int
    public let xp: Int
    public let color: String
    /// "years" | "sale" | "collector" | "community" | "awards" | "deck" | "trophy"
    public let icon: String

    public var id: String { name }
}

public struct ProfileStats: Codable, Hashable, Sendable {
    public let gamesOwned: Int
    public let achievements: Int
    public let perfectGames: Int
    public let friends: Int
    public let screenshots: Int
    public let reviews: Int
    public let badges: Int
    public let hoursLabel: String
}

public struct RecentGame: Codable, Hashable, Sendable, Identifiable {
    public let appId: Int
    public let name: String
    public let images: Images
    public let twoWeeksLabel: String
    public let totalLabel: String
    public let lastPlayedLabel: String
    public let achievements: AchievementProgress?

    public var id: Int { appId }
}

public struct ShowcaseAchievement: Codable, Hashable, Sendable {
    public let appId: Int
    public let appName: String
    public let achievement: Achievement
}

public struct ShowcaseScreenshot: Codable, Hashable, Sendable {
    public let appId: Int
    public let appName: String
    public let url: String
}

public struct UserProfile: Codable, Sendable {
    public let steamId: String
    public let personaName: String
    public let realName: String
    public let avatarUrl: String
    public let backgroundUrl: String
    public let country: String
    public let level: Int
    public let levelColor: String
    public let xp: Int
    public let xpToNextLabel: String
    public let xpFraction: Double
    public let status: String
    public let summary: String
    public let memberSinceLabel: String
    public let yearsLabel: String
    public let stats: ProfileStats
    public let badges: [Badge]
    public let favoriteGame: GameRef
    public let recentGames: [RecentGame]
    public let rareAchievements: [ShowcaseAchievement]
    public let screenshots: [ShowcaseScreenshot]
}
