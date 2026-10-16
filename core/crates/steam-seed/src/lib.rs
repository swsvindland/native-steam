//! Deterministic fake data for the parts of Steam that need an account:
//! the signed-in user's library stats, friends, friend activity and profile.
//!
//! Everything is built on top of *real* app data (names, artwork, achievement
//! icons, screenshots) passed in by the snapshot generator, and a fixed seed,
//! so the same day's snapshot always produces the same fake user.

use chrono::{DateTime, Datelike, Duration, Utc};
use steam_model::*;

pub mod labels;
use labels::*;

/// The persona shown as the fourth tab.
pub const PERSONA_NAME: &str = "Kestrel";

/// (app id, total hours, days since last played, installed, favorite,
/// hours in the past two weeks, size on disk in GB)
pub type LibraryEntry = (u32, f32, Option<u32>, bool, bool, f32, f32);

/// Curated library. Hand-tuned rather than random so screenshots tell a
/// believable story.
pub const LIBRARY: &[LibraryEntry] = &[
    (1145350, 38.4, Some(0), true, true, 6.1, 18.2), // Hades II
    (2379780, 96.2, Some(1), true, true, 4.3, 0.3),  // Balatro
    (1086940, 212.7, Some(3), true, true, 9.8, 128.4), // Baldur's Gate 3
    (1030300, 27.9, Some(5), true, false, 7.4, 6.8), // Hollow Knight: Silksong
    (548430, 164.0, Some(9), true, false, 2.2, 3.1), // Deep Rock Galactic
    (730, 412.9, Some(15), true, false, 0.0, 33.6),  // Counter-Strike 2
    (1145360, 142.3, Some(21), true, true, 0.0, 15.1), // Hades
    (553850, 77.3, Some(28), true, false, 0.0, 74.0), // HELLDIVERS 2
    (1245620, 181.5, Some(34), true, false, 0.0, 61.2), // ELDEN RING
    (526870, 3.2, Some(40), false, false, 0.0, 22.0), // Satisfactory
    (413150, 124.4, Some(45), true, false, 0.0, 0.6), // Stardew Valley
    (367520, 61.8, Some(60), false, true, 0.0, 8.9), // Hollow Knight
    (427520, 302.4, Some(70), true, false, 0.0, 4.5), // Factorio
    (646570, 188.6, Some(90), true, false, 0.0, 1.2), // Slay the Spire
    (1794680, 41.0, Some(120), false, false, 0.0, 0.8), // Vampire Survivors
    (1868140, 29.5, Some(140), false, false, 0.0, 9.6), // Dave the Diver
    (753640, 19.7, Some(150), false, true, 0.0, 6.4), // Outer Wilds
    (632360, 73.1, Some(160), true, false, 0.0, 6.2), // Risk of Rain 2
    (1091500, 96.8, Some(180), false, false, 0.0, 70.3), // Cyberpunk 2077
    (504230, 31.2, Some(200), false, true, 0.0, 1.2), // Celeste
    (1092790, 16.3, Some(220), false, false, 0.0, 3.4), // Inscryption
    (632470, 44.9, Some(250), false, false, 0.0, 22.4), // Disco Elysium
    (892970, 58.8, Some(260), false, false, 0.0, 1.4), // Valheim
    (546560, 14.6, Some(300), false, false, 0.0, 67.3), // Half-Life: Alyx
    (1174180, 88.0, Some(330), false, false, 0.0, 119.8), // Red Dead Redemption 2
    (105600, 210.3, Some(365), false, false, 0.0, 0.5), // Terraria
    (620, 22.1, Some(400), false, true, 0.0, 12.7),  // Portal 2
    (814380, 52.6, Some(500), false, false, 0.0, 14.8), // Sekiro
    (264710, 35.6, Some(600), false, false, 0.0, 9.1), // Subnautica
    (292030, 133.5, Some(700), false, false, 0.0, 48.6), // The Witcher 3
    (440, 618.2, Some(900), false, true, 0.0, 26.3), // Team Fortress 2
    (220, 18.4, Some(1200), false, false, 0.0, 6.5), // Half-Life 2
    (570, 8.2, Some(1500), false, false, 0.0, 41.0), // Dota 2
    (2358720, 0.0, None, true, false, 0.0, 129.7),   // Black Myth: Wukong (new)
    (1313140, 0.0, None, false, false, 0.0, 4.2),    // Cult of the Lamb (backlog)
];

