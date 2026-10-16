// C# mirror of core/crates/steam-model/src/lib.rs.
// The JSON contract is camelCase; property names here are PascalCase and are
// mapped by the camelCase naming policy in SnapshotJsonContext.
using System.Collections.Generic;

namespace NativeSteam.Models;

public sealed class Snapshot
{
    public uint SchemaVersion { get; set; }
    public string GeneratedAt { get; set; } = "";
    public string Region { get; set; } = "";
    public UserProfile User { get; set; } = new();
    public Store Store { get; set; } = new();
    public Library Library { get; set; } = new();
    public Community Community { get; set; } = new();
    public List<Friend> Friends { get; set; } = new();
}

// ---------------------------------------------------------------------------
// Shared building blocks
// ---------------------------------------------------------------------------

public sealed class Images
{
    public string Header { get; set; } = "";
    public string Capsule { get; set; } = "";
    public string SmallCapsule { get; set; } = "";
    public string? Portrait { get; set; }
    public string? Hero { get; set; }
    public string? Logo { get; set; }
    public string? Background { get; set; }
}

public sealed class Platforms
{
    public bool Windows { get; set; }
    public bool Mac { get; set; }
    public bool Linux { get; set; }
}

public sealed class Price
{
    public string Currency { get; set; } = "";
    public uint Initial { get; set; }
    public uint FinalPrice { get; set; }
    public uint DiscountPercent { get; set; }
    public string InitialLabel { get; set; } = "";
    public string FinalLabel { get; set; } = "";
    public string? DiscountLabel { get; set; }
    public bool IsFree { get; set; }
}

public sealed class Screenshot
{
    public string Thumbnail { get; set; } = "";
    public string Full { get; set; } = "";
}

public sealed class ReviewSummary
{
    public string Label { get; set; } = "";
    public uint PercentPositive { get; set; }
    public ulong Total { get; set; }
    public string TotalLabel { get; set; } = "";
    /// <summary>"positive" | "mixed" | "negative"</summary>
    public string Tone { get; set; } = "";
}

public sealed class Achievement
{
    public string Name { get; set; } = "";
    public string IconUrl { get; set; } = "";
    public bool Unlocked { get; set; }
    public string? UnlockedLabel { get; set; }
}

// ---------------------------------------------------------------------------
// Store
// ---------------------------------------------------------------------------

public sealed class StoreItem
{
    public uint AppId { get; set; }
    public string Name { get; set; } = "";
    public Images Images { get; set; } = new();
    public Price? Price { get; set; }
    public Platforms Platforms { get; set; } = new();
    /// <summary>"full" | "partial" | null</summary>
    public string? ControllerSupport { get; set; }
    public string? ShortDescription { get; set; }
    public List<string> Genres { get; set; } = new();
    public List<string> Developers { get; set; } = new();
    public string? ReleaseDate { get; set; }
    public bool ComingSoon { get; set; }
    public ReviewSummary? Review { get; set; }
    public List<Screenshot> Screenshots { get; set; } = new();
    public uint? Metacritic { get; set; }
    public string? DiscountEndsLabel { get; set; }
}

public sealed class ChartEntry
{
    public uint Rank { get; set; }
    public uint AppId { get; set; }
    public string Name { get; set; } = "";
    public Images Images { get; set; } = new();
    public ulong CurrentPlayers { get; set; }
    public string CurrentPlayersLabel { get; set; } = "";
    public ulong PeakToday { get; set; }
    public string PeakTodayLabel { get; set; } = "";
    public Price? Price { get; set; }
}

public sealed class Tag
{
    public uint Id { get; set; }
    public string Name { get; set; } = "";
}

public sealed class Store
{
    public List<StoreItem> Featured { get; set; } = new();
    public List<StoreItem> Specials { get; set; } = new();
    public List<StoreItem> TopSellers { get; set; } = new();
    public List<StoreItem> NewReleases { get; set; } = new();
    public List<StoreItem> ComingSoon { get; set; } = new();
    public List<ChartEntry> MostPlayed { get; set; } = new();
    public List<Tag> PopularTags { get; set; } = new();
}

// ---------------------------------------------------------------------------
// Library
// ---------------------------------------------------------------------------

public sealed class AchievementProgress
{
    public uint Unlocked { get; set; }
    public uint Total { get; set; }
    public float Fraction { get; set; }
    public List<Achievement> Highlighted { get; set; } = new();
}

public sealed class LibraryGame
{
    public uint AppId { get; set; }
    public string Name { get; set; } = "";
    public Images Images { get; set; } = new();
    public uint PlaytimeMinutes { get; set; }
    public string PlaytimeLabel { get; set; } = "";
    public uint PlaytimeTwoWeeksMinutes { get; set; }
    public string? PlaytimeTwoWeeksLabel { get; set; }
    public string? LastPlayed { get; set; }
    public string LastPlayedLabel { get; set; } = "";
    public bool Installed { get; set; }
    public ulong SizeOnDiskBytes { get; set; }
    public string SizeLabel { get; set; } = "";
    public bool Favorite { get; set; }
    public bool UpdateAvailable { get; set; }
    public AchievementProgress? Achievements { get; set; }
    public string? ControllerSupport { get; set; }
    public List<string> Genres { get; set; } = new();
    public List<string> Developers { get; set; } = new();
    public string? ShortDescription { get; set; }
    public string? ReleaseDate { get; set; }
    public List<Screenshot> Screenshots { get; set; } = new();
    public List<string> FriendsPlaying { get; set; } = new();
}

