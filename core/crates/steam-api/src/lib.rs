//! A small blocking client for Steam's public, key-less web APIs.
//!
//! Only endpoints that work without a Web API key are used:
//!
//! | Data                    | Endpoint                                                      |
//! |-------------------------|---------------------------------------------------------------|
//! | Store shelves           | `store.steampowered.com/api/featuredcategories`               |
//! | Featured carousel       | `store.steampowered.com/api/featured`                         |
//! | App details             | `store.steampowered.com/api/appdetails`                       |
//! | Review summary          | `store.steampowered.com/appreviews/{appid}?json=1`            |
//! | Popular tags            | `store.steampowered.com/tagdata/populartags/english`          |
//! | News                    | `api.steampowered.com/ISteamNews/GetNewsForApp/v2`            |
//! | Live player counts      | `api.steampowered.com/ISteamUserStats/GetNumberOfCurrentPlayers/v1` |
//! | Most played chart       | `api.steampowered.com/ISteamChartsService/GetMostPlayedGames/v1` |
//!
//! Responses can be cached on disk so regenerating a snapshot doesn't hammer
//! the store API (which rate-limits around 200 requests / 5 minutes).

use serde::de::DeserializeOwned;
use serde::Deserialize;
use std::collections::HashMap;
use std::path::PathBuf;
use std::thread;
use std::time::{Duration, Instant, SystemTime};

pub mod text;

