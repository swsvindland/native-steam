package dev.nativesteam.android.data

import androidx.compose.runtime.Immutable
import kotlinx.serialization.Serializable

/*
 * Kotlin mirror of core/crates/steam-model/src/lib.rs.
 * JSON is camelCase, which matches Kotlin property names one-to-one.
 * Every `*Label` field is a pre-formatted display string: render as-is.
 */

@Immutable
@Serializable
data class Snapshot(
    val schemaVersion: Int,
    val generatedAt: String,
    val region: String,
    val user: UserProfile,
    val store: Store,
    val library: Library,
    val community: Community,
    val friends: List<Friend>,
)

// ---------------------------------------------------------------------------
// Shared building blocks
// ---------------------------------------------------------------------------

@Immutable
@Serializable
data class Images(
    val header: String,
    val capsule: String,
    val smallCapsule: String,
    val portrait: String? = null,
    val hero: String? = null,
    val logo: String? = null,
    val background: String? = null,
)

@Immutable
@Serializable
data class Platforms(
    val windows: Boolean = false,
    val mac: Boolean = false,
    val linux: Boolean = false,
)

@Immutable
@Serializable
data class Price(
    val currency: String,
    val initial: Long,
    val finalPrice: Long,
    val discountPercent: Int,
    val initialLabel: String,
    val finalLabel: String,
    val discountLabel: String? = null,
    val isFree: Boolean,
)

@Immutable
@Serializable
data class Screenshot(
    val thumbnail: String,
    val full: String,
)

@Immutable
@Serializable
data class ReviewSummary(
    val label: String,
    val percentPositive: Int,
    val total: Long,
    val totalLabel: String,
    /** "positive" | "mixed" | "negative" */
    val tone: String,
)

@Immutable
@Serializable
data class Achievement(
    val name: String,
    val iconUrl: String,
    val unlocked: Boolean,
    val unlockedLabel: String? = null,
)

// ---------------------------------------------------------------------------
// Store
// ---------------------------------------------------------------------------

@Immutable
@Serializable
data class StoreItem(
    val appId: Int,
    val name: String,
    val images: Images,
    val price: Price? = null,
    val platforms: Platforms = Platforms(),
    /** "full" | "partial" | null */
    val controllerSupport: String? = null,
    val shortDescription: String? = null,
    val genres: List<String> = emptyList(),
    val developers: List<String> = emptyList(),
    val releaseDate: String? = null,
    val comingSoon: Boolean = false,
    val review: ReviewSummary? = null,
    val screenshots: List<Screenshot> = emptyList(),
    val metacritic: Int? = null,
    val discountEndsLabel: String? = null,
)

@Immutable
@Serializable
data class ChartEntry(
    val rank: Int,
    val appId: Int,
    val name: String,
    val images: Images,
    val currentPlayers: Long,
    val currentPlayersLabel: String,
    val peakToday: Long,
    val peakTodayLabel: String,
    val price: Price? = null,
)

@Immutable
@Serializable
data class Tag(val id: Int, val name: String)

@Immutable
@Serializable
data class Store(
    val featured: List<StoreItem>,
    val specials: List<StoreItem>,
    val topSellers: List<StoreItem>,
    val newReleases: List<StoreItem>,
    val comingSoon: List<StoreItem>,
    val mostPlayed: List<ChartEntry>,
    val popularTags: List<Tag>,
)

// ---------------------------------------------------------------------------
// Library
// ---------------------------------------------------------------------------

@Immutable
@Serializable
data class AchievementProgress(
    val unlocked: Int,
    val total: Int,
    val fraction: Float,
    val highlighted: List<Achievement> = emptyList(),
)

@Immutable
@Serializable
data class LibraryGame(
    val appId: Int,
    val name: String,
    val images: Images,
    val playtimeMinutes: Long,
    val playtimeLabel: String,
    val playtimeTwoWeeksMinutes: Long,
    val playtimeTwoWeeksLabel: String? = null,
    val lastPlayed: String? = null,
    val lastPlayedLabel: String,
    val installed: Boolean,
    val sizeOnDiskBytes: Long,
    val sizeLabel: String,
    val favorite: Boolean,
    val updateAvailable: Boolean,
    val achievements: AchievementProgress? = null,
    val controllerSupport: String? = null,
    val genres: List<String> = emptyList(),
    val developers: List<String> = emptyList(),
    val shortDescription: String? = null,
    val releaseDate: String? = null,
    val screenshots: List<Screenshot> = emptyList(),
    val friendsPlaying: List<String> = emptyList(),
)

