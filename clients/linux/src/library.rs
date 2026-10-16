//! LIBRARY tab (DESIGN.md §4.2): collections sidebar / chips, recent games,
//! the portrait grid with filter + sort, and the game page.

use crate::art::Art;
use crate::responsive::{self, Width};
use crate::shell::{self, Tab};
use crate::{snapshot, ui};
use adw::prelude::*;
use gtk::glib;
use std::cell::RefCell;
use std::collections::{HashMap, HashSet};
use steam_model::{Achievement, LibraryGame};

const PORTRAIT: f64 = 2.0 / 3.0;
const HERO: f64 = 1920.0 / 620.0;
const SCREENSHOT: f64 = 16.0 / 9.0;

#[derive(Clone, Copy, PartialEq, Eq)]
enum Sort {
    Alphabetical,
    Recent,
    Hours,
}

struct State {
    collection: usize,
    query: String,
    sort: Sort,
    favorites: HashSet<u32>,
}

#[derive(Default)]
struct Widgets {
    flow: Option<gtk::FlowBox>,
    title: Option<gtk::Label>,
    list: Option<gtk::ListBox>,
    chips: Vec<gtk::ToggleButton>,
    searches: Vec<gtk::SearchEntry>,
    stars: HashMap<u32, Vec<glib::WeakRef<gtk::Widget>>>,
    favorites_count: Option<gtk::Label>,
}

thread_local! {
    static STATE: RefCell<State> = RefCell::new(State {
        collection: 0,
        query: String::new(),
        sort: Sort::Alphabetical,
        favorites: snapshot().library.games.iter().filter(|g| g.favorite).map(|g| g.app_id).collect(),
    });
    static WIDGETS: RefCell<Widgets> = RefCell::new(Widgets::default());
}

fn is_favorite(id: u32) -> bool {
    STATE.with(|s| s.borrow().favorites.contains(&id))
}

fn in_collection(state: &State, game: &LibraryGame) -> bool {
    let colls = &snapshot().library.collections;
    let Some(c) = colls.get(state.collection) else {
        return true;
    };
    let member = match c.id.as_str() {
        // Favorites is live so the X button / star toggle updates it.
        "favorites" => state.favorites.contains(&game.app_id),
        _ => c.app_ids.contains(&game.app_id),
    };
    member && (state.query.is_empty() || game.name.to_lowercase().contains(&state.query))
}

fn refresh() {
    let (count, name) = STATE.with(|s| {
        let s = s.borrow();
        let count = snapshot()
            .library
            .games
            .iter()
            .filter(|g| in_collection(&s, g))
            .count();
        let name = snapshot()
            .library
            .collections
            .get(s.collection)
            .map(|c| c.name.clone())
            .unwrap_or_else(|| "All Games".into());
        (count, name)
    });
    WIDGETS.with(|w| {
        let w = w.borrow();
        if let Some(f) = &w.flow {
            f.invalidate_filter();
            f.invalidate_sort();
        }
        if let Some(t) = &w.title {
            t.set_text(&format!("{} ({count})", name.to_uppercase()));
        }
    });
}

fn set_collection(index: usize) {
    let changed = STATE.with(|s| {
        let mut s = s.borrow_mut();
        let changed = s.collection != index;
        s.collection = index;
        changed
    });
    // Sync both pickers (sidebar list and chips).
    WIDGETS.with(|w| {
        let w = w.borrow();
        if let Some(list) = &w.list {
            let name = format!("coll-{index}");
            let mut i = 0;
            while let Some(row) = list.row_at_index(i) {
                if row.widget_name() == name.as_str() {
                    if !row.is_selected() {
                        list.select_row(Some(&row));
                    }
                    break;
                }
                i += 1;
            }
        }
        if let Some(chip) = w.chips.get(index) {
            if !chip.is_active() {
                chip.set_active(true);
            }
        }
    });
    if changed {
        refresh();
    }
}

fn set_query(text: &str) {
    let q = text.trim().to_lowercase();
    let changed = STATE.with(|s| {
        let mut s = s.borrow_mut();
        let changed = s.query != q;
        s.query = q;
        changed
    });
    if changed {
        WIDGETS.with(|w| {
            for e in &w.borrow().searches {
                if e.text() != text {
                    e.set_text(text);
                }
            }
        });
        refresh();
    }
}