public sealed class Collection
{
    public string Id { get; set; } = "";
    public string Name { get; set; } = "";
    /// <summary>"dynamic" or "user"</summary>
    public string Kind { get; set; } = "";
    public List<uint> AppIds { get; set; } = new();
}

public sealed class Library
{
    public List<LibraryGame> Games { get; set; } = new();
    public List<Collection> Collections { get; set; } = new();
    public List<uint> RecentAppIds { get; set; } = new();
}

// ---------------------------------------------------------------------------
// Community
// ---------------------------------------------------------------------------

public sealed class ActivityReview
{
    public bool Recommended { get; set; }
    public string Body { get; set; } = "";
    public string HoursLabel { get; set; } = "";
}

public sealed class ActivityItem
{
    public string Id { get; set; } = "";
    /// <summary>"achievement" | "screenshot" | "review" | "nowPlaying" | "newGame"</summary>
    public string Kind { get; set; } = "";
    public string FriendId { get; set; } = "";
    public string FriendName { get; set; } = "";
    public string FriendAvatarUrl { get; set; } = "";
    public uint AppId { get; set; }
    public string AppName { get; set; } = "";
    public Images AppImages { get; set; } = new();
    public string Timestamp { get; set; } = "";
    public string TimeLabel { get; set; } = "";
    public string Headline { get; set; } = "";
    public Achievement? Achievement { get; set; }
    public string? ImageUrl { get; set; }
    public ActivityReview? Review { get; set; }
    public uint Likes { get; set; }
    public uint Comments { get; set; }
}

public sealed class NewsItem
{
    public string Id { get; set; } = "";
    public uint AppId { get; set; }
    public string AppName { get; set; } = "";
    public Images AppImages { get; set; } = new();
    public string Title { get; set; } = "";
    public string? Author { get; set; }
    public string Url { get; set; } = "";
    public string Date { get; set; } = "";
    public string DateLabel { get; set; } = "";
    public string Excerpt { get; set; } = "";
    public string? ImageUrl { get; set; }
    public string FeedLabel { get; set; } = "";
}

public sealed class Hub
{
    public uint AppId { get; set; }
    public string Name { get; set; } = "";
    public Images Images { get; set; } = new();
    public ulong CurrentPlayers { get; set; }
    public string CurrentPlayersLabel { get; set; } = "";
    public uint Rank { get; set; }
}

public sealed class Community
{
    public List<ActivityItem> Activity { get; set; } = new();
    public List<NewsItem> News { get; set; } = new();
    public List<Hub> Hubs { get; set; } = new();
}

// ---------------------------------------------------------------------------
// People
// ---------------------------------------------------------------------------

public sealed class GameRef
{
    public uint AppId { get; set; }
    public string Name { get; set; } = "";
}

public sealed class Friend
{
    public string SteamId { get; set; } = "";
    public string PersonaName { get; set; } = "";
    public string AvatarUrl { get; set; } = "";
    public uint Level { get; set; }
    public string LevelColor { get; set; } = "";
    /// <summary>"inGame" | "online" | "away" | "offline"</summary>
    public string Status { get; set; } = "";
    public string StatusLabel { get; set; } = "";
    public GameRef? Game { get; set; }
}

public sealed class Badge
{
    public string Name { get; set; } = "";
    public string Description { get; set; } = "";
    public uint Level { get; set; }
    public uint Xp { get; set; }
    public string Color { get; set; } = "";
    /// <summary>"years" | "sale" | "collector" | "community" | "awards" | "deck" | "trophy"</summary>
    public string Icon { get; set; } = "";
}

public sealed class ProfileStats
{
    public uint GamesOwned { get; set; }
    public uint Achievements { get; set; }
    public uint PerfectGames { get; set; }
    public uint Friends { get; set; }
    public uint Screenshots { get; set; }
    public uint Reviews { get; set; }
    public uint Badges { get; set; }
    public string HoursLabel { get; set; } = "";
}

public sealed class RecentGame
{
    public uint AppId { get; set; }
    public string Name { get; set; } = "";
    public Images Images { get; set; } = new();
    public string TwoWeeksLabel { get; set; } = "";
    public string TotalLabel { get; set; } = "";
    public string LastPlayedLabel { get; set; } = "";
    public AchievementProgress? Achievements { get; set; }
}

public sealed class ShowcaseAchievement
{
    public uint AppId { get; set; }
    public string AppName { get; set; } = "";
    public Achievement Achievement { get; set; } = new();
}

public sealed class ShowcaseScreenshot
{
    public uint AppId { get; set; }
    public string AppName { get; set; } = "";
    public string Url { get; set; } = "";
}

public sealed class UserProfile
{
    public string SteamId { get; set; } = "";
    public string PersonaName { get; set; } = "";
    public string RealName { get; set; } = "";
    public string AvatarUrl { get; set; } = "";
    public string BackgroundUrl { get; set; } = "";
    public string Country { get; set; } = "";
    public uint Level { get; set; }
    public string LevelColor { get; set; } = "";
    public uint Xp { get; set; }
    public string XpToNextLabel { get; set; } = "";
    public float XpFraction { get; set; }
    public string Status { get; set; } = "";
    public string Summary { get; set; } = "";
    public string MemberSinceLabel { get; set; } = "";
    public string YearsLabel { get; set; } = "";
    public ProfileStats Stats { get; set; } = new();
    public List<Badge> Badges { get; set; } = new();
    public GameRef FavoriteGame { get; set; } = new();
    public List<RecentGame> RecentGames { get; set; } = new();
    public List<ShowcaseAchievement> RareAchievements { get; set; } = new();
    public List<ShowcaseScreenshot> Screenshots { get; set; } = new();
}