/// Games that are 100% complete for the persona.
const PERFECT: &[u32] = &[1145360, 504230, 367520, 620, 2379780];

/// Real app data the seed decorates. Supplied by the snapshot generator.
#[derive(Clone, Debug)]
pub struct SeedGame {
    pub app_id: u32,
    pub name: String,
    pub images: Images,
    pub achievements_total: u32,
    /// (display name, icon url)
    pub highlighted: Vec<(String, String)>,
    pub controller_support: Option<String>,
    pub genres: Vec<String>,
    pub developers: Vec<String>,
    pub short_description: Option<String>,
    pub release_date: Option<String>,
    pub screenshots: Vec<Screenshot>,
}

/// SplitMix64 — tiny, dependency-free and stable across Rust versions.
#[derive(Clone)]
pub struct Rng(u64);

impl Rng {
    pub fn new(seed: u64) -> Self {
        Self(seed)
    }
    pub fn next_u64(&mut self) -> u64 {
        self.0 = self.0.wrapping_add(0x9E3779B97F4A7C15);
        let mut z = self.0;
        z = (z ^ (z >> 30)).wrapping_mul(0xBF58476D1CE4E5B9);
        z = (z ^ (z >> 27)).wrapping_mul(0x94D049BB133111EB);
        z ^ (z >> 31)
    }
    pub fn f32(&mut self) -> f32 {
        (self.next_u64() >> 40) as f32 / (1u64 << 24) as f32
    }
    pub fn range(&mut self, lo: u32, hi: u32) -> u32 {
        lo + (self.next_u64() % (hi - lo + 1) as u64) as u32
    }
    pub fn pick<'a, T>(&mut self, items: &'a [T]) -> &'a T {
        &items[(self.next_u64() % items.len() as u64) as usize]
    }
}

pub struct Seeded {
    pub library: Library,
    pub friends: Vec<Friend>,
    pub activity: Vec<ActivityItem>,
    pub user: UserProfile,
}

/// Build the fake account around the given real games.
///
/// `popular` are games outside the library that friends may be playing.
pub fn generate(now: DateTime<Utc>, games: &[SeedGame], popular: &[GameRef]) -> Seeded {
    let mut rng = Rng::new(0x5EED_57EA_u64);
    let friends = friends(&mut rng, now, games, popular);
    let library = library(&mut rng, now, games, &friends);
    let activity = activity(&mut rng, now, &library, &friends);
    let user = profile(&mut rng, now, &library, &friends);
    Seeded {
        library,
        friends,
        activity,
        user,
    }
}

// ---------------------------------------------------------------------------
// Library
// ---------------------------------------------------------------------------