/// LT / RT on the gamepad.
pub fn cycle_collection(delta: i32) {
    let n = snapshot().library.collections.len() as i32;
    let cur = STATE.with(|s| s.borrow().collection) as i32;
    set_collection((cur + delta).rem_euclid(n.max(1)) as usize);
    // Land on the first game of the new collection.
    glib::idle_add_local_once(|| {
        let first = WIDGETS.with(|w| {
            let flow = w.borrow().flow.clone()?;
            let mut child = flow.first_child();
            while let Some(c) = child {
                if c.is_visible() && c.is_child_visible() {
                    return c.first_child();
                }
                child = c.next_sibling();
            }
            None
        });
        if let Some(cover) = first {
            cover.grab_focus();
            crate::input::scroll_focus_into_view(&cover);
        }
    });
}

/// X on the gamepad, or the star button on the game page.
pub fn toggle_favorite(id: u32) {
    let now = STATE.with(|s| {
        let mut s = s.borrow_mut();
        if !s.favorites.remove(&id) {
            s.favorites.insert(id);
            true
        } else {
            false
        }
    });
    WIDGETS.with(|w| {
        if let Some(l) = &w.borrow().favorites_count {
            l.set_text(&STATE.with(|s| s.borrow().favorites.len()).to_string());
        }
        if let Some(list) = w.borrow().stars.get(&id) {
            for star in list.iter().filter_map(|s| s.upgrade()) {
                if let Some(t) = star.downcast_ref::<gtk::ToggleButton>() {
                    if t.is_active() != now {
                        t.set_active(now);
                    }
                } else {
                    star.set_visible(now);
                }
            }
        }
    });
    if let Some(g) = snapshot().library_game(id) {
        let msg = if now {
            format!("Added {} to Favorites", g.name)
        } else {
            format!("Removed {} from Favorites", g.name)
        };
        shell::get().toast(&msg);
    }
    refresh();
}

fn register_star(id: u32, w: &impl IsA<gtk::Widget>) {
    WIDGETS.with(|ws| {
        ws.borrow_mut()
            .stars
            .entry(id)
            .or_default()
            .push(w.upcast_ref::<gtk::Widget>().downgrade())
    });
}

fn collection_icon(id: &str, kind: &str) -> &'static str {
    match id {
        "all" => "ns-library-symbolic",
        "favorites" => "ns-star-symbolic",
        "installed" => "ns-download-symbolic",
        "controller" => "ns-controller-symbolic",
        _ if kind == "user" => "ns-layers-symbolic",
        _ => "ns-library-symbolic",
    }
}

fn search_entry(placeholder: &str) -> gtk::SearchEntry {
    let e = gtk::SearchEntry::new();
    e.set_placeholder_text(Some(placeholder));
    e.add_css_class("steam-search");
    shell::register_search(Tab::Library, &e);
    e.connect_search_changed(|e| set_query(&e.text()));
    WIDGETS.with(|w| w.borrow_mut().searches.push(e.clone()));
    e
}

// ---------------------------------------------------------------------------
// Root page
// ---------------------------------------------------------------------------

