//! `steam-snapshot` — builds `data/snapshot.json`, the single data file every
//! Native Steam client renders.
//!
//! Store, charts, news and app artwork come live from Steam's public APIs;
//! the signed-in user (library stats, friends, activity, profile) is seeded
//! deterministically by `steam-seed` on top of that real data.

use anyhow::{Context, Result};
use chrono::{DateTime, Utc};
use clap::Parser;
use std::collections::{BTreeMap, HashMap, HashSet};
use std::path::PathBuf;
use std::time::Duration;
use steam_api::{
    library_asset, text, RawAppDetails, RawFeaturedItem, RawReviewSummary, SteamClient,
};
use steam_model::*;
use steam_seed::SeedGame;

#[derive(Parser)]
#[command(about = "Generate data/snapshot.json from Steam's public APIs")]
struct Args {
    /// Output path.
    #[arg(long, default_value = "../data/snapshot.json")]
    out: PathBuf,
    /// Directory for cached API responses.
    #[arg(long, default_value = ".cache")]
    cache: PathBuf,
    /// Cache lifetime in hours (0 disables caching).
    #[arg(long, default_value_t = 12)]
    cache_hours: u64,
    /// Store country code for prices.
    #[arg(long, default_value = "us")]
    country: String,
}

fn main() -> Result<()> {
    let args = Args::parse();
    let now = Utc::now();
    let mut client = SteamClient::new(&args.country)?;
    if args.cache_hours > 0 {
        client = client.with_cache(&args.cache, Duration::from_secs(args.cache_hours * 3600));
    }

    eprintln!("» store shelves");
    let cats = client.featured_categories().context("featuredcategories")?;
    let featured = client.featured().context("featured")?;
    let charts = client.most_played().context("most played")?;
    // featuredcategories' "coming soon" is mostly demos; the popular-upcoming
    // search is what the store front actually shows.
    let upcoming: Vec<RawFeaturedItem> = client
        .popular_upcoming(20)
        .context("popular upcoming")?
        .into_iter()
        .map(|id| RawFeaturedItem::bare(id, ""))
        .collect();
    let tags = client.popular_tags().context("popular tags")?;

    let apps_only = |items: Vec<RawFeaturedItem>, n: usize| -> Vec<RawFeaturedItem> {
        let mut seen = HashSet::new();
        items
            .into_iter()
            .filter(|i| i.kind == 0 && seen.insert(i.id))
            .take(n)
            .collect()
    };
    let mut featured_raw = featured.large_capsules;
    featured_raw.extend(featured.featured_win);
    let shelves = [
        ("featured", apps_only(featured_raw, 10)),
        ("specials", apps_only(cats.specials.items, 12)),
        ("top_sellers", apps_only(cats.top_sellers.items, 12)),
        ("new_releases", apps_only(cats.new_releases.items, 15)),
        (
            "coming_soon",
            apps_only(
                if upcoming.is_empty() {
                    cats.coming_soon.items
                } else {
                    upcoming
                },
                12,
            ),
        ),
    ];
    let chart_ranks: Vec<_> = charts.into_iter().take(12).collect();

    // -- app details for everything we show ---------------------------------
    let mut ids: Vec<u32> = Vec::new();
    ids.extend(steam_seed::LIBRARY.iter().map(|g| g.0));
    for (_, items) in &shelves {
        ids.extend(items.iter().map(|i| i.id));
    }
    ids.extend(chart_ranks.iter().map(|r| r.appid));
    let mut seen = HashSet::new();
    ids.retain(|id| seen.insert(*id));

    eprintln!("» app details for {} apps", ids.len());
    let mut details: HashMap<u32, RawAppDetails> = HashMap::new();
    for (n, id) in ids.iter().enumerate() {
        match client.app_details(*id) {
            Ok(Some(d)) => {
                details.insert(*id, d);
            }
            Ok(None) => eprintln!("  {id}: no store data (skipped)"),
            Err(e) => eprintln!("  {id}: {e}"),
        }
        if (n + 1) % 20 == 0 {
            eprintln!("  {}/{}", n + 1, ids.len());
        }
    }

    let library_ids: HashSet<u32> = steam_seed::LIBRARY.iter().map(|g| g.0).collect();
    let mut images_cache: HashMap<u32, Images> = HashMap::new();
    let mut images_for = |client: &SteamClient, id: u32, raw: Option<&RawFeaturedItem>| -> Images {
        images_cache
            .entry(id)
            .or_insert_with(|| build_images(client, id, raw, details.get(&id)))
            .clone()
    };

    // -- store ---------------------------------------------------------------
    eprintln!("» reviews + artwork for store items");
    let mut reviews: HashMap<u32, Option<ReviewSummary>> = HashMap::new();
    let mut store_lists: BTreeMap<&str, Vec<StoreItem>> = BTreeMap::new();
    for (name, items) in &shelves {
        let mut list = Vec::new();
        for raw in items {
            let Some(d) = details.get(&raw.id) else {
                continue;
            };
            if d.kind != "game" || d.is_adult() {
                continue;
            }
            let review = reviews
                .entry(raw.id)
                .or_insert_with(|| client.review_summary(raw.id).ok().and_then(review_summary))
                .clone();
            let images = images_for(&client, raw.id, Some(raw));
            list.push(store_item(raw, d, images, review));
        }
        store_lists.insert(name, list);
    }

    eprintln!("» live player counts");
    let mut most_played = Vec::new();
    for r in &chart_ranks {
        let Some(d) = details.get(&r.appid) else {
            continue;
        };
        let players = client.current_players(r.appid).unwrap_or(0);
        if players == 0 || d.is_adult() {
            continue;
        }
        most_played.push(ChartEntry {
            // Re-rank after filtering so the list reads 1, 2, 3…
            rank: most_played.len() as u32 + 1,
            app_id: r.appid,
            name: d.name.clone(),
            images: images_for(&client, r.appid, None),
            current_players: players,
            current_players_label: format!("{} playing", compact_count(players)),
            peak_today: r.peak_in_game,
            peak_today_label: format!("Peak {} today", compact_count(r.peak_in_game)),
            price: price_from_details(d),
        });
    }

    let store = Store {
        featured: store_lists.remove("featured").unwrap_or_default(),
        specials: store_lists.remove("specials").unwrap_or_default(),
        top_sellers: store_lists.remove("top_sellers").unwrap_or_default(),
        new_releases: store_lists.remove("new_releases").unwrap_or_default(),
        coming_soon: store_lists.remove("coming_soon").unwrap_or_default(),
        most_played: most_played.clone(),
        popular_tags: tags
            .into_iter()
            .take(16)
            .map(|t| Tag {
                id: t.tagid,
                name: t.name,
            })
            .collect(),
    };

    // -- seeded account ------------------------------------------------------
    eprintln!("» library artwork");
    let seed_games: Vec<SeedGame> = steam_seed::LIBRARY
        .iter()
        .filter_map(|&(id, ..)| {
            let d = details.get(&id)?;
            let achievements = d.achievements.as_ref();
            Some(SeedGame {
                app_id: id,
                name: d.name.clone(),
                images: images_for(&client, id, None),
                achievements_total: achievements.map_or(0, |a| a.total),
                highlighted: achievements
                    .map(|a| {
                        a.highlighted
                            .iter()
                            .map(|h| (h.name.clone(), h.path.clone()))
                            .collect()
                    })
                    .unwrap_or_default(),
                controller_support: d.controller_support.clone(),
                genres: d.genres.iter().map(|g| g.description.clone()).collect(),
                developers: d.developers.clone(),
                short_description: non_empty(&d.short_description),
                release_date: d
                    .release_date
                    .as_ref()
                    .map(|r| r.date.clone())
                    .filter(|s| !s.is_empty()),
                screenshots: screenshots(d, 8),
            })
        })
        .collect();
    let popular: Vec<GameRef> = most_played
        .iter()
        .filter(|c| !library_ids.contains(&c.app_id))
        .map(|c| GameRef {
            app_id: c.app_id,
            name: c.name.clone(),
        })
        .collect();
    let seeded = steam_seed::generate(now, &seed_games, &popular);

    // -- community -----------------------------------------------------------
    eprintln!("» news");
    let news_sources: Vec<&LibraryGame> = {
        let mut v: Vec<&LibraryGame> = seeded
            .library
            .recent_app_ids
            .iter()
            .filter_map(|id| seeded.library.games.iter().find(|g| g.app_id == *id))
            .collect();
        v.extend(seeded.library.games.iter().filter(|g| g.favorite));
        let mut seen = HashSet::new();
        v.retain(|g| seen.insert(g.app_id));
        v.into_iter().take(10).collect()
    };
    let mut news = Vec::new();
    for g in news_sources {
        let items = client.news(g.app_id, 12).unwrap_or_default();
        let official = items.into_iter().filter(|n| {
            n.feedname == "steam_community_announcements" && !n.title.trim().is_empty()
        });
        for n in official.take(2) {
            let date = DateTime::<Utc>::from_timestamp(n.date, 0).unwrap_or(now);
            news.push(NewsItem {
                id: n.gid.clone(),
                app_id: g.app_id,
                app_name: g.name.clone(),
                app_images: g.images.clone(),
                title: n.title.trim().to_string(),
                author: n.author.filter(|a| !a.trim().is_empty()),
                url: n.url,
                date: date.to_rfc3339(),
                date_label: steam_seed::labels::day_label(now, date),
                excerpt: text::excerpt(&n.contents, 280),
                image_url: text::first_image(&n.contents),
                feed_label: if n.feedlabel.is_empty() {
                    "News".into()
                } else {
                    n.feedlabel
                },
            });
        }
    }
    news.sort_by(|a, b| b.date.cmp(&a.date));
    news.truncate(16);

    let mut by_players = most_played.clone();
    by_players.sort_by_key(|c| std::cmp::Reverse(c.current_players));
    let hubs = by_players
        .iter()
        .take(8)
        .zip(1u32..)
        .map(|(c, rank)| Hub {
            app_id: c.app_id,
            name: c.name.clone(),
            images: c.images.clone(),
            current_players: c.current_players,
            current_players_label: format!("{} in-game", compact_count(c.current_players)),
            rank,
        })
        .collect();

    let snapshot = Snapshot {
        schema_version: SCHEMA_VERSION,
        generated_at: now.to_rfc3339_opts(chrono::SecondsFormat::Secs, true),
        region: args.country.clone(),
        user: seeded.user,
        store,
        library: seeded.library,
        community: Community {
            activity: seeded.activity,
            news,
            hubs,
        },
        friends: seeded.friends,
    };

    if let Some(dir) = args.out.parent() {
        std::fs::create_dir_all(dir)?;
    }
    let json = serde_json::to_string_pretty(&snapshot)?;
    std::fs::write(&args.out, json + "\n")?;
    eprintln!(
        "✓ wrote {} — {} featured, {} specials, {} library games, {} news, {} activity",
        args.out.display(),
        snapshot.store.featured.len(),
        snapshot.store.specials.len(),
        snapshot.library.games.len(),
        snapshot.community.news.len(),
        snapshot.community.activity.len(),
    );
    Ok(())
}

