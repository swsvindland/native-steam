//! STORE tab (DESIGN.md §4.1) and the store app page.

use crate::art::Art;
use crate::responsive::{self, Width};
use crate::shell::{self, Tab};
use crate::{snapshot, ui};
use adw::prelude::*;
use gtk::glib;
use std::cell::{Cell, RefCell};
use std::collections::HashMap;
use std::rc::Rc;
use std::time::Duration;
use steam_model::{ChartEntry, Platforms, StoreItem};

const HEADER: f64 = 460.0 / 215.0;
const CAPSULE: f64 = 616.0 / 353.0;
const SMALL_CAPSULE: f64 = 231.0 / 87.0;
const SCREENSHOT: f64 = 16.0 / 9.0;

// ---------------------------------------------------------------------------
// Data lookup
// ---------------------------------------------------------------------------

thread_local! {
    static SYNTHESIZED: RefCell<HashMap<u32, &'static StoreItem>> = RefCell::new(HashMap::new());
}

/// Finds the store entry for `app_id`. Apps that only appear in charts, hubs or
/// the library get a minimal entry assembled from what we know.
pub fn find_item(app_id: u32) -> Option<&'static StoreItem> {
    let s = &snapshot().store;
    if let Some(i) = s
        .featured
        .iter()
        .chain(&s.specials)
        .chain(&s.top_sellers)
        .chain(&s.new_releases)
        .chain(&s.coming_soon)
        .find(|i| i.app_id == app_id)
    {
        return Some(i);
    }
    if let Some(i) = SYNTHESIZED.with(|m| m.borrow().get(&app_id).copied()) {
        return Some(i);
    }
    let snap = snapshot();
    let chart = s.most_played.iter().find(|c| c.app_id == app_id);
    let hub = snap.community.hubs.iter().find(|h| h.app_id == app_id);
    let lib = snap.library_game(app_id);
    let (name, images) = chart
        .map(|c| (c.name.clone(), c.images.clone()))
        .or_else(|| hub.map(|h| (h.name.clone(), h.images.clone())))
        .or_else(|| lib.map(|g| (g.name.clone(), g.images.clone())))?;
    let item = StoreItem {
        app_id,
        name,
        images,
        price: chart.and_then(|c| c.price.clone()),
        platforms: Platforms {
            windows: true,
            mac: false,
            linux: false,
        },
        controller_support: lib.and_then(|g| g.controller_support.clone()),
        short_description: lib.and_then(|g| g.short_description.clone()),
        genres: lib.map(|g| g.genres.clone()).unwrap_or_default(),
        developers: lib.map(|g| g.developers.clone()).unwrap_or_default(),
        release_date: lib.and_then(|g| g.release_date.clone()),
        coming_soon: false,
        review: None,
        screenshots: lib.map(|g| g.screenshots.clone()).unwrap_or_default(),
        metacritic: None,
        discount_ends_label: None,
    };
    let leaked: &'static StoreItem = Box::leak(Box::new(item));
    SYNTHESIZED.with(|m| m.borrow_mut().insert(app_id, leaked));
    Some(leaked)
}

fn open(app_id: u32) -> impl Fn() + 'static {
    move || shell::open_store_app(app_id)
}

// ---------------------------------------------------------------------------
// Root page
// ---------------------------------------------------------------------------