pub fn root() -> adw::NavigationPage {
    let lib = &snapshot().library;

    let layout = ui::hbox(0);
    let side = sidebar();
    responsive::visible_when(&side, |w| w >= Width::Large);
    layout.append(&side);

    let main = ui::vbox(0);
    main.add_css_class("page-content");

    // Search + chips when there's no sidebar.
    let top = ui::vbox(12);
    top.add_css_class("library-top");
    responsive::gutter(&top);
    responsive::visible_when(&top, |w| w < Width::Large);
    top.append(&search_entry("Search your library"));
    let chips = ui::hbox(8);
    chips.add_css_class("chip-row");
    let mut chip_buttons: Vec<gtk::ToggleButton> = Vec::new();
    for (i, c) in lib.collections.iter().enumerate() {
        let b = gtk::ToggleButton::with_label(&c.name);
        b.add_css_class("chip");
        if let Some(first) = chip_buttons.first() {
            b.set_group(Some(first));
        }
        b.connect_toggled(move |b| {
            if b.is_active() {
                set_collection(i);
            }
        });
        chips.append(&b);
        chip_buttons.push(b);
    }
    if let Some(first) = chip_buttons.first() {
        first.set_active(true);
    }
    let chip_sw = gtk::ScrolledWindow::new();
    chip_sw.set_vscrollbar_policy(gtk::PolicyType::Never);
    chip_sw.set_child(Some(&ui::viewport(&chips)));
    chip_sw.add_css_class("chip-scroller");
    top.append(&chip_sw);
    main.append(&top);

    // Recent games.
    main.append(&ui::section("Recent Games", None));
    let recent = lib
        .recent_app_ids
        .iter()
        .filter_map(|id| snapshot().library_game(*id))
        .enumerate()
        .map(|(i, g)| recent_card(g, i == 0));
    main.append(&ui::shelf(recent));

    // All games grid.
    let header = ui::section_header("All Games", None);
    responsive::gutter(&header);
    let title = header
        .first_child()
        .and_then(|w| w.downcast::<gtk::Label>().ok())
        .expect("section title");
    let sort_label = ui::label("SORT BY", &["sort-label"]);
    sort_label.set_valign(gtk::Align::Center);
    header.append(&sort_label);
    let sort = gtk::DropDown::from_strings(&["Alphabetical", "Recently played", "Hours played"]);
    sort.add_css_class("sort-dropdown");
    sort.set_valign(gtk::Align::Center);
    sort.connect_selected_notify(|d| {
        let s = match d.selected() {
            1 => Sort::Recent,
            2 => Sort::Hours,
            _ => Sort::Alphabetical,
        };
        STATE.with(|st| st.borrow_mut().sort = s);
        refresh();
    });
    header.append(&sort);
    main.append(&header);

    let flow = gtk::FlowBox::new();
    flow.add_css_class("library-grid");
    flow.set_selection_mode(gtk::SelectionMode::None);
    flow.set_homogeneous(true);
    flow.set_min_children_per_line(3);
    flow.set_max_children_per_line(16);
    flow.set_valign(gtk::Align::Start);
    flow.set_activate_on_single_click(false);
    responsive::watch(&flow, |f, w| {
        f.set_margin_start(w.gutter());
        f.set_margin_end(w.gutter());
        f.set_column_spacing(if w.is_compact() { 10 } else { 16 });
        f.set_row_spacing(if w.is_compact() { 12 } else { 20 });
    });
    for g in &lib.games {
        let fc = gtk::FlowBoxChild::new();
        fc.set_child(Some(&cover(g)));
        fc.set_focusable(false);
        fc.set_widget_name(&g.app_id.to_string());
        flow.append(&fc);
    }
    let id_of = |c: &gtk::FlowBoxChild| c.widget_name().parse::<u32>().unwrap_or(0);
    flow.set_filter_func(move |c| {
        let id = id_of(c);
        snapshot()
            .library_game(id)
            .is_some_and(|g| STATE.with(|s| in_collection(&s.borrow(), g)))
    });
    flow.set_sort_func(move |a, b| {
        let (Some(ga), Some(gb)) = (
            snapshot().library_game(id_of(a)),
            snapshot().library_game(id_of(b)),
        ) else {
            return gtk::Ordering::Equal;
        };
        let ord = match STATE.with(|s| s.borrow().sort) {
            Sort::Alphabetical => ga.name.to_lowercase().cmp(&gb.name.to_lowercase()),
            // RFC 3339 strings sort chronologically; never-played last.
            Sort::Recent => gb.last_played.cmp(&ga.last_played),
            Sort::Hours => gb.playtime_minutes.cmp(&ga.playtime_minutes),
        };
        ord.into()
    });
    main.append(&flow);

    WIDGETS.with(|w| {
        let mut w = w.borrow_mut();
        w.flow = Some(flow);
        w.title = Some(title);
        w.chips = chip_buttons;
    });
    refresh();

    let scroller = ui::page_scroller(&main);
    scroller.set_hexpand(true);
    layout.append(&scroller);

    let page = adw::NavigationPage::builder()
        .title("Library")
        .tag("root")
        .child(&layout)
        .build();
    page.add_css_class("bg-library");
    page
}