fn non_empty(s: &str) -> Option<String> {
    let s = s.trim();
    (!s.is_empty()).then(|| s.replace("&quot;", "\"").replace("&amp;", "&"))
}

fn screenshots(d: &RawAppDetails, n: usize) -> Vec<Screenshot> {
    d.screenshots
        .iter()
        .take(n)
        .map(|s| Screenshot {
            thumbnail: s.path_thumbnail.clone(),
            full: s.path_full.clone(),
        })
        .collect()
}

fn build_images(
    client: &SteamClient,
    id: u32,
    raw: Option<&RawFeaturedItem>,
    d: Option<&RawAppDetails>,
) -> Images {
    let optional = |file: &str| {
        let url = library_asset(id, file);
        client.asset_exists(&url).then_some(url)
    };
    let header = raw
        .and_then(|r| r.header_image.clone())
        .or_else(|| d.and_then(|d| d.header_image.clone()))
        .unwrap_or_else(|| library_asset(id, "header.jpg"));
    let capsule = raw
        .and_then(|r| r.large_capsule_image.clone())
        .or_else(|| optional("capsule_616x353.jpg"))
        .unwrap_or_else(|| header.clone());
    let small_capsule = d
        .and_then(|d| d.capsule_image.clone())
        .or_else(|| raw.and_then(|r| r.small_capsule_image.clone()))
        .unwrap_or_else(|| header.clone());
    Images {
        header,
        capsule,
        small_capsule,
        portrait: optional("library_600x900.jpg"),
        hero: optional("library_hero.jpg"),
        logo: optional("logo.png"),
        background: d.and_then(|d| d.background_raw.clone()),
    }
}