pub fn root() -> adw::NavigationPage {
    let s = &snapshot().store;
    let content = ui::vbox(0);
    content.add_css_class("page-content");

    content.append(&search_row());

    content.append(&ui::section("Featured & Recommended", None));
    let featured = adw::Clamp::builder()
        .unit(adw::LengthUnit::Px)
        .maximum_size(1100)
        .tightening_threshold(1100)
        .child(&featured_regular())
        .build();
    responsive::visible_when(&featured, |w| !w.is_compact());
    content.append(&featured);
    let featured_c = featured_compact();
    responsive::visible_when(&featured_c, Width::is_compact);
    content.append(&featured_c);

    content.append(&ui::section("Special Offers", Some("Browse more")));
    content.append(&ui::shelf(s.specials.iter().map(|i| {
        store_card(
            i,
            i.discount_ends_label
                .as_deref()
                .unwrap_or("Limited time offer"),
        )
    })));

    content.append(&ui::section("Top Sellers", Some("See all")));
    let rows: Vec<gtk::Widget> = s.top_sellers.iter().map(|i| list_row(i).upcast()).collect();
    let grid = ui::columns(rows, |w| if w >= Width::Large { 2 } else { 1 });
    responsive::gutter(&grid);
    responsive::visible_when(&grid, |w| !w.is_compact());
    content.append(&grid);
    let top_shelf = ui::shelf(s.top_sellers.iter().map(|i| store_card(i, &genres(i))));
    responsive::visible_when(&top_shelf, Width::is_compact);
    content.append(&top_shelf);

    content.append(&ui::section("New & Trending", Some("See all")));
    content.append(&ui::shelf(s.new_releases.iter().map(|i| {
        let meta = i
            .review
            .as_ref()
            .map(|r| r.label.clone())
            .unwrap_or_else(|| genres(i));
        store_card(i, &meta)
    })));

    content.append(&ui::section("Most Played", Some("Charts")));
    let chart: Vec<gtk::Widget> = s
        .most_played
        .iter()
        .map(|e| chart_row(e).upcast())
        .collect();
    let chart = ui::columns(chart, |w| if w >= Width::Large { 2 } else { 1 });
    responsive::gutter(&chart);
    content.append(&chart);

    content.append(&ui::section("Popular Upcoming", Some("See all")));
    content.append(&ui::shelf(s.coming_soon.iter().map(|i| {
        store_card(i, i.release_date.as_deref().unwrap_or("Coming soon"))
    })));

    // Shelves bleed to the window edge; very wide windows centre at ~1600.
    let clamp = adw::Clamp::builder()
        .unit(adw::LengthUnit::Px)
        .maximum_size(1600)
        .tightening_threshold(1600)
        .child(&content)
        .build();
    let page = adw::NavigationPage::builder()
        .title("Store")
        .tag("root")
        .child(&ui::page_scroller(&clamp))
        .build();
    page.add_css_class("bg-store");
    page
}

fn genres(i: &StoreItem) -> String {
    i.genres
        .iter()
        .take(3)
        .cloned()
        .collect::<Vec<_>>()
        .join(", ")
}

fn search_row() -> gtk::Box {
    let row = ui::hbox(16);
    row.add_css_class("search-row");
    responsive::gutter(&row);

    let entry = gtk::SearchEntry::new();
    entry.set_placeholder_text(Some("Search the store"));
    entry.add_css_class("steam-search");
    entry.set_valign(gtk::Align::Center);
    shell::register_search(Tab::Store, &entry);
    entry.connect_activate(|e| {
        let q = e.text();
        if !q.is_empty() {
            shell::get().toast(&format!("Searching the store for “{q}”"));
        }
    });
    responsive::watch(&entry, |e, w| {
        e.set_width_request(if w.is_compact() { -1 } else { 300 })
    });
    row.append(&entry);

    let chips = ui::hbox(8);
    chips.add_css_class("chip-row");
    for tag in &snapshot().store.popular_tags {
        let c = ui::chip(&tag.name);
        let name = tag.name.clone();
        c.connect_clicked(move |_| shell::get().toast(&format!("Browsing {name}")));
        chips.append(&c);
    }
    let sw = gtk::ScrolledWindow::new();
    sw.set_vscrollbar_policy(gtk::PolicyType::Never);
    sw.set_child(Some(&ui::viewport(&chips)));
    sw.set_hexpand(true);
    sw.add_css_class("chip-scroller");
    row.append(&sw);

    responsive::stack_on_compact(&row);
    row
}

// ---------------------------------------------------------------------------
// Featured & recommended carousel
// ---------------------------------------------------------------------------