fn sidebar() -> gtk::Box {
    let lib = &snapshot().library;
    let v = ui::vbox(0);
    v.add_css_class("library-sidebar");
    v.set_width_request(264);

    let entry = search_entry("Filter games");
    entry.set_margin_start(14);
    entry.set_margin_end(14);
    entry.set_margin_top(16);
    entry.set_margin_bottom(8);
    v.append(&entry);

    let list = gtk::ListBox::new();
    list.add_css_class("navigation-sidebar");
    list.add_css_class("collections");
    let heading_row = |text: &str| {
        let r = gtk::ListBoxRow::new();
        r.set_child(Some(&ui::label(text, &["sidebar-heading"])));
        r.set_selectable(false);
        r.set_activatable(false);
        r.set_focusable(false);
        r
    };
    list.append(&heading_row("COLLECTIONS"));
    let mut user_heading = false;
    for (i, c) in lib.collections.iter().enumerate() {
        if c.kind == "user" && !user_heading {
            list.append(&heading_row("MY COLLECTIONS"));
            user_heading = true;
        }
        let h = ui::hbox(10);
        h.append(&ui::icon(collection_icon(&c.id, &c.kind), 16));
        h.append(&ui::fit_label(&c.name, &["collection-name"]));
        let count = if c.id == "favorites" {
            STATE.with(|s| s.borrow().favorites.len())
        } else {
            c.app_ids.len()
        };
        let count_label = ui::label(&count.to_string(), &["count"]);
        if c.id == "favorites" {
            WIDGETS.with(|w| w.borrow_mut().favorites_count = Some(count_label.clone()));
        }
        h.append(&count_label);
        let row = gtk::ListBoxRow::new();
        row.set_child(Some(&h));
        row.set_widget_name(&format!("coll-{i}"));
        list.append(&row);
    }
    list.connect_row_selected(|_, row| {
        if let Some(i) = row
            .and_then(|r| r.widget_name().strip_prefix("coll-").map(str::to_owned))
            .and_then(|s| s.parse::<usize>().ok())
        {
            set_collection(i);
        }
    });
    if let Some(first) = list.row_at_index(1) {
        list.select_row(Some(&first));
    }
    WIDGETS.with(|w| w.borrow_mut().list = Some(list.clone()));

    let sw = gtk::ScrolledWindow::new();
    sw.set_hscrollbar_policy(gtk::PolicyType::Never);
    sw.set_vexpand(true);
    sw.set_child(Some(&ui::viewport(&list)));
    v.append(&sw);

    let footer = ui::hbox(8);
    footer.add_css_class("sidebar-footer");
    let installed = lib.games.iter().filter(|g| g.installed).count();
    footer.append(&ui::icon("ns-download-symbolic", 14));
    footer.append(&ui::label(
        &format!("{installed} of {} installed", lib.games.len()),
        &["meta"],
    ));
    v.append(&footer);
    v
}