@Immutable
@Serializable
data class Collection(
    val id: String,
    val name: String,
    /** "dynamic" or "user" */
    val kind: String,
    val appIds: List<Int>,
)

@Immutable
@Serializable
data class Library(
    val games: List<LibraryGame>,
    val collections: List<Collection>,
    val recentAppIds: List<Int>,
)

// ---------------------------------------------------------------------------
// Community
// ---------------------------------------------------------------------------

@Immutable
@Serializable
data class ActivityReview(
    val recommended: Boolean,
    val body: String,
    val hoursLabel: String,
)

@Immutable
@Serializable
data class ActivityItem(
    val id: String,
    /** "achievement" | "screenshot" | "review" | "nowPlaying" | "newGame" */
    val kind: String,
    val friendId: String,
    val friendName: String,
    val friendAvatarUrl: String,
    val appId: Int,
    val appName: String,
    val appImages: Images,
    val timestamp: String,
    val timeLabel: String,
    val headline: String,
    val achievement: Achievement? = null,
    val imageUrl: String? = null,
    val review: ActivityReview? = null,
    val likes: Int,
    val comments: Int,
)

@Immutable
@Serializable
data class NewsItem(
    val id: String,
    val appId: Int,
    val appName: String,
    val appImages: Images,
    val title: String,
    val author: String? = null,
    val url: String,
    val date: String,
    val dateLabel: String,
    val excerpt: String,
    val imageUrl: String? = null,
    val feedLabel: String,
)

@Immutable
@Serializable
data class Hub(
    val appId: Int,
    val name: String,
    val images: Images,
    val currentPlayers: Long,
    val currentPlayersLabel: String,
    val rank: Int,
)

@Immutable
@Serializable
data class Community(
    val activity: List<ActivityItem>,
    val news: List<NewsItem>,
    val hubs: List<Hub>,
)

// ---------------------------------------------------------------------------
// People
// ---------------------------------------------------------------------------

@Immutable
@Serializable
data class GameRef(val appId: Int, val name: String)

@Immutable
@Serializable
data class Friend(
    val steamId: String,
    val personaName: String,
    val avatarUrl: String,
    val level: Int,
    val levelColor: String,
    /** "inGame" | "online" | "away" | "offline" */
    val status: String,
    val statusLabel: String,
    val game: GameRef? = null,
)

@Immutable
@Serializable
data class Badge(
    val name: String,
    val description: String,
    val level: Int,
    val xp: Int,
    val color: String,
    /** "years" | "sale" | "collector" | "community" | "awards" | "deck" | "trophy" */
    val icon: String,
)

@Immutable
@Serializable
data class ProfileStats(
    val gamesOwned: Int,
    val achievements: Int,
    val perfectGames: Int,
    val friends: Int,
    val screenshots: Int,
    val reviews: Int,
    val badges: Int,
    val hoursLabel: String,
)

@Immutable
@Serializable
data class RecentGame(
    val appId: Int,
    val name: String,
    val images: Images,
    val twoWeeksLabel: String,
    val totalLabel: String,
    val lastPlayedLabel: String,
    val achievements: AchievementProgress? = null,
)

@Immutable
@Serializable
data class ShowcaseAchievement(
    val appId: Int,
    val appName: String,
    val achievement: Achievement,
)

@Immutable
@Serializable
data class ShowcaseScreenshot(
    val appId: Int,
    val appName: String,
    val url: String,
)

@Immutable
@Serializable
data class UserProfile(
    val steamId: String,
    val personaName: String,
    val realName: String,
    val avatarUrl: String,
    val backgroundUrl: String,
    val country: String,
    val level: Int,
    val levelColor: String,
    val xp: Int,
    val xpToNextLabel: String,
    val xpFraction: Float,
    val status: String,
    val summary: String,
    val memberSinceLabel: String,
    val yearsLabel: String,
    val stats: ProfileStats,
    val badges: List<Badge>,
    val favoriteGame: GameRef,
    val recentGames: List<RecentGame>,
    val rareAchievements: List<ShowcaseAchievement>,
    val screenshots: List<ShowcaseScreenshot>,
)