/// Auto-advances `carousel` every 6 s unless it's hovered or holds focus.
fn auto_advance(carousel: &adw::Carousel, hover_area: &impl IsA<gtk::Widget>) {
    let hovered = Rc::new(Cell::new(false));
    let motion = gtk::EventControllerMotion::new();
    {
        let h = hovered.clone();
        motion.connect_enter(move |_, _, _| h.set(true));
    }
    {
        let h = hovered.clone();
        motion.connect_leave(move |_| h.set(false));
    }
    hover_area.add_controller(motion);
    let focus = gtk::EventControllerFocus::new();
    carousel.add_controller(focus.clone());

    let weak = carousel.downgrade();
    glib::timeout_add_local(Duration::from_secs(6), move || {
        let Some(c) = weak.upgrade() else {
            return glib::ControlFlow::Break;
        };
        if c.is_mapped() && !hovered.get() && !focus.contains_focus() {
            step(&c, 1);
        }
        glib::ControlFlow::Continue
    });
}

fn step(c: &adw::Carousel, delta: i32) {
    let n = c.n_pages() as i32;
    if n == 0 {
        return;
    }
    let i = (c.position().round() as i32 + delta).rem_euclid(n);
    c.scroll_to(&c.nth_page(i as u32), true);
}

fn arrow(icon: &str, carousel: &adw::Carousel, delta: i32) -> gtk::Button {
    let b = gtk::Button::from_icon_name(icon);
    b.add_css_class("carousel-arrow");
    b.set_valign(gtk::Align::Center);
    // Mouse affordance; gamepad/keyboard page by moving focus left/right.
    b.set_focusable(false);
    let c = carousel.clone();
    b.connect_clicked(move |_| step(&c, delta));
    b
}

fn featured_regular() -> gtk::Box {
    let carousel = adw::Carousel::new();
    carousel.set_allow_scroll_wheel(false);
    carousel.set_spacing(32);
    carousel.set_hexpand(true);
    for item in &snapshot().store.featured {
        carousel.append(&featured_card(item));
    }
    let row = ui::hbox(12);
    row.append(&arrow("ns-back-symbolic", &carousel, -1));
    row.append(&carousel);
    row.append(&arrow("ns-next-symbolic", &carousel, 1));
    responsive::watch(&row, |row, w| {
        let m = (w.gutter() - 44).max(4);
        row.set_margin_start(m);
        row.set_margin_end(m);
    });

    let dots = adw::CarouselIndicatorDots::new();
    dots.set_carousel(Some(&carousel));
    dots.add_css_class("featured-dots");

    let v = ui::vbox(4);
    v.add_css_class("featured");
    v.append(&row);
    v.append(&dots);
    auto_advance(&carousel, &v);
    v
}

fn featured_card(item: &'static StoreItem) -> gtk::Button {
    let grid = gtk::Grid::new();
    grid.set_column_homogeneous(true);
    let art = Art::new(Some(&item.images.capsule), CAPSULE)
        .fluid(280, 760)
        .placeholder(&item.name)
        .fallbacks([Some(item.images.header.as_str())]);
    // Capsule art ~2/3, details panel ~1/3.
    grid.attach(&art, 0, 0, 6, 1);

    let panel = ui::vbox(12);
    panel.add_css_class("featured-panel");
    let title = ui::wrap_label(&item.name, &["featured-title"], 2);
    panel.append(&title);

    let shots = gtk::Grid::new();
    shots.set_column_homogeneous(true);
    shots.set_row_spacing(8);
    shots.set_column_spacing(8);
    for (i, s) in item.screenshots.iter().take(4).enumerate() {
        let a = Art::new(Some(&s.thumbnail), SCREENSHOT)
            .fluid(40, 180)
            .class("thumb");
        shots.attach(&a, (i % 2) as i32, (i / 2) as i32, 1, 1);
    }
    panel.append(&shots);

    let status = if item.coming_soon {
        "Coming soon".to_owned()
    } else if item.discount_ends_label.is_some() {
        "Special offer".to_owned()
    } else {
        "Now available".to_owned()
    };
    panel.append(&ui::label(&status, &["featured-status"]));

    if let Some(r) = &item.review {
        let rv = ui::hbox(6);
        rv.append(&ui::label("Reviews:", &["meta"]));
        rv.append(&ui::fit_label(
            &r.label,
            &["review-label", ui::tone_class(&r.tone)],
        ));
        panel.append(&rv);
    }
    let pills = ui::hbox(6);
    for (i, g) in item.genres.iter().take(3).enumerate() {
        let p = ui::pill(g, &[]);
        if i == 2 {
            // The third genre only fits when the card is wide.
            responsive::visible_when(&p, |w| w >= Width::Large);
        }
        pills.append(&p);
    }
    panel.append(&pills);

    let filler = ui::vbox(0);
    filler.set_vexpand(true);
    panel.append(&filler);

    let bottom = ui::hbox(8);
    bottom.append(&ui::platform_icons(&item.platforms));
    bottom.append(&ui::spacer());
    bottom.append(&ui::price_block(item.price.as_ref(), false));
    panel.append(&bottom);
    grid.attach(&panel, 6, 0, 3, 1);

    let t = ui::tile(&grid, open(item.app_id));
    t.add_css_class("featured-card");
    t.add_css_class("hero-card");
    t.set_widget_name(&format!("store-{}", item.app_id));
    t
}