fn store_item(
    raw: &RawFeaturedItem,
    d: &RawAppDetails,
    images: Images,
    review: Option<ReviewSummary>,
) -> StoreItem {
    let coming_soon = d.release_date.as_ref().is_some_and(|r| r.coming_soon);
    let price = if d.is_free {
        Some(free_price())
    } else if let (Some(initial), Some(final_price)) = (raw.original_price, raw.final_price) {
        // Prefer the shelf's price: it reflects the deal being promoted.
        let currency = raw.currency.clone().unwrap_or_else(|| "USD".into());
        let initial = initial.max(final_price);
        (final_price > 0).then(|| make_price(&currency, initial, final_price, raw.discount_percent))
    } else {
        price_from_details(d)
    };
    let price = if coming_soon
        && price
            .as_ref()
            .is_some_and(|p| p.final_price == 0 && !p.is_free)
    {
        None
    } else {
        price
    };
    StoreItem {
        app_id: raw.id,
        name: d.name.clone(),
        images,
        price,
        platforms: Platforms {
            windows: raw.windows_available || d.platforms.as_ref().is_some_and(|p| p.windows),
            mac: raw.mac_available || d.platforms.as_ref().is_some_and(|p| p.mac),
            linux: raw.linux_available || d.platforms.as_ref().is_some_and(|p| p.linux),
        },
        controller_support: raw
            .controller_support
            .clone()
            .or_else(|| d.controller_support.clone()),
        short_description: non_empty(&d.short_description),
        genres: d.genres.iter().map(|g| g.description.clone()).collect(),
        developers: d.developers.clone(),
        release_date: d
            .release_date
            .as_ref()
            .map(|r| r.date.clone())
            .filter(|s| !s.is_empty()),
        coming_soon,
        review,
        screenshots: screenshots(d, 6),
        metacritic: d.metacritic.as_ref().map(|m| m.score),
        discount_ends_label: raw
            .discount_expiration
            .filter(|_| raw.discounted)
            .and_then(|ts| DateTime::<Utc>::from_timestamp(ts, 0))
            .map(|t| format!("Offer ends {}", t.format("%b %-d"))),
    }
}