#[derive(Debug, thiserror::Error)]
pub enum Error {
    #[error("http: {0}")]
    Http(#[from] reqwest::Error),
    #[error("json from {url}: {source}")]
    Json {
        url: String,
        source: serde_json::Error,
    },
    #[error("io: {0}")]
    Io(#[from] std::io::Error),
    #[error("steam returned no data for {0}")]
    Missing(String),
}

pub type Result<T> = std::result::Result<T, Error>;

pub const STORE: &str = "https://store.steampowered.com";
pub const WEBAPI: &str = "https://api.steampowered.com";
pub const ASSETS: &str = "https://shared.akamai.steamstatic.com/store_item_assets/steam/apps";

pub struct SteamClient {
    http: reqwest::blocking::Client,
    cache_dir: Option<PathBuf>,
    cache_ttl: Duration,
    min_interval: Duration,
    last_request: std::cell::Cell<Option<Instant>>,
    pub country: String,
    pub language: String,
}

impl SteamClient {
    pub fn new(country: &str) -> Result<Self> {
        let http = reqwest::blocking::Client::builder()
            .user_agent("native-steam-snapshot/0.1 (+https://github.com/swsvindland/native-steam)")
            .timeout(Duration::from_secs(20))
            .build()?;
        Ok(Self {
            http,
            cache_dir: None,
            cache_ttl: Duration::from_secs(60 * 60 * 12),
            min_interval: Duration::from_millis(300),
            last_request: std::cell::Cell::new(None),
            country: country.to_string(),
            language: "english".to_string(),
        })
    }

    /// Cache raw responses under `dir` for `ttl`.
    pub fn with_cache(mut self, dir: impl Into<PathBuf>, ttl: Duration) -> Self {
        self.cache_dir = Some(dir.into());
        self.cache_ttl = ttl;
        self
    }

    // -- endpoints ----------------------------------------------------------

    pub fn featured_categories(&self) -> Result<RawFeaturedCategories> {
        self.get_json(&format!(
            "{STORE}/api/featuredcategories?cc={}&l={}",
            self.country, self.language
        ))
    }

    pub fn featured(&self) -> Result<RawFeatured> {
        self.get_json(&format!(
            "{STORE}/api/featured/?cc={}&l={}",
            self.country, self.language
        ))
    }

    /// Returns `None` when the app is region-locked, delisted or not a game.
    pub fn app_details(&self, app_id: u32) -> Result<Option<RawAppDetails>> {
        let url = format!(
            "{STORE}/api/appdetails?appids={app_id}&cc={}&l={}",
            self.country, self.language
        );
        let mut map: HashMap<String, RawAppDetailsEnvelope> = self.get_json(&url)?;
        Ok(map
            .remove(&app_id.to_string())
            .filter(|e| e.success)
            .and_then(|e| e.data))
    }

    /// App ids from the store's "Popular Upcoming" search, in rank order.
    pub fn popular_upcoming(&self, count: u32) -> Result<Vec<u32>> {
        let url = format!(
            "{STORE}/search/results/?filter=popularcomingsoon&json=1&count={count}&cc={}&l={}",
            self.country, self.language
        );
        let r: RawSearch = self.get_json(&url)?;
        Ok(r.items
            .iter()
            .filter_map(|i| app_id_from_asset_url(&i.logo))
            .collect())
    }

    pub fn review_summary(&self, app_id: u32) -> Result<RawReviewSummary> {
        let url = format!(
            "{STORE}/appreviews/{app_id}?json=1&num_per_page=0&language=all&purchase_type=all"
        );
        let r: RawReviews = self.get_json(&url)?;
        r.query_summary.ok_or_else(|| Error::Missing(url))
    }

    pub fn popular_tags(&self) -> Result<Vec<RawTag>> {
        self.get_json(&format!("{STORE}/tagdata/populartags/{}", self.language))
    }

    pub fn news(&self, app_id: u32, count: u32) -> Result<Vec<RawNewsItem>> {
        let url = format!(
            "{WEBAPI}/ISteamNews/GetNewsForApp/v2/?appid={app_id}&count={count}&maxlength=0&format=json"
        );
        let r: RawNewsEnvelope = self.get_json(&url)?;
        Ok(r.appnews.map(|a| a.newsitems).unwrap_or_default())
    }

    pub fn current_players(&self, app_id: u32) -> Result<u64> {
        let url = format!("{WEBAPI}/ISteamUserStats/GetNumberOfCurrentPlayers/v1/?appid={app_id}");
        let r: RawPlayersEnvelope = self.get_json(&url)?;
        Ok(r.response.player_count.unwrap_or(0))
    }

    pub fn most_played(&self) -> Result<Vec<RawChartRank>> {
        let r: RawChartEnvelope = self.get_json(&format!(
            "{WEBAPI}/ISteamChartsService/GetMostPlayedGames/v1/"
        ))?;
        Ok(r.response.ranks)
    }

    /// HEAD request used to check whether optional library artwork exists.
    pub fn asset_exists(&self, url: &str) -> bool {
        let key = format!("head-{url}");
        if let Some(cached) = self.read_cache(&key) {
            return cached == "1";
        }
        self.throttle();
        let ok = self
            .http
            .head(url)
            .send()
            .map(|r| r.status().is_success())
            .unwrap_or(false);
        self.write_cache(&key, if ok { "1" } else { "0" });
        ok
    }

    // -- plumbing -----------------------------------------------------------

    fn get_json<T: DeserializeOwned>(&self, url: &str) -> Result<T> {
        let body = match self.read_cache(url) {
            Some(body) => body,
            None => {
                let body = self.fetch_with_retry(url)?;
                self.write_cache(url, &body);
                body
            }
        };
        serde_json::from_str(&body).map_err(|source| Error::Json {
            url: url.to_string(),
            source,
        })
    }

    fn fetch_with_retry(&self, url: &str) -> Result<String> {
        let mut delay = Duration::from_secs(5);
        for attempt in 0..4 {
            self.throttle();
            let resp = self.http.get(url).send()?;
            let status = resp.status();
            if (status.as_u16() == 429 || status.is_server_error()) && attempt < 3 {
                eprintln!("  {status} from {url}; retrying in {delay:?}");
                thread::sleep(delay);
                delay *= 3;
                continue;
            }
            return Ok(resp.error_for_status()?.text()?);
        }
        unreachable!()
    }

    fn throttle(&self) {
        if let Some(last) = self.last_request.get() {
            let elapsed = last.elapsed();
            if elapsed < self.min_interval {
                thread::sleep(self.min_interval - elapsed);
            }
        }
        self.last_request.set(Some(Instant::now()));
    }

    fn cache_path(&self, key: &str) -> Option<PathBuf> {
        let dir = self.cache_dir.as_ref()?;
        let name: String = key
            .chars()
            .map(|c| if c.is_ascii_alphanumeric() { c } else { '_' })
            .collect();
        // Keep names short but unique enough for our handful of URLs.
        let name = if name.len() > 180 {
            format!("{}_{:x}", &name[..120], fxhash(key))
        } else {
            name
        };
        Some(dir.join(name))
    }

    fn read_cache(&self, key: &str) -> Option<String> {
        let path = self.cache_path(key)?;
        let meta = std::fs::metadata(&path).ok()?;
        let age = SystemTime::now()
            .duration_since(meta.modified().ok()?)
            .unwrap_or_default();
        if age > self.cache_ttl {
            return None;
        }
        std::fs::read_to_string(path).ok()
    }

    fn write_cache(&self, key: &str, body: &str) {
        if let Some(path) = self.cache_path(key) {
            let _ = std::fs::create_dir_all(path.parent().unwrap());
            let _ = std::fs::write(path, body);
        }
    }
}

fn fxhash(s: &str) -> u64 {
    s.bytes().fold(0xcbf29ce484222325u64, |h, b| {
        (h ^ b as u64).wrapping_mul(0x100000001b3)
    })
}

/// Extract the app id from a CDN asset URL like `.../steam/apps/4115450/...`.
pub fn app_id_from_asset_url(url: &str) -> Option<u32> {
    let rest = url.split("/apps/").nth(1)?;
    rest.split('/').next()?.parse().ok()
}

/// Conventional library artwork URLs for an app id.
pub fn library_asset(app_id: u32, file: &str) -> String {
    format!("{ASSETS}/{app_id}/{file}")
}

// ---------------------------------------------------------------------------
// Raw response types (only the fields we use)
// ---------------------------------------------------------------------------

#[derive(Deserialize, Debug, Clone)]
pub struct RawFeaturedItem {
    pub id: u32,
    /// 0 = app; other values are packages/bundles.
    #[serde(rename = "type", default)]
    pub kind: u32,
    pub name: String,
    #[serde(default)]
    pub discounted: bool,
    #[serde(default)]
    pub discount_percent: u32,
    pub original_price: Option<u32>,
    pub final_price: Option<u32>,
    pub currency: Option<String>,
    pub large_capsule_image: Option<String>,
    pub small_capsule_image: Option<String>,
    pub header_image: Option<String>,
    #[serde(default)]
    pub windows_available: bool,
    #[serde(default)]
    pub mac_available: bool,
    #[serde(default)]
    pub linux_available: bool,
    pub discount_expiration: Option<i64>,
    pub controller_support: Option<String>,
}

impl RawFeaturedItem {
    /// A shelf entry for an app we only know by id; details fill in the rest.
    pub fn bare(id: u32, name: &str) -> Self {
        Self {
            id,
            kind: 0,
            name: name.to_string(),
            discounted: false,
            discount_percent: 0,
            original_price: None,
            final_price: None,
            currency: None,
            large_capsule_image: None,
            small_capsule_image: None,
            header_image: None,
            windows_available: false,
            mac_available: false,
            linux_available: false,
            discount_expiration: None,
            controller_support: None,
        }
    }
}

#[derive(Deserialize, Debug)]
struct RawSearch {
    #[serde(default)]
    items: Vec<RawSearchItem>,
}

#[derive(Deserialize, Debug)]
struct RawSearchItem {
    #[serde(default)]
    logo: String,
}

#[derive(Deserialize, Debug, Default)]
pub struct RawShelf {
    #[serde(default)]
    pub items: Vec<RawFeaturedItem>,
}

#[derive(Deserialize, Debug)]
pub struct RawFeaturedCategories {
    #[serde(default)]
    pub specials: RawShelf,
    #[serde(default)]
    pub coming_soon: RawShelf,
    #[serde(default)]
    pub top_sellers: RawShelf,
    #[serde(default)]
    pub new_releases: RawShelf,
}

#[derive(Deserialize, Debug)]
pub struct RawFeatured {
    #[serde(default)]
    pub large_capsules: Vec<RawFeaturedItem>,
    #[serde(default)]
    pub featured_win: Vec<RawFeaturedItem>,
}

#[derive(Deserialize, Debug)]
struct RawAppDetailsEnvelope {
    success: bool,
    data: Option<RawAppDetails>,
}

#[derive(Deserialize, Debug, Clone)]
pub struct RawAppDetails {
    #[serde(rename = "type")]
    pub kind: String,
    pub name: String,
    pub steam_appid: u32,
    #[serde(default)]
    pub is_free: bool,
    pub controller_support: Option<String>,
    #[serde(default)]
    pub short_description: String,
    pub header_image: Option<String>,
    pub capsule_image: Option<String>,
    pub capsule_imagev5: Option<String>,
    #[serde(default)]
    pub developers: Vec<String>,
    pub price_overview: Option<RawPriceOverview>,
    pub platforms: Option<RawPlatforms>,
    pub metacritic: Option<RawMetacritic>,
    #[serde(default)]
    pub genres: Vec<RawGenre>,
    #[serde(default)]
    pub screenshots: Vec<RawScreenshot>,
    pub achievements: Option<RawAchievements>,
    pub release_date: Option<RawReleaseDate>,
    pub background_raw: Option<String>,
    pub content_descriptors: Option<RawContentDescriptors>,
}

impl RawAppDetails {
    /// True for apps flagged with nudity / sexual content descriptors.
    pub fn is_adult(&self) -> bool {
        self.content_descriptors
            .as_ref()
            .is_some_and(|c| c.ids.iter().any(|id| matches!(id, 1 | 3 | 4)))
    }
}

#[derive(Deserialize, Debug, Clone)]
pub struct RawContentDescriptors {
    #[serde(default)]
    pub ids: Vec<u32>,
}

#[derive(Deserialize, Debug, Clone)]
pub struct RawPriceOverview {
    pub currency: String,
    pub initial: u32,
    #[serde(rename = "final")]
    pub final_price: u32,
    pub discount_percent: u32,
    #[serde(default)]
    pub initial_formatted: String,
    #[serde(default)]
    pub final_formatted: String,
}

#[derive(Deserialize, Debug, Clone, Default)]
pub struct RawPlatforms {
    #[serde(default)]
    pub windows: bool,
    #[serde(default)]
    pub mac: bool,
    #[serde(default)]
    pub linux: bool,
}

#[derive(Deserialize, Debug, Clone)]
pub struct RawMetacritic {
    pub score: u32,
}

#[derive(Deserialize, Debug, Clone)]
pub struct RawGenre {
    pub description: String,
}

#[derive(Deserialize, Debug, Clone)]
pub struct RawScreenshot {
    pub path_thumbnail: String,
    pub path_full: String,
}

#[derive(Deserialize, Debug, Clone)]
pub struct RawAchievements {
    #[serde(default)]
    pub total: u32,
    #[serde(default)]
    pub highlighted: Vec<RawHighlightedAchievement>,
}

#[derive(Deserialize, Debug, Clone)]
pub struct RawHighlightedAchievement {
    pub name: String,
    pub path: String,
}

#[derive(Deserialize, Debug, Clone)]
pub struct RawReleaseDate {
    #[serde(default)]
    pub coming_soon: bool,
    #[serde(default)]
    pub date: String,
}

#[derive(Deserialize, Debug)]
struct RawReviews {
    query_summary: Option<RawReviewSummary>,
}

#[derive(Deserialize, Debug, Clone)]
pub struct RawReviewSummary {
    #[serde(default)]
    pub review_score: u32,
    #[serde(default)]
    pub review_score_desc: String,
    #[serde(default)]
    pub total_positive: u64,
    #[serde(default)]
    pub total_reviews: u64,
}

#[derive(Deserialize, Debug, Clone)]
pub struct RawTag {
    pub tagid: u32,
    pub name: String,
}

#[derive(Deserialize, Debug)]
struct RawNewsEnvelope {
    appnews: Option<RawAppNews>,
}

#[derive(Deserialize, Debug)]
struct RawAppNews {
    #[serde(default)]
    newsitems: Vec<RawNewsItem>,
}

#[derive(Deserialize, Debug, Clone)]
pub struct RawNewsItem {
    pub gid: String,
    pub title: String,
    pub url: String,
    pub author: Option<String>,
    #[serde(default)]
    pub contents: String,
    #[serde(default)]
    pub feedlabel: String,
    #[serde(default)]
    pub feedname: String,
    #[serde(default)]
    pub feed_type: u32,
    pub date: i64,
}

#[derive(Deserialize, Debug)]
struct RawPlayersEnvelope {
    response: RawPlayers,
}

#[derive(Deserialize, Debug)]
struct RawPlayers {
    player_count: Option<u64>,
}

#[derive(Deserialize, Debug)]
struct RawChartEnvelope {
    response: RawChart,
}

#[derive(Deserialize, Debug)]
struct RawChart {
    #[serde(default)]
    ranks: Vec<RawChartRank>,
}

#[derive(Deserialize, Debug, Clone)]
pub struct RawChartRank {
    pub rank: u32,
    pub appid: u32,
    #[serde(default)]
    pub peak_in_game: u64,
}