fn featured_compact() -> gtk::Box {
    let carousel = adw::Carousel::new();
    carousel.set_allow_scroll_wheel(false);
    carousel.set_spacing(12);
    for item in &snapshot().store.featured {
        let overlay = gtk::Overlay::new();
        let art = Art::new(Some(&item.images.capsule), CAPSULE)
            .fluid(200, 420)
            .placeholder(&item.name);
        overlay.set_child(Some(&art));
        overlay.add_overlay(&ui::scrim("scrim-bottom"));
        let info = ui::hbox(8);
        info.add_css_class("featured-compact-info");
        info.set_valign(gtk::Align::End);
        let name = ui::fit_label(&item.name, &["featured-compact-title"]);
        info.append(&name);
        info.append(&ui::price_block(item.price.as_ref(), false));
        overlay.add_overlay(&info);
        let t = ui::tile(&overlay, open(item.app_id));
        t.add_css_class("hero-card");
        t.set_widget_name(&format!("store-{}", item.app_id));
        carousel.append(&t);
    }
    responsive::gutter(&carousel);
    let dots = adw::CarouselIndicatorDots::new();
    dots.set_carousel(Some(&carousel));
    let v = ui::vbox(2);
    v.add_css_class("featured");
    v.append(&carousel);
    v.append(&dots);
    auto_advance(&carousel, &v);
    v
}

// ---------------------------------------------------------------------------
// Cards and rows
// ---------------------------------------------------------------------------

/// Shelf card: header art, name, a meta line and the price block.
pub fn store_card(item: &'static StoreItem, meta: &str) -> gtk::Button {
    let art = Art::new(Some(&item.images.header), HEADER)
        .fixed(280)
        .placeholder(&item.name);
    responsive::watch(&art, |a, w| {
        a.set_fixed_width(if w.is_compact() { 252 } else { 280 })
    });
    let body = ui::vbox(6);
    body.add_css_class("tile-body");
    body.append(&ui::fit_label(&item.name, &["tile-title"]));
    let row = ui::hbox(8);
    let meta = ui::fit_label(meta, &["tile-meta"]);
    meta.set_valign(gtk::Align::Center);
    if item.discount_ends_label.is_some() {
        meta.add_css_class("offer-ends");
    }
    row.append(&meta);
    row.append(&ui::price_block(item.price.as_ref(), false));
    body.append(&row);

    let v = ui::vbox(0);
    v.append(&art);
    v.append(&body);
    let t = ui::tile(&v, open(item.app_id));
    t.add_css_class("store-card");
    t.set_widget_name(&format!("store-{}", item.app_id));
    t
}

/// Top-seller list row: small capsule, name, platforms, review dot, price.
fn list_row(item: &'static StoreItem) -> gtk::Button {
    let h = ui::hbox(14);
    h.add_css_class("list-row");
    let art = Art::new(Some(&item.images.small_capsule), SMALL_CAPSULE)
        .fixed(144)
        .fallbacks([Some(item.images.header.as_str())]);
    h.append(&art);
    let mid = ui::vbox(4);
    mid.set_valign(gtk::Align::Center);
    mid.append(&ui::fit_label(&item.name, &["row-title"]));
    let meta = ui::hbox(8);
    meta.append(&ui::platform_icons(&item.platforms));
    meta.append(&ui::tone_dot(item.review.as_ref()));
    if let Some(r) = &item.review {
        meta.append(&ui::fit_label(&r.label, &["meta"]));
    }
    mid.append(&meta);
    h.append(&mid);
    h.append(&ui::price_block(item.price.as_ref(), false));
    let t = ui::tile(&h, open(item.app_id));
    t.add_css_class("row-tile");
    t.set_widget_name(&format!("store-{}", item.app_id));
    t
}

