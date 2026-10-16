//! Shared data model for Native Steam.
//!
//! Everything here serializes to camelCase JSON. `data/snapshot.json` is the
//! contract every client decodes (Swift, Kotlin, C#, TypeScript and Rust), so
//! keep field names stable and prefer adding optional fields over renaming.
//!
//! Display strings (`*Label` fields) are pre-formatted by the generator so that
//! all six clients render identical text without reimplementing formatting.

use serde::{Deserialize, Serialize};

pub const SCHEMA_VERSION: u32 = 1;

#[derive(Serialize, Deserialize, Clone, Debug)]
#[serde(rename_all = "camelCase")]
pub struct Snapshot {
    pub schema_version: u32,
    /// RFC 3339 timestamp of when the snapshot was generated.
    pub generated_at: String,
    /// Store region the prices came from (e.g. "us").
    pub region: String,
    pub user: UserProfile,
    pub store: Store,
    pub library: Library,
    pub community: Community,
    pub friends: Vec<Friend>,
}

impl Snapshot {
    pub fn from_json(json: &str) -> serde_json::Result<Self> {
        serde_json::from_str(json)
    }

    pub fn library_game(&self, app_id: u32) -> Option<&LibraryGame> {
        self.library.games.iter().find(|g| g.app_id == app_id)
    }

    pub fn friend(&self, steam_id: &str) -> Option<&Friend> {
        self.friends.iter().find(|f| f.steam_id == steam_id)
    }
}

// ---------------------------------------------------------------------------
// Shared building blocks
// ---------------------------------------------------------------------------

/// Steam CDN artwork for an app. Every URL is absolute.
#[derive(Serialize, Deserialize, Clone, Debug, Default)]
#[serde(rename_all = "camelCase")]
pub struct Images {
    /// 460x215 store header.
    pub header: String,
    /// 616x353 large store capsule.
    pub capsule: String,
    /// 231x87 small capsule.
    pub small_capsule: String,
    /// 600x900 library portrait cover. `None` if the app has no library art.
    pub portrait: Option<String>,
    /// 1920x620 library hero (no text, meant to sit behind `logo`).
    pub hero: Option<String>,
    /// Transparent PNG title logo for overlaying on `hero`.
    pub logo: Option<String>,
    /// Full-bleed store page background.
    pub background: Option<String>,
}