fn library(rng: &mut Rng, now: DateTime<Utc>, games: &[SeedGame], friends: &[Friend]) -> Library {
    let mut out = Vec::new();
    for &(app_id, hours, days, installed, favorite, two_weeks, size_gb) in LIBRARY {
        let Some(g) = games.iter().find(|g| g.app_id == app_id) else {
            continue;
        };
        let minutes = (hours * 60.0).round() as u32;
        let two_weeks_minutes = (two_weeks * 60.0).round() as u32;
        let last_played = days
            .map(|d| now - Duration::days(d as i64) - Duration::minutes(rng.range(20, 600) as i64));
        let achievements = achievements(rng, g, hours, last_played.unwrap_or(now));
        let friends_playing: Vec<String> = friends
            .iter()
            .filter(|f| f.game.as_ref().is_some_and(|gr| gr.app_id == app_id) || rng.f32() < 0.18)
            .take(5)
            .map(|f| f.steam_id.clone())
            .collect();
        out.push(LibraryGame {
            app_id,
            name: g.name.clone(),
            images: g.images.clone(),
            playtime_minutes: minutes,
            playtime_label: if minutes == 0 {
                "Never played".into()
            } else {
                format!("{} on record", hours_label(minutes))
            },
            playtime_two_weeks_minutes: two_weeks_minutes,
            playtime_two_weeks_label: (two_weeks_minutes > 0)
                .then(|| format!("{} past 2 weeks", hours_label(two_weeks_minutes))),
            last_played: last_played.map(|t| t.to_rfc3339()),
            last_played_label: last_played
                .map(|t| day_label(now, t))
                .unwrap_or_else(|| "Never played".into()),
            installed,
            size_on_disk_bytes: (size_gb as f64 * 1_073_741_824.0) as u64,
            size_label: size_label(size_gb),
            favorite,
            update_available: installed && rng.f32() < 0.2,
            achievements,
            controller_support: g.controller_support.clone(),
            genres: g.genres.clone(),
            developers: g.developers.clone(),
            short_description: g.short_description.clone(),
            release_date: g.release_date.clone(),
            screenshots: g.screenshots.clone(),
            friends_playing,
        });
    }

    let mut recent: Vec<&LibraryGame> = out.iter().filter(|g| g.last_played.is_some()).collect();
    recent.sort_by(|a, b| b.last_played.cmp(&a.last_played));
    let recent_app_ids: Vec<u32> = recent.iter().take(8).map(|g| g.app_id).collect();

    out.sort_by_key(|g| sort_name(&g.name));

    let ids = |f: &dyn Fn(&LibraryGame) -> bool| -> Vec<u32> {
        out.iter().filter(|g| f(g)).map(|g| g.app_id).collect()
    };
    let has_genre = |g: &LibraryGame, name: &str| g.genres.iter().any(|x| x == name);
    let roguelikes = [1145350, 1145360, 2379780, 646570, 1794680, 632360, 1092790];
    let couch = [
        548430, 553850, 413150, 632360, 892970, 105600, 440, 730, 570,
    ];
    let collections = vec![
        Collection {
            id: "all".into(),
            name: "All Games".into(),
            kind: "dynamic".into(),
            app_ids: ids(&|_| true),
        },
        Collection {
            id: "favorites".into(),
            name: "Favorites".into(),
            kind: "dynamic".into(),
            app_ids: ids(&|g| g.favorite),
        },
        Collection {
            id: "installed".into(),
            name: "Installed".into(),
            kind: "dynamic".into(),
            app_ids: ids(&|g| g.installed),
        },
        Collection {
            id: "controller".into(),
            name: "Great on Controller".into(),
            kind: "dynamic".into(),
            app_ids: ids(&|g| g.controller_support.as_deref() == Some("full")),
        },
        Collection {
            id: "roguelikes".into(),
            name: "One More Run".into(),
            kind: "user".into(),
            app_ids: ids(&|g| roguelikes.contains(&g.app_id)),
        },
        Collection {
            id: "coop".into(),
            name: "Friday Night Co-op".into(),
            kind: "user".into(),
            app_ids: ids(&|g| couch.contains(&g.app_id)),
        },
        Collection {
            id: "rpg".into(),
            name: "Big RPGs".into(),
            kind: "user".into(),
            app_ids: ids(&|g| has_genre(g, "RPG") && g.playtime_minutes > 40 * 60),
        },
        Collection {
            id: "backlog".into(),
            name: "Backlog".into(),
            kind: "user".into(),
            app_ids: ids(&|g| g.playtime_minutes < 5 * 60),
        },
    ];

    Library {
        games: out,
        collections,
        recent_app_ids,
    }
}

fn achievements(
    rng: &mut Rng,
    g: &SeedGame,
    hours: f32,
    last: DateTime<Utc>,
) -> Option<AchievementProgress> {
    if g.achievements_total == 0 {
        return None;
    }
    let total = g.achievements_total;
    let unlocked = if PERFECT.contains(&g.app_id) {
        total
    } else if hours == 0.0 {
        0
    } else {
        let curve = 1.0 - (-hours / 70.0).exp();
        let jitter = 0.75 + rng.f32() * 0.3;
        ((0.08 + 0.85 * curve * jitter) * total as f32)
            .round()
            .min(total as f32 - 1.0) as u32
    };
    let fraction = unlocked as f32 / total as f32;
    let shown_unlocked = (g.highlighted.len() as f32 * fraction).round() as usize;
    let highlighted = g
        .highlighted
        .iter()
        .enumerate()
        .map(|(i, (name, icon))| {
            let unlocked = i < shown_unlocked;
            Achievement {
                name: name.clone(),
                icon_url: icon.clone(),
                unlocked,
                unlocked_label: unlocked.then(|| {
                    let when = last - Duration::days((i as i64) * rng.range(2, 19) as i64);
                    format!("Unlocked {}", short_date(when))
                }),
            }
        })
        .collect();
    Some(AchievementProgress {
        unlocked,
        total,
        fraction,
        highlighted,
    })
}

/// Sort like Steam: ignore leading "The ".
fn sort_name(name: &str) -> String {
    let lower = name.to_lowercase();
    lower.strip_prefix("the ").unwrap_or(&lower).to_string()
}