/// Recent games: landscape hero art with the logo on top, "last played" below.
fn recent_card(g: &'static LibraryGame, first: bool) -> gtk::Box {
    let art = Art::new(g.images.hero.as_deref(), 300.0 / 176.0)
        .fixed(300)
        .fallbacks([Some(g.images.capsule.as_str())])
        .placeholder(&g.name);
    let overlay = gtk::Overlay::new();
    overlay.set_child(Some(&art));
    overlay.add_overlay(&ui::scrim("scrim-bottom"));
    let name = ui::wrap_label(&g.name, &["recent-name"], 2);
    name.set_valign(gtk::Align::End);
    name.set_visible(g.images.logo.is_none());
    if let Some(url) = &g.images.logo {
        let n = name.clone();
        let logo = Art::new(Some(url), 2.4)
            .logo(190, 64)
            .on_result(move |_, ok| n.set_visible(!ok));
        logo.set_halign(gtk::Align::Start);
        logo.set_valign(gtk::Align::End);
        logo.add_css_class("recent-logo");
        logo.set_margin_start(14);
        logo.set_margin_bottom(12);
        overlay.add_overlay(&logo);
    }
    overlay.add_overlay(&name);
    responsive::watch(&art, move |a, w| {
        let (cw, ch) = if w.is_compact() {
            (264, 150)
        } else {
            (300, 176)
        };
        let width = if first && !w.is_compact() {
            cw * 2 + 16
        } else {
            cw
        };
        a.set_fixed_width(width);
        a.set_aspect(width as f64 / ch as f64);
    });

    let id = g.app_id;
    let t = ui::tile(&overlay, move || shell::open_game(id));
    t.add_css_class("recent-card");
    t.set_widget_name(&format!("game-{id}"));
    let v = ui::vbox(8);
    v.append(&t);
    let when = ui::hbox(6);
    when.append(&ui::icon("ns-clock-symbolic", 12));
    when.append(&ui::label(&g.last_played_label, &["meta"]));
    v.append(&when);
    v
}

/// Portrait cover for the grid.
fn cover(g: &'static LibraryGame) -> gtk::Button {
    let art = Art::new(g.images.portrait.as_deref(), PORTRAIT)
        .fluid(92, 150)
        .placeholder(&g.name)
        .class("cover-art");
    let overlay = gtk::Overlay::new();
    overlay.set_child(Some(&art));

    let caption = ui::vbox(0);
    caption.add_css_class("cover-caption");
    caption.set_valign(gtk::Align::End);
    caption.set_can_target(false);
    caption.append(&ui::wrap_label(&g.name, &["cover-name"], 2));
    overlay.add_overlay(&caption);

    if g.update_available {
        let dot = ui::hbox(0);
        dot.add_css_class("update-dot");
        dot.set_halign(gtk::Align::Start);
        dot.set_valign(gtk::Align::Start);
        dot.set_tooltip_text(Some("Update available"));
        overlay.add_overlay(&dot);
    }
    let star = ui::icon("ns-star-symbolic", 14);
    star.add_css_class("fav-star");
    star.set_halign(gtk::Align::End);
    star.set_valign(gtk::Align::Start);
    star.set_visible(is_favorite(g.app_id));
    star.set_can_target(false);
    register_star(g.app_id, &star);
    overlay.add_overlay(&star);
    if !g.installed {
        let dl = ui::icon("ns-download-symbolic", 14);
        dl.add_css_class("not-installed-glyph");
        dl.set_halign(gtk::Align::End);
        dl.set_valign(gtk::Align::End);
        dl.set_tooltip_text(Some("Not installed"));
        overlay.add_overlay(&dl);
    }

    let id = g.app_id;
    let t = ui::tile(&overlay, move || shell::open_game(id));
    t.add_css_class("cover");
    if !g.installed {
        t.add_css_class("not-installed");
    }
    t.set_widget_name(&format!("game-{id}"));
    t.set_tooltip_text(Some(&g.name));
    t
}

// ---------------------------------------------------------------------------
// Game page
// ---------------------------------------------------------------------------

fn stat(key: &str, value: &impl IsA<gtk::Widget>) -> gtk::Box {
    let v = ui::vbox(4);
    v.add_css_class("stat");
    v.append(&ui::label(&key.to_uppercase(), &["stat-key"]));
    v.append(value);
    v
}

fn icon_button(icon: &str, tip: &str) -> gtk::Button {
    let b = gtk::Button::from_icon_name(icon);
    b.set_tooltip_text(Some(tip));
    b.add_css_class("icon-button");
    b.set_valign(gtk::Align::Center);
    b
}

fn achievement_icon(a: &Achievement, size: i32) -> Art {
    let art = Art::new(Some(&a.icon_url), 1.0)
        .fixed(size)
        .class("achievement-icon");
    let tip = match &a.unlocked_label {
        Some(l) => format!("{}\n{l}", a.name),
        None => format!("{}\nLocked", a.name),
    };
    art.set_tooltip_text(Some(&tip));
    if !a.unlocked {
        art.add_css_class("locked");
    }
    art
}