fn price_from_details(d: &RawAppDetails) -> Option<Price> {
    if d.is_free {
        return Some(free_price());
    }
    let p = d.price_overview.as_ref()?;
    Some(make_price(
        &p.currency,
        p.initial,
        p.final_price,
        p.discount_percent,
    ))
}

fn free_price() -> Price {
    Price {
        currency: "USD".into(),
        initial: 0,
        final_price: 0,
        discount_percent: 0,
        initial_label: "Free".into(),
        final_label: "Free to Play".into(),
        discount_label: None,
        is_free: true,
    }
}

fn make_price(currency: &str, initial: u32, final_price: u32, discount: u32) -> Price {
    Price {
        currency: currency.to_string(),
        initial,
        final_price,
        discount_percent: discount,
        initial_label: money(currency, initial),
        final_label: money(currency, final_price),
        discount_label: (discount > 0).then(|| format!("-{discount}%")),
        is_free: false,
    }
}

fn money(currency: &str, cents: u32) -> String {
    let amount = format!(
        "{}.{:02}",
        group_thousands((cents / 100) as u64),
        cents % 100
    );
    match currency {
        "USD" => format!("${amount}"),
        "GBP" => format!("£{amount}"),
        "EUR" => format!("{}€", amount.replace('.', ",")),
        other => format!("{amount} {other}"),
    }
}

fn review_summary(r: RawReviewSummary) -> Option<ReviewSummary> {
    // Steam shows "N user reviews" with no score below 10 reviews.
    if r.total_reviews < 10 || r.review_score_desc.is_empty() {
        return None;
    }
    let tone = match r.review_score {
        6.. => "positive",
        5 => "mixed",
        _ => "negative",
    };
    Some(ReviewSummary {
        label: r.review_score_desc,
        percent_positive: ((r.total_positive as f64 / r.total_reviews as f64) * 100.0).round()
            as u32,
        total: r.total_reviews,
        total_label: format!("{} reviews", group_thousands(r.total_reviews)),
        tone: tone.into(),
    })
}