// ---------------------------------------------------------------------------
// Friends
// ---------------------------------------------------------------------------

/// (persona, level, status, minutes since last online for offline friends)
const FRIENDS: &[(&str, u32, &str, u32)] = &[
    ("mira.exe", 63, "inGame", 0),
    ("glitchwitch", 112, "inGame", 0),
    ("Tobias", 28, "inGame", 0),
    ("bread_knight", 9, "inGame", 0),
    ("Rook", 41, "online", 0),
    ("ctrl_alt_defeat", 77, "online", 0),
    ("Juniper", 35, "online", 0),
    ("sunny_d", 19, "away", 0),
    ("Okonkwo", 54, "offline", 190),
    ("pyrolysis", 88, "offline", 60 * 26),
    ("Hana", 22, "offline", 60 * 24 * 4),
    ("N0va", 140, "offline", 60 * 24 * 19),
];

fn friends(
    rng: &mut Rng,
    now: DateTime<Utc>,
    games: &[SeedGame],
    popular: &[GameRef],
) -> Vec<Friend> {
    // Avatars are achievement icons: square, colourful and real Steam assets.
    let icons: Vec<&String> = games
        .iter()
        .flat_map(|g| g.highlighted.iter().map(|(_, i)| i))
        .collect();
    let mut playing: Vec<GameRef> = games
        .iter()
        .filter(|g| [1145350, 1086940, 548430, 2379780].contains(&g.app_id))
        .map(|g| GameRef {
            app_id: g.app_id,
            name: g.name.clone(),
        })
        .collect();
    playing.extend(popular.iter().take(4).cloned());

    FRIENDS
        .iter()
        .enumerate()
        .map(|(i, &(name, level, status, minutes_ago))| {
            let avatar = icons
                .get((i * 7 + 3) % icons.len().max(1))
                .map(|s| s.to_string())
                .unwrap_or_default();
            let game = (status == "inGame").then(|| playing[(i * 3) % playing.len()].clone());
            let status_label = match status {
                "inGame" => game.as_ref().unwrap().name.clone(),
                "online" => "Online".into(),
                "away" => "Away".into(),
                _ => format!(
                    "Last online {}",
                    relative(now, now - Duration::minutes(minutes_ago as i64))
                ),
            };
            let _ = rng.next_u64();
            Friend {
                steam_id: format!("7656119800{:07}", 4_200_000 + i * 7_919),
                persona_name: name.into(),
                avatar_url: avatar,
                level,
                level_color: level_color(level).into(),
                status: status.into(),
                status_label,
                game,
            }
        })
        .collect()
}

// ---------------------------------------------------------------------------
// Friend activity
// ---------------------------------------------------------------------------

const REVIEWS: &[(bool, &str)] = &[
    (
        true,
        "Lost an entire weekend to this. Zero regrets — I'd lose another one.",
    ),
    (
        true,
        "The soundtrack alone is worth the price. Everything else is a bonus.",
    ),
    (
        true,
        "Controller support is flawless. Played the whole thing from the couch.",
    ),
    (
        true,
        "Gets better every hour. Push through the first act and it never lets go.",
    ),
    (
        true,
        "Bought it on sale, would have happily paid double. Instant classic.",
    ),
    (
        false,
        "Great ideas and gorgeous art, but the late game drags. Wait for a sale.",
    ),
    (
        true,
        "Co-op with friends is pure chaos in the best possible way. Rock and stone!",
    ),
];