/// Most-played chart row: rank, header thumb, live player count, peak, price.
fn chart_row(e: &'static ChartEntry) -> gtk::Button {
    let h = ui::hbox(14);
    h.add_css_class("list-row");
    let rank = ui::label(&format!("#{}", e.rank), &["rank"]);
    rank.set_xalign(1.0);
    rank.set_width_chars(3);
    h.append(&rank);
    let art = Art::new(Some(&e.images.header), HEADER).fixed(124);
    responsive::watch(&art, |a, w| {
        a.set_fixed_width(if w.is_compact() { 84 } else { 124 })
    });
    h.append(&art);
    let mid = ui::vbox(4);
    mid.set_valign(gtk::Align::Center);
    mid.append(&ui::fit_label(&e.name, &["row-title"]));
    let live = ui::hbox(6);
    live.append(&ui::live_dot());
    live.append(&ui::fit_label(&e.current_players_label, &["live-text"]));
    let peak = ui::fit_label(&format!("·  {}", e.peak_today_label), &["meta"]);
    responsive::visible_when(&peak, |w| !w.is_compact());
    live.append(&peak);
    mid.append(&live);
    h.append(&mid);
    h.append(&ui::price_block(e.price.as_ref(), false));
    let id = e.app_id;
    let t = ui::tile(&h, move || shell::open_store_app(id));
    t.add_css_class("row-tile");
    t.set_widget_name(&format!("store-{id}"));
    t
}

// ---------------------------------------------------------------------------
// Store app page
// ---------------------------------------------------------------------------