pub fn game_page(app_id: u32) -> Option<adw::NavigationPage> {
    let snap = snapshot();
    let g = snap.library_game(app_id)?;
    let content = ui::vbox(0);
    content.add_css_class("game-page");

    // Hero with logo.
    let hero = gtk::Overlay::new();
    hero.add_css_class("game-hero");
    let art = Art::new(g.images.hero.as_deref(), HERO)
        .fluid(0, 1440)
        .min_height(220)
        .max_height(480)
        .fallbacks([
            g.images.background.as_deref(),
            Some(g.images.capsule.as_str()),
        ])
        .placeholder(&g.name);
    hero.set_child(Some(&art));
    hero.add_overlay(&ui::scrim("scrim-hero"));
    let hero_title = ui::wrap_label(&g.name, &["hero-title"], 2);
    hero_title.set_valign(gtk::Align::End);
    hero_title.set_visible(g.images.logo.is_none());
    if let Some(url) = &g.images.logo {
        let t = hero_title.clone();
        let logo = Art::new(Some(url), 2.4)
            .logo(460, 170)
            .on_result(move |_, ok| t.set_visible(!ok));
        logo.set_halign(gtk::Align::Start);
        logo.set_valign(gtk::Align::End);
        responsive::watch(&logo, |l, w| {
            l.set_margin_start(w.gutter() + 8);
            l.set_margin_bottom(if w.is_compact() { 20 } else { 40 });
            if w.is_compact() {
                l.set_logo_box(240, 96);
            } else {
                l.set_logo_box(460, 170);
            }
        });
        hero.add_overlay(&logo);
    }
    responsive::watch(&hero_title, |l, w| {
        l.set_margin_start(w.gutter() + 8);
        l.set_margin_end(w.gutter());
        l.set_margin_bottom(if w.is_compact() { 20 } else { 40 });
    });
    hero.add_overlay(&hero_title);
    content.append(&hero);

    // Action bar: PLAY / INSTALL + stats + secondary buttons.
    // Action bar: [PLAY] [stats…] [★ ⚙ ⓘ] on one row when wide; on narrower
    // windows the stats drop to a second row below the buttons.
    let bar = gtk::Grid::new();
    bar.add_css_class("game-bar");
    let primary = gtk::Button::new();
    primary.add_css_class("primary-action");
    let inner = ui::hbox(10);
    if g.installed {
        primary.add_css_class("play-button");
        inner.append(&ui::icon("ns-play-symbolic", 18));
        inner.append(&ui::label("PLAY", &["primary-label"]));
        let name = g.name.clone();
        primary.connect_clicked(move |_| {
            shell::get().toast(&format!("Launching {name}… (concept only)"))
        });
    } else {
        primary.add_css_class("install-button");
        inner.append(&ui::icon("ns-download-symbolic", 18));
        let words = ui::vbox(0);
        words.append(&ui::label("INSTALL", &["primary-label"]));
        words.append(&ui::label(&g.size_label, &["button-sub"]));
        inner.append(&words);
        let name = g.name.clone();
        primary.connect_clicked(move |_| {
            shell::get().toast(&format!("Installing {name}… (concept only)"))
        });
    }
    inner.set_halign(gtk::Align::Center);
    primary.set_child(Some(&inner));
    primary.set_valign(gtk::Align::Center);

    let mut stat_items: Vec<gtk::Widget> = vec![
        stat(
            "Last played",
            &ui::label(&g.last_played_label, &["stat-value"]),
        )
        .upcast(),
        stat("Play time", &ui::label(&g.playtime_label, &["stat-value"])).upcast(),
    ];
    if let Some(a) = &g.achievements {
        let row = ui::hbox(10);
        row.append(&ui::label(
            &format!("{}/{}", a.unlocked, a.total),
            &["stat-value"],
        ));
        let p = ui::progress(a.fraction as f64);
        p.set_width_request(100);
        p.set_hexpand(true);
        row.append(&p);
        stat_items.push(stat("Achievements", &row).upcast());
    }
    if !g.installed || g.update_available {
        let size = if g.update_available {
            "Update available"
        } else {
            "Not installed"
        };
        stat_items.push(stat("Status", &ui::label(size, &["stat-value", "accent-text"])).upcast());
    }
    let n_stats = stat_items.len();
    let stats = ui::columns(
        stat_items,
        move |w| if w.is_compact() { 2 } else { n_stats },
    );
    stats.add_css_class("game-stats");
    stats.set_column_homogeneous(false);
    stats.set_column_spacing(36);
    stats.set_row_spacing(14);
    stats.set_valign(gtk::Align::Center);

    let secondary = ui::hbox(8);
    secondary.set_valign(gtk::Align::Center);
    let fav = gtk::ToggleButton::new();
    fav.set_icon_name("ns-star-outline-symbolic");
    fav.add_css_class("icon-button");
    fav.add_css_class("fav-toggle");
    fav.set_tooltip_text(Some("Favorite"));
    fav.set_active(is_favorite(app_id));
    if fav.is_active() {
        fav.set_icon_name("ns-star-symbolic");
    }
    fav.connect_toggled(move |b| {
        b.set_icon_name(if b.is_active() {
            "ns-star-symbolic"
        } else {
            "ns-star-outline-symbolic"
        });
        if b.is_active() != is_favorite(app_id) {
            toggle_favorite(app_id);
        }
    });
    register_star(app_id, &fav);
    secondary.append(&fav);
    let gear = icon_button("ns-gear-symbolic", "Properties");
    gear.connect_clicked(|_| shell::get().toast("Game properties are not part of this concept"));
    secondary.append(&gear);
    let info = icon_button("ns-info-symbolic", "Store page");
    info.connect_clicked(move |_| shell::open_store_app(app_id));
    secondary.append(&info);
    secondary.set_halign(gtk::Align::End);
    secondary.set_hexpand(true);
    responsive::watch(&bar, move |bar, w| {
        for c in [
            primary.upcast_ref::<gtk::Widget>(),
            stats.upcast_ref(),
            secondary.upcast_ref(),
        ] {
            if c.parent().is_some() {
                bar.remove(c);
            }
        }
        bar.set_margin_start(w.gutter());
        bar.set_margin_end(w.gutter());
        bar.set_column_spacing(if w.is_compact() { 12 } else { 28 });
        bar.set_row_spacing(18);
        if w == Width::Wide {
            bar.attach(&primary, 0, 0, 1, 1);
            bar.attach(&stats, 1, 0, 1, 1);
            bar.attach(&secondary, 2, 0, 1, 1);
        } else {
            bar.attach(&primary, 0, 0, 1, 1);
            bar.attach(&secondary, 1, 0, 1, 1);
            bar.attach(&stats, 0, 1, 2, 1);
        }
    });
    content.append(&bar);

    // Two columns: activity-ish sections + side info.
    let main = ui::vbox(28);
    main.set_hexpand(true);

    if let Some(a) = &g.achievements {
        let sec = ui::vbox(12);
        let head = ui::section_header("Achievements", None);
        head.append(&ui::label(
            &format!(
                "{} of {} unlocked · {:.0}%",
                a.unlocked,
                a.total,
                a.fraction * 100.0
            ),
            &["meta"],
        ));
        sec.append(&head);
        let p = ui::progress(a.fraction as f64);
        p.add_css_class("achievement-progress");
        sec.append(&p);
        let strip = gtk::FlowBox::new();
        strip.set_selection_mode(gtk::SelectionMode::None);
        strip.set_max_children_per_line(12);
        strip.set_min_children_per_line(4);
        strip.set_column_spacing(10);
        strip.set_row_spacing(10);
        strip.set_homogeneous(true);
        for ach in &a.highlighted {
            let fc = gtk::FlowBoxChild::new();
            let icon = achievement_icon(ach, 64);
            icon.set_halign(gtk::Align::Start);
            fc.set_child(Some(&icon));
            fc.set_focusable(false);
            strip.append(&fc);
        }
        sec.append(&strip);
        main.append(&sec);
    }

    if !g.screenshots.is_empty() {
        let sec = ui::vbox(12);
        sec.append(&ui::section_header("Screenshots", None));
        let shots: Vec<gtk::Widget> = g
            .screenshots
            .iter()
            .take(6)
            .map(|s| {
                Art::new(Some(&s.thumbnail), SCREENSHOT)
                    .fluid(120, 320)
                    .class("rounded")
                    .upcast()
            })
            .collect();
        let grid = ui::columns(shots, |w| if w.is_compact() { 2 } else { 3 });
        grid.set_row_spacing(12);
        grid.set_column_spacing(12);
        sec.append(&grid);
        main.append(&sec);
    }

    let about = ui::vbox(12);
    about.append(&ui::section_header("About", None));
    if let Some(d) = &g.short_description {
        about.append(&ui::wrap_label(d, &["body-text"], 0));
    }
    let facts = gtk::Grid::new();
    facts.set_row_spacing(8);
    facts.set_column_spacing(18);
    let mut r = 0;
    let mut fact = |k: &str, v: &str| {
        facts.attach(&ui::label(&k.to_uppercase(), &["fact-key"]), 0, r, 1, 1);
        facts.attach(&ui::fit_label(v, &["fact-value"]), 1, r, 1, 1);
        r += 1;
    };
    if !g.developers.is_empty() {
        fact("Developer", &g.developers.join(", "));
    }
    if let Some(d) = &g.release_date {
        fact("Release date", d);
    }
    if !g.genres.is_empty() {
        fact("Genres", &g.genres.join(", "));
    }
    fact(
        "Size on disk",
        if g.installed { &g.size_label } else { "—" },
    );
    about.append(&facts);
    if let Some(cs) = &g.controller_support {
        let b = ui::hbox(8);
        b.add_css_class("feature-badge");
        b.set_halign(gtk::Align::Start);
        b.append(&ui::icon("ns-controller-symbolic", 18));
        b.append(&ui::label(
            if cs == "full" {
                "Full Controller Support"
            } else {
                "Partial Controller Support"
            },
            &[],
        ));
        about.append(&b);
    }
    main.append(&about);

    let side = ui::vbox(24);
    side.add_css_class("game-side");
    responsive::watch(&side, |s, w| {
        s.set_width_request(if w <= Width::Medium { -1 } else { 340 });
    });
    let friends: Vec<_> = g
        .friends_playing
        .iter()
        .filter_map(|id| snap.friend(id))
        .collect();
    let fsec = ui::vbox(10);
    fsec.add_css_class("side-card");
    fsec.append(&ui::section_header("Friends who play", None));
    if friends.is_empty() {
        fsec.append(&ui::label("None of your friends play this yet.", &["meta"]));
    } else {
        fsec.append(&ui::label(
            &format!(
                "{} friend{} play{} {}",
                friends.len(),
                if friends.len() == 1 { "" } else { "s" },
                if friends.len() == 1 { "s" } else { "" },
                g.name
            ),
            &["meta"],
        ));
        for f in friends {
            fsec.append(&crate::community::friend_row(f));
        }
    }
    side.append(&fsec);

    let you = ui::vbox(10);
    you.add_css_class("side-card");
    you.append(&ui::section_header("Your activity", None));
    if let Some(two) = &g.playtime_two_weeks_label {
        you.append(&ui::label(two, &["fact-value"]));
    }
    you.append(&ui::label(&g.playtime_label, &["meta"]));
    if let Some(a) = &g.achievements {
        let unlocked: Vec<_> = a
            .highlighted
            .iter()
            .filter(|x| x.unlocked)
            .take(4)
            .collect();
        if !unlocked.is_empty() {
            let row = ui::hbox(8);
            for x in unlocked {
                row.append(&achievement_icon(x, 40));
            }
            you.append(&row);
        }
    }
    side.append(&you);
    let cols = ui::column_layout_stacked_when(vec![main.upcast(), side.upcast()], 40, |w| {
        w <= Width::Medium
    });
    cols.add_css_class("game-columns");
    responsive::gutter(&cols);
    content.append(&cols);

    let clamp_tail = ui::vbox(0);
    clamp_tail.set_height_request(48);
    content.append(&clamp_tail);

    Some(shell::detail_page(
        &g.name,
        &ui::page_scroller(&content),
        "bg-library",
    ))
}