fn activity(
    rng: &mut Rng,
    now: DateTime<Utc>,
    library: &Library,
    friends: &[Friend],
) -> Vec<ActivityItem> {
    let pool: Vec<&LibraryGame> = library
        .games
        .iter()
        .filter(|g| g.playtime_minutes > 0 && !g.screenshots.is_empty())
        .collect();
    let kinds = [
        "achievement",
        "screenshot",
        "achievement",
        "review",
        "nowPlaying",
        "achievement",
        "screenshot",
        "newGame",
        "achievement",
        "review",
    ];
    let mut minutes_ago = 6u32;
    let mut items = Vec::new();
    for i in 0..22 {
        let friend = &friends[(i * 5 + 1) % friends.len()];
        let kind = kinds[i % kinds.len()];
        let game = match (kind, &friend.game) {
            ("nowPlaying", Some(g)) => library
                .games
                .iter()
                .find(|lg| lg.app_id == g.app_id)
                .copied_or(pool[i % pool.len()]),
            _ => pool[(i * 7 + 2) % pool.len()],
        };
        let when = now - Duration::minutes(minutes_ago as i64);
        minutes_ago += rng.range(25, 260);

        let (headline, achievement, image_url, review) = match kind {
            "achievement" => {
                let a = game.achievements.as_ref().and_then(|a| {
                    let list = &a.highlighted;
                    (!list.is_empty())
                        .then(|| list[rng.range(0, list.len() as u32 - 1) as usize].clone())
                });
                match a {
                    Some(mut a) => {
                        a.unlocked = true;
                        a.unlocked_label = Some(format!("Unlocked {}", short_date(when)));
                        ("unlocked an achievement in", Some(a), None, None)
                    }
                    None => ("is now playing", None, None, None),
                }
            }
            "screenshot" => {
                let shot = rng.pick(&game.screenshots).full.clone();
                ("uploaded a screenshot of", None, Some(shot), None)
            }
            "review" => {
                let (recommended, body) = *rng.pick(REVIEWS);
                let hours = rng.range(8, 260) * 60 + rng.range(0, 59);
                (
                    if recommended {
                        "recommends"
                    } else {
                        "does not recommend"
                    },
                    None,
                    None,
                    Some(ActivityReview {
                        recommended,
                        body: body.into(),
                        hours_label: format!("{} on record", hours_label(hours)),
                    }),
                )
            }
            "newGame" => (
                "added to their library",
                None,
                game.images.header.clone().into(),
                None,
            ),
            _ => ("is now playing", None, None, None),
        };

        items.push(ActivityItem {
            id: format!("act-{i:03}"),
            kind: if headline == "is now playing" {
                "nowPlaying".into()
            } else {
                kind.into()
            },
            friend_id: friend.steam_id.clone(),
            friend_name: friend.persona_name.clone(),
            friend_avatar_url: friend.avatar_url.clone(),
            app_id: game.app_id,
            app_name: game.name.clone(),
            app_images: game.images.clone(),
            timestamp: when.to_rfc3339(),
            time_label: relative(now, when),
            headline: headline.into(),
            achievement,
            image_url,
            review,
            likes: rng.range(0, 48),
            comments: rng.range(0, 9),
        });
    }
    items
}

trait CopiedOr<'a, T> {
    fn copied_or(self, fallback: &'a T) -> &'a T;
}
impl<'a, T> CopiedOr<'a, T> for Option<&'a T> {
    fn copied_or(self, fallback: &'a T) -> &'a T {
        self.unwrap_or(fallback)
    }
}

// ---------------------------------------------------------------------------
// Profile
// ---------------------------------------------------------------------------