pub fn app_page(app_id: u32) -> Option<adw::NavigationPage> {
    let item = find_item(app_id)?;

    // Full-bleed page background art that fades into the store gradient.
    let bg = gtk::Overlay::new();
    let bg_art = Art::new(item.images.background.as_deref(), 1438.0 / 810.0)
        .fluid(0, 1440)
        .max_height(640)
        .fallbacks([
            item.images.hero.as_deref(),
            Some(item.images.capsule.as_str()),
        ])
        .class("page-bg-art");
    bg.set_child(Some(&bg_art));
    bg.add_overlay(&ui::scrim("scrim-page-bg"));
    bg.set_valign(gtk::Align::Start);
    bg.set_can_target(false);

    let content = ui::vbox(20);
    content.add_css_class("app-page");

    let title = ui::wrap_label(&item.name, &["page-title"], 2);
    content.append(&title);

    // Left: screenshot carousel + thumbnails.
    let left = ui::vbox(10);
    left.set_hexpand(true);
    let carousel = adw::Carousel::new();
    carousel.set_allow_scroll_wheel(false);
    carousel.add_css_class("screenshot-carousel");
    let shots: Vec<_> = item.screenshots.iter().take(8).collect();
    if shots.is_empty() {
        let a = Art::new(Some(&item.images.capsule), SCREENSHOT)
            .fluid(240, 760)
            .placeholder(&item.name);
        carousel.append(&a);
    }
    for s in &shots {
        let a = Art::new(Some(&s.full), SCREENSHOT)
            .fluid(240, 760)
            .fallbacks([Some(s.thumbnail.as_str())])
            .class("screenshot");
        carousel.append(&a);
    }
    left.append(&carousel);
    if shots.len() > 1 {
        let strip = ui::hbox(8);
        strip.add_css_class("thumb-strip");
        for (i, s) in shots.iter().enumerate() {
            let a = Art::new(Some(&s.thumbnail), SCREENSHOT).fixed(116);
            let b = gtk::Button::new();
            b.set_child(Some(&a));
            b.add_css_class("thumb-button");
            b.set_overflow(gtk::Overflow::Hidden);
            let c = carousel.clone();
            b.connect_clicked(move |_| c.scroll_to(&c.nth_page(i as u32), true));
            strip.append(&b);
        }
        let sw = gtk::ScrolledWindow::new();
        sw.set_vscrollbar_policy(gtk::PolicyType::Never);
        sw.set_child(Some(&ui::viewport(&strip)));
        sw.add_css_class("shelf");
        left.append(&sw);
    }

    // Right: header capsule, description, review summary, facts.
    let right = ui::vbox(14);
    right.add_css_class("app-side");
    responsive::watch(&right, |r, w| {
        r.set_width_request(if w.is_compact() { -1 } else { 340 });
        r.set_hexpand(w.is_compact());
    });
    right.append(
        &Art::new(Some(&item.images.header), HEADER)
            .fluid(200, 340)
            .class("rounded"),
    );
    if let Some(d) = &item.short_description {
        right.append(&ui::wrap_label(d, &["body-text"], 0));
    }
    let facts = gtk::Grid::new();
    facts.set_row_spacing(6);
    facts.set_column_spacing(14);
    let mut row = 0;
    let mut fact = |k: &str, v: gtk::Widget| {
        facts.attach(&ui::label(&k.to_uppercase(), &["fact-key"]), 0, row, 1, 1);
        facts.attach(&v, 1, row, 1, 1);
        row += 1;
    };
    match &item.review {
        Some(r) => {
            let v = ui::vbox(0);
            v.append(&ui::label(
                &r.label,
                &["review-label", ui::tone_class(&r.tone)],
            ));
            v.append(&ui::label(
                &format!("{}% of {} are positive", r.percent_positive, r.total_label),
                &["meta"],
            ));
            fact("All reviews", v.upcast());
        }
        None => fact(
            "All reviews",
            ui::label("No user reviews", &["meta"]).upcast(),
        ),
    }
    if let Some(d) = &item.release_date {
        fact("Release date", ui::label(d, &["fact-value"]).upcast());
    }
    if !item.developers.is_empty() {
        fact(
            "Developer",
            ui::fit_label(&item.developers.join(", "), &["fact-value", "link"]).upcast(),
        );
    }
    if let Some(m) = item.metacritic {
        fact(
            "Metacritic",
            ui::label(&m.to_string(), &["metacritic"]).upcast(),
        );
    }
    right.append(&facts);
    let pills = gtk::FlowBox::new();
    pills.set_halign(gtk::Align::Start);
    pills.set_selection_mode(gtk::SelectionMode::None);
    pills.set_max_children_per_line(6);
    pills.set_row_spacing(6);
    pills.set_column_spacing(6);
    for g in &item.genres {
        let p = ui::pill(g, &[]);
        pills.append(&p);
        if let Some(fc) = pills.last_child() {
            fc.set_focusable(false);
        }
    }
    right.append(&pills);
    content.append(&ui::column_layout(vec![left.upcast(), right.upcast()], 24));

    // Purchase box (purely visual: nothing is ever bought or installed).
    let owned = snapshot().library_game(item.app_id);
    let buy = ui::hbox(16);
    buy.add_css_class("purchase-box");
    responsive::stack_on_compact(&buy);
    let words = ui::vbox(6);
    words.set_hexpand(true);
    words.set_valign(gtk::Align::Center);
    let top = ui::hbox(12);
    let title = match (owned, &item.price) {
        (Some(_), _) => format!("{} is in your library", item.name),
        (None, Some(p)) if p.is_free => format!("Play {}", item.name),
        (None, _) if item.coming_soon => format!("Wishlist {}", item.name),
        (None, None) => format!("{} on Steam", item.name),
        (None, Some(_)) => format!("Buy {}", item.name),
    };
    top.append(&ui::fit_label(&title, &["purchase-title"]));
    top.append(&ui::platform_icons(&item.platforms));
    words.append(&top);
    let sub = match (owned, &item.discount_ends_label) {
        (Some(g), _) => Some(format!(
            "{} · Last played {}",
            g.playtime_label, g.last_played_label
        )),
        (None, Some(ends)) => Some(format!("SPECIAL PROMOTION! {ends}")),
        (None, None) if item.coming_soon => item
            .release_date
            .as_ref()
            .map(|d| format!("Planned release: {d}")),
        _ => None,
    };
    if let Some(sub) = sub {
        words.append(&ui::fit_label(&sub, &["offer-ends"]));
    }
    buy.append(&words);

    let actions = ui::hbox(10);
    actions.add_css_class("purchase-actions");
    actions.set_valign(gtk::Align::Center);
    responsive::watch(&actions, |a, w| {
        let compact = w.is_compact();
        a.set_orientation(if compact {
            gtk::Orientation::Vertical
        } else {
            gtk::Orientation::Horizontal
        });
        a.set_halign(if compact {
            gtk::Align::Fill
        } else {
            gtk::Align::End
        });
    });
    match owned {
        Some(g) => {
            let (label, class) = if g.installed {
                ("Play Now", "play-button")
            } else {
                ("Install", "install-button")
            };
            let play = gtk::Button::with_label(label);
            play.add_css_class(class);
            play.add_css_class("primary-action");
            let name = g.name.clone();
            play.connect_clicked(move |_| {
                shell::get().toast(&format!("Launching {name}… (concept only)"))
            });
            actions.append(&play);
            let lib = gtk::Button::with_label("View in Library");
            lib.add_css_class("secondary-button");
            let id = g.app_id;
            lib.connect_clicked(move |_| shell::open_game(id));
            actions.append(&lib);
        }
        None => {
            if item.price.is_some() || item.coming_soon {
                actions.append(&ui::price_block(item.price.as_ref(), true));
            }
            let cart_label = match &item.price {
                Some(p) if p.is_free => "Play Game",
                Some(_) => "Add to Cart",
                None => "Follow",
            };
            let cart = gtk::Button::with_label(cart_label);
            cart.add_css_class("install-button");
            cart.add_css_class("primary-action");
            let name = item.name.clone();
            cart.connect_clicked(move |_| {
                shell::get().toast(&format!(
                    "{name} added to your cart (concept only — nothing is purchased)"
                ))
            });
            actions.append(&cart);
            let wish = gtk::Button::with_label("Add to Wishlist");
            wish.add_css_class("secondary-button");
            let name = item.name.clone();
            wish.connect_clicked(move |_| {
                shell::get().toast(&format!("{name} added to your wishlist"))
            });
            actions.append(&wish);
        }
    }
    buy.append(&actions);
    content.append(&buy);

    // Feature badges.
    let badges = ui::hbox(10);
    badges.add_css_class("feature-badges");
    if let Some(cs) = &item.controller_support {
        let b = ui::hbox(8);
        b.add_css_class("feature-badge");
        b.append(&ui::icon("ns-controller-symbolic", 18));
        let text = if cs == "full" {
            "Full Controller Support"
        } else {
            "Partial Controller Support"
        };
        b.append(&ui::label(text, &[]));
        badges.append(&b);
    }
    if item.platforms.linux {
        let b = ui::hbox(8);
        b.add_css_class("feature-badge");
        b.append(&ui::icon("ns-linux-symbolic", 18));
        b.append(&ui::label("Native Linux", &[]));
        badges.append(&b);
    }
    if badges.first_child().is_some() {
        content.append(&badges);
    }

    responsive::watch(&content, |c, w| {
        c.set_margin_start(w.gutter());
        c.set_margin_end(w.gutter());
        c.set_margin_top(if w.is_compact() { 16 } else { 40 });
    });
    let clamp = adw::Clamp::builder()
        .unit(adw::LengthUnit::Px)
        .maximum_size(1180)
        .tightening_threshold(1180)
        .child(&content)
        .build();

    let layered = gtk::Overlay::new();
    layered.set_child(Some(&bg));
    layered.add_overlay(&clamp);
    layered.set_measure_overlay(&clamp, true);
    clamp.set_valign(gtk::Align::Start);

    Some(shell::detail_page(
        &item.name,
        &ui::page_scroller(&layered),
        "bg-store",
    ))
}