#[derive(Serialize, Deserialize, Clone, Debug, Default)]
#[serde(rename_all = "camelCase")]
pub struct Platforms {
    pub windows: bool,
    pub mac: bool,
    pub linux: bool,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
#[serde(rename_all = "camelCase")]
pub struct Price {
    pub currency: String,
    /// Price in minor units (cents) before discount.
    pub initial: u32,
    /// Price in minor units (cents) after discount.
    pub final_price: u32,
    pub discount_percent: u32,
    /// e.g. "$39.99"
    pub initial_label: String,
    /// e.g. "$35.99" or "Free to Play"
    pub final_label: String,
    /// e.g. "-10%"; `None` when not discounted.
    pub discount_label: Option<String>,
    pub is_free: bool,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
#[serde(rename_all = "camelCase")]
pub struct Screenshot {
    pub thumbnail: String,
    pub full: String,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
#[serde(rename_all = "camelCase")]
pub struct ReviewSummary {
    /// e.g. "Overwhelmingly Positive"
    pub label: String,
    /// 0-100
    pub percent_positive: u32,
    pub total: u64,
    /// e.g. "154,526 reviews"
    pub total_label: String,
    /// "positive" | "mixed" | "negative" — drives the label colour.
    pub tone: String,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
#[serde(rename_all = "camelCase")]
pub struct Achievement {
    pub name: String,
    pub icon_url: String,
    pub unlocked: bool,
    /// e.g. "Unlocked Oct 3" — only for unlocked achievements.
    pub unlocked_label: Option<String>,
}

// ---------------------------------------------------------------------------
// Store
// ---------------------------------------------------------------------------

#[derive(Serialize, Deserialize, Clone, Debug)]
#[serde(rename_all = "camelCase")]
pub struct StoreItem {
    pub app_id: u32,
    pub name: String,
    pub images: Images,
    /// `None` for unreleased titles with no price yet.
    pub price: Option<Price>,
    pub platforms: Platforms,
    /// "full" | "partial" | null
    pub controller_support: Option<String>,
    pub short_description: Option<String>,
    pub genres: Vec<String>,
    pub developers: Vec<String>,
    /// Human release date as Steam reports it, e.g. "Sep 17, 2020" or "Q1 2027".
    pub release_date: Option<String>,
    pub coming_soon: bool,
    pub review: Option<ReviewSummary>,
    pub screenshots: Vec<Screenshot>,
    pub metacritic: Option<u32>,
    /// e.g. "Offer ends Oct 30"
    pub discount_ends_label: Option<String>,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
#[serde(rename_all = "camelCase")]
pub struct ChartEntry {
    pub rank: u32,
    pub app_id: u32,
    pub name: String,
    pub images: Images,
    pub current_players: u64,
    /// e.g. "1.2M playing"
    pub current_players_label: String,
    pub peak_today: u64,
    /// e.g. "Peak 1.1M today"
    pub peak_today_label: String,
    pub price: Option<Price>,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
#[serde(rename_all = "camelCase")]
pub struct Tag {
    pub id: u32,
    pub name: String,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
#[serde(rename_all = "camelCase")]
pub struct Store {
    /// "Featured & Recommended" hero carousel.
    pub featured: Vec<StoreItem>,
    pub specials: Vec<StoreItem>,
    pub top_sellers: Vec<StoreItem>,
    pub new_releases: Vec<StoreItem>,
    pub coming_soon: Vec<StoreItem>,
    pub most_played: Vec<ChartEntry>,
    pub popular_tags: Vec<Tag>,
}

// ---------------------------------------------------------------------------
// Library
// ---------------------------------------------------------------------------

#[derive(Serialize, Deserialize, Clone, Debug)]
#[serde(rename_all = "camelCase")]
pub struct AchievementProgress {
    pub unlocked: u32,
    pub total: u32,
    /// 0.0 - 1.0
    pub fraction: f32,
    /// A handful of the game's showcase achievements with real icons.
    pub highlighted: Vec<Achievement>,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
#[serde(rename_all = "camelCase")]
pub struct LibraryGame {
    pub app_id: u32,
    pub name: String,
    pub images: Images,
    pub playtime_minutes: u32,
    /// e.g. "142.3 hrs on record"
    pub playtime_label: String,
    pub playtime_two_weeks_minutes: u32,
    /// e.g. "6.1 hrs past 2 weeks"
    pub playtime_two_weeks_label: Option<String>,
    /// RFC 3339; `None` if never played.
    pub last_played: Option<String>,
    /// e.g. "Today", "Yesterday", "Oct 3", "Never played"
    pub last_played_label: String,
    pub installed: bool,
    pub size_on_disk_bytes: u64,
    /// e.g. "12.4 GB"
    pub size_label: String,
    pub favorite: bool,
    pub update_available: bool,
    pub achievements: Option<AchievementProgress>,
    pub controller_support: Option<String>,
    pub genres: Vec<String>,
    pub developers: Vec<String>,
    pub short_description: Option<String>,
    pub release_date: Option<String>,
    pub screenshots: Vec<Screenshot>,
    /// Steam IDs of friends who own/play this game.
    pub friends_playing: Vec<String>,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
#[serde(rename_all = "camelCase")]
pub struct Collection {
    pub id: String,
    pub name: String,
    /// "dynamic" (All, Installed, Favorites…) or "user".
    pub kind: String,
    pub app_ids: Vec<u32>,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
#[serde(rename_all = "camelCase")]
pub struct Library {
    /// Sorted alphabetically.
    pub games: Vec<LibraryGame>,
    /// Ordered for display; the first is always "All Games".
    pub collections: Vec<Collection>,
    /// Most recently played first.
    pub recent_app_ids: Vec<u32>,
}

// ---------------------------------------------------------------------------
// Community
// ---------------------------------------------------------------------------

#[derive(Serialize, Deserialize, Clone, Debug)]
#[serde(rename_all = "camelCase")]
pub struct ActivityReview {
    pub recommended: bool,
    pub body: String,
    /// e.g. "84.2 hrs on record"
    pub hours_label: String,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
#[serde(rename_all = "camelCase")]
pub struct ActivityItem {
    pub id: String,
    /// "achievement" | "screenshot" | "review" | "nowPlaying" | "newGame"
    pub kind: String,
    pub friend_id: String,
    pub friend_name: String,
    pub friend_avatar_url: String,
    pub app_id: u32,
    pub app_name: String,
    pub app_images: Images,
    /// RFC 3339
    pub timestamp: String,
    /// e.g. "2 hours ago"
    pub time_label: String,
    /// Verb phrase shown between friend and game, e.g. "unlocked an achievement in".
    pub headline: String,
    pub achievement: Option<Achievement>,
    pub image_url: Option<String>,
    pub review: Option<ActivityReview>,
    pub likes: u32,
    pub comments: u32,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
#[serde(rename_all = "camelCase")]
pub struct NewsItem {
    pub id: String,
    pub app_id: u32,
    pub app_name: String,
    pub app_images: Images,
    pub title: String,
    pub author: Option<String>,
    pub url: String,
    /// RFC 3339
    pub date: String,
    /// e.g. "Oct 14"
    pub date_label: String,
    /// Plain text, BBCode stripped, ~280 chars.
    pub excerpt: String,
    pub image_url: Option<String>,
    /// e.g. "Community Announcements", "PC Gamer"
    pub feed_label: String,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
#[serde(rename_all = "camelCase")]
pub struct Hub {
    pub app_id: u32,
    pub name: String,
    pub images: Images,
    pub current_players: u64,
    /// e.g. "1.2M in-game"
    pub current_players_label: String,
    pub rank: u32,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
#[serde(rename_all = "camelCase")]
pub struct Community {
    /// Newest first.
    pub activity: Vec<ActivityItem>,
    /// Newest first; news for games in your library.
    pub news: Vec<NewsItem>,
    /// Popular community hubs by live player count.
    pub hubs: Vec<Hub>,
}

// ---------------------------------------------------------------------------
// People
// ---------------------------------------------------------------------------

#[derive(Serialize, Deserialize, Clone, Debug)]
#[serde(rename_all = "camelCase")]
pub struct GameRef {
    pub app_id: u32,
    pub name: String,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
#[serde(rename_all = "camelCase")]
pub struct Friend {
    pub steam_id: String,
    pub persona_name: String,
    pub avatar_url: String,
    pub level: u32,
    /// Hex colour of the Steam level ring, e.g. "#467a3c".
    pub level_color: String,
    /// "inGame" | "online" | "away" | "offline"
    pub status: String,
    /// e.g. "Hades", "Online", "Away", "Last online 3 hrs ago"
    pub status_label: String,
    pub game: Option<GameRef>,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
#[serde(rename_all = "camelCase")]
pub struct Badge {
    pub name: String,
    pub description: String,
    pub level: u32,
    pub xp: u32,
    /// Hex colour used to draw the badge medallion.
    pub color: String,
    /// SF Symbol / Material-ish keyword clients may map to an icon:
    /// "years" | "sale" | "collector" | "community" | "awards" | "deck" | "trophy".
    pub icon: String,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
#[serde(rename_all = "camelCase")]
pub struct ProfileStats {
    pub games_owned: u32,
    pub achievements: u32,
    pub perfect_games: u32,
    pub friends: u32,
    pub screenshots: u32,
    pub reviews: u32,
    pub badges: u32,
    /// e.g. "4,182 hrs"
    pub hours_label: String,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
#[serde(rename_all = "camelCase")]
pub struct RecentGame {
    pub app_id: u32,
    pub name: String,
    pub images: Images,
    /// e.g. "6.1 hrs past 2 weeks"
    pub two_weeks_label: String,
    /// e.g. "142.3 hrs on record"
    pub total_label: String,
    pub last_played_label: String,
    pub achievements: Option<AchievementProgress>,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
#[serde(rename_all = "camelCase")]
pub struct ShowcaseAchievement {
    pub app_id: u32,
    pub app_name: String,
    pub achievement: Achievement,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
#[serde(rename_all = "camelCase")]
pub struct UserProfile {
    pub steam_id: String,
    pub persona_name: String,
    pub real_name: String,
    pub avatar_url: String,
    /// Wide artwork for the profile banner.
    pub background_url: String,
    pub country: String,
    pub level: u32,
    pub level_color: String,
    pub xp: u32,
    /// e.g. "312 XP to level 48"
    pub xp_to_next_label: String,
    /// 0.0 - 1.0 progress to next level.
    pub xp_fraction: f32,
    pub status: String,
    pub summary: String,
    /// e.g. "Member since March 14, 2013"
    pub member_since_label: String,
    /// e.g. "Steam Years of Service: 13"
    pub years_label: String,
    pub stats: ProfileStats,
    pub badges: Vec<Badge>,
    pub favorite_game: GameRef,
    pub recent_games: Vec<RecentGame>,
    pub rare_achievements: Vec<ShowcaseAchievement>,
    pub screenshots: Vec<ShowcaseScreenshot>,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
#[serde(rename_all = "camelCase")]
pub struct ShowcaseScreenshot {
    pub app_id: u32,
    pub app_name: String,
    pub url: String,
}

// ---------------------------------------------------------------------------
// Helpers shared by the generator and the Rust (GTK) client
// ---------------------------------------------------------------------------

/// Steam level ring colour (cycles every 100 levels like the real client).
pub fn level_color(level: u32) -> &'static str {
    match (level % 100) / 10 {
        0 => "#9b9b9b",
        1 => "#c02942",
        2 => "#d95b43",
        3 => "#fecc23",
        4 => "#467a3c",
        5 => "#4e8ddb",
        6 => "#7652c9",
        7 => "#c252c9",
        8 => "#542437",
        _ => "#997c52",
    }
}

/// "1,234,567"
pub fn group_thousands(n: u64) -> String {
    let s = n.to_string();
    let mut out = String::with_capacity(s.len() + s.len() / 3);
    for (i, c) in s.chars().enumerate() {
        if i > 0 && (s.len() - i).is_multiple_of(3) {
            out.push(',');
        }
        out.push(c);
    }
    out
}

/// "1.2M", "874K", "932"
pub fn compact_count(n: u64) -> String {
    if n >= 1_000_000 {
        format!("{:.1}M", n as f64 / 1_000_000.0)
    } else if n >= 10_000 {
        format!("{}K", n / 1000)
    } else if n >= 1000 {
        format!("{:.1}K", n as f64 / 1000.0)
    } else {
        n.to_string()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn formats_counts() {
        assert_eq!(group_thousands(154526), "154,526");
        assert_eq!(group_thousands(999), "999");
        assert_eq!(compact_count(1_234_188), "1.2M");
        assert_eq!(compact_count(874_030), "874K");
        assert_eq!(compact_count(1_500), "1.5K");
    }

    #[test]
    fn level_colors_cycle() {
        assert_eq!(level_color(47), "#467a3c");
        assert_eq!(level_color(147), "#467a3c");
        assert_eq!(level_color(5), "#9b9b9b");
    }
}