fn profile(
    rng: &mut Rng,
    now: DateTime<Utc>,
    library: &Library,
    friends: &[Friend],
) -> UserProfile {
    let game = |id: u32| library.games.iter().find(|g| g.app_id == id);
    let favorite = game(1145360)
        .or_else(|| library.games.first())
        .expect("library is empty");

    let level = 47u32;
    let xp_for = |lvl: u32| -> u32 { (1..=lvl).map(|i| 100 * i.div_ceil(10)).sum() };
    let xp = xp_for(level) + 188;
    let span = xp_for(level + 1) - xp_for(level);
    let into = xp - xp_for(level);

    let member_since = chrono::NaiveDate::from_ymd_opt(2013, 3, 14).unwrap();
    let years = now.year()
        - member_since.year()
        - if (now.month(), now.day()) < (member_since.month(), member_since.day()) {
            1
        } else {
            0
        };

    let total_minutes: u32 = library.games.iter().map(|g| g.playtime_minutes).sum();
    let unlocked: u32 = library
        .games
        .iter()
        .filter_map(|g| g.achievements.as_ref())
        .map(|a| a.unlocked)
        .sum();
    let perfect = library
        .games
        .iter()
        .filter_map(|g| g.achievements.as_ref())
        .filter(|a| a.total > 0 && a.unlocked == a.total)
        .count() as u32;

    let recent_games = library
        .recent_app_ids
        .iter()
        .filter_map(|&id| game(id))
        .take(3)
        .map(|g| RecentGame {
            app_id: g.app_id,
            name: g.name.clone(),
            images: g.images.clone(),
            two_weeks_label: g
                .playtime_two_weeks_label
                .clone()
                .unwrap_or_else(|| "0 hrs past 2 weeks".into()),
            total_label: g.playtime_label.clone(),
            last_played_label: format!("Last played {}", g.last_played_label.to_lowercase_first()),
            achievements: g.achievements.clone(),
        })
        .collect();

    let rare_achievements = PERFECT
        .iter()
        .chain([1086940u32, 1245620].iter())
        .filter_map(|&id| game(id))
        .filter_map(|g| {
            let a = g
                .achievements
                .as_ref()?
                .highlighted
                .iter()
                .rfind(|a| a.unlocked)?;
            Some(ShowcaseAchievement {
                app_id: g.app_id,
                app_name: g.name.clone(),
                achievement: a.clone(),
            })
        })
        .take(6)
        .collect();

    let screenshots = [1145350u32, 1086940, 1030300, 1245620]
        .iter()
        .filter_map(|&id| game(id))
        .filter_map(|g| {
            let s = g
                .screenshots
                .get(rng.range(0, g.screenshots.len().saturating_sub(1) as u32) as usize)?;
            Some(ShowcaseScreenshot {
                app_id: g.app_id,
                app_name: g.name.clone(),
                url: s.full.clone(),
            })
        })
        .collect();

    let avatar = game(1145350)
        .or(Some(favorite))
        .and_then(|g| g.achievements.as_ref())
        .and_then(|a| a.highlighted.first())
        .map(|a| a.icon_url.clone())
        .unwrap_or_default();

    let badges = vec![
        Badge {
            name: "Years of Service".into(),
            description: format!("Member for {years} years"),
            level: years as u32,
            xp: years as u32 * 50,
            color: "#c7a64b".into(),
            icon: "years".into(),
        },
        Badge {
            name: "Game Collector".into(),
            description: format!("Owns {} games", library.games.len()),
            level: 3,
            xp: 250,
            color: "#4e8ddb".into(),
            icon: "collector".into(),
        },
        Badge {
            name: "Summer Sale 2026".into(),
            description: "Level 5 · Collected all trading cards".into(),
            level: 5,
            xp: 500,
            color: "#e2873b".into(),
            icon: "sale".into(),
        },
        Badge {
            name: "Community Leader".into(),
            description: "Completed every community task".into(),
            level: 1,
            xp: 100,
            color: "#66c0f4".into(),
            icon: "community".into(),
        },
        Badge {
            name: "Steam Awards Nominator".into(),
            description: "Nominated in every category".into(),
            level: 6,
            xp: 300,
            color: "#9b5de5".into(),
            icon: "awards".into(),
        },
        Badge {
            name: "Completionist".into(),
            description: format!("{perfect} perfect games"),
            level: perfect,
            xp: perfect * 100,
            color: "#90ba3c".into(),
            icon: "trophy".into(),
        },
    ];

    UserProfile {
        steam_id: "76561198000420042".into(),
        persona_name: PERSONA_NAME.into(),
        real_name: "Kes".into(),
        avatar_url: avatar,
        background_url: favorite.images.hero.clone().unwrap_or_else(|| favorite.images.header.clone()),
        country: "United States".into(),
        level,
        level_color: level_color(level).into(),
        xp,
        xp_to_next_label: format!("{} XP to level {}", steam_model::group_thousands((span - into) as u64), level + 1),
        xp_fraction: into as f32 / span as f32,
        status: "online".into(),
        summary: "Roguelikes, 200-hour RPGs and the occasional cozy farm. Controller > keyboard — fight me. Always down for Deep Rock on Fridays.".into(),
        member_since_label: format!("Member since {}", member_since.format("%B %-d, %Y")),
        years_label: format!("Years of Service: {years}"),
        stats: ProfileStats {
            games_owned: library.games.len() as u32,
            achievements: unlocked,
            perfect_games: perfect,
            friends: friends.len() as u32,
            screenshots: 1284,
            reviews: 23,
            badges: 38,
            hours_label: format!("{} hrs", steam_model::group_thousands((total_minutes / 60) as u64)),
        },
        badges,
        favorite_game: GameRef { app_id: favorite.app_id, name: favorite.name.clone() },
        recent_games,
        rare_achievements,
        screenshots,
    }
}

trait LowerFirst {
    fn to_lowercase_first(&self) -> String;
}
impl LowerFirst for String {
    fn to_lowercase_first(&self) -> String {
        // "Today" -> "today", but keep month names ("Oct 3") capitalised.
        match self.as_str() {
            "Today" | "Yesterday" => self.to_lowercase(),
            _ => format!("on {self}"),
        }
    }
}
