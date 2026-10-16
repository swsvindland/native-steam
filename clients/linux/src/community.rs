//! COMMUNITY tab (DESIGN.md §4.3): friend activity, news, popular hubs and
//! the friends list (right rail on wide windows, its own page elsewhere).

use crate::art::Art;
use crate::responsive::{self, Width};
use crate::{shell, snapshot, ui};
use adw::prelude::*;
use std::cell::RefCell;
use steam_model::{ActivityItem, Friend, Hub, NewsItem};

const HEADER: f64 = 460.0 / 215.0;
const SCREENSHOT: f64 = 16.0 / 9.0;

thread_local! {
    static SECTIONS: RefCell<Option<(gtk::Stack, Vec<gtk::ToggleButton>)>> = const { RefCell::new(None) };
}

const SECTION_NAMES: [(&str, &str); 3] =
    [("activity", "Activity"), ("news", "News"), ("hubs", "Hubs")];

/// LT / RT: switch Activity | News | Hubs on compact widths.
pub fn cycle_section(delta: i32) {
    SECTIONS.with(|s| {
        if let Some((stack, buttons)) = s.borrow().as_ref() {
            if !stack.is_mapped() {
                return;
            }
            let cur = stack
                .visible_child_name()
                .and_then(|n| SECTION_NAMES.iter().position(|(id, _)| *id == n.as_str()))
                .unwrap_or(0) as i32;
            let next = (cur + delta).rem_euclid(SECTION_NAMES.len() as i32) as usize;
            buttons[next].set_active(true);
        }
    });
}

pub fn root() -> adw::NavigationPage {
    let c = &snapshot().community;
    let outer = ui::vbox(0);
    outer.add_css_class("page-content");

    // --- Regular: Activity | News (| Rail ≥ 1100) -------------------------------
    let activity_col = ui::vbox(14);
    activity_col.set_hexpand(true);
    activity_col.append(&ui::section_header("Friend Activity", None));
    for a in &c.activity {
        activity_col.append(&activity_card(a));
    }

    let news_col = ui::vbox(14);
    news_col.add_css_class("news-column");
    responsive::watch(&news_col, |n, w| {
        n.set_width_request(if w >= Width::Large { 380 } else { -1 })
    });
    news_col.append(&ui::section_header("News", Some("All news")));
    for n in &c.news {
        news_col.append(&news_card(n));
    }

    let rail = ui::vbox(28);
    rail.add_css_class("rail");
    rail.set_width_request(300);
    responsive::visible_when(&rail, |w| w == Width::Wide);
    let hubs = ui::vbox(10);
    hubs.append(&ui::section_header("Popular Hubs", None));
    for (i, h) in c.hubs.iter().enumerate() {
        hubs.append(&hub_row(i + 1, h));
    }
    rail.append(&hubs);
    let friends = ui::vbox(10);
    friends.add_css_class("side-card");
    friends.append(&friends_list());
    rail.append(&friends);
    // News sits beside Activity from 1000 px, below it on medium widths.
    let regular = ui::column_layout_stacked_when(
        vec![activity_col.upcast(), news_col.upcast(), rail.upcast()],
        28,
        |w| w < Width::Large,
    );
    responsive::gutter(&regular);
    responsive::visible_when(&regular, |w| !w.is_compact());
    outer.append(&regular);

    // --- Compact: segmented Activity | News | Hubs ----------------------------
    let compact = ui::vbox(14);
    responsive::visible_when(&compact, Width::is_compact);
    let seg = ui::hbox(0);
    seg.add_css_class("linked");
    seg.add_css_class("segmented");
    seg.set_homogeneous(true);
    responsive::gutter(&seg);
    let stack = gtk::Stack::new();
    stack.set_transition_type(gtk::StackTransitionType::Crossfade);
    stack.set_vhomogeneous(false);
    let mut buttons: Vec<gtk::ToggleButton> = Vec::new();
    for (id, title) in SECTION_NAMES {
        let b = gtk::ToggleButton::with_label(title);
        if let Some(first) = buttons.first() {
            b.set_group(Some(first));
        }
        let st = stack.clone();
        b.connect_toggled(move |b| {
            if b.is_active() {
                st.set_visible_child_name(id);
            }
        });
        seg.append(&b);
        buttons.push(b);
    }
    let list = |items: Vec<gtk::Widget>| {
        let v = ui::vbox(12);
        responsive::gutter(&v);
        for i in items {
            v.append(&i);
        }
        v
    };
    stack.add_named(
        &list(
            c.activity
                .iter()
                .map(|a| activity_card(a).upcast())
                .collect(),
        ),
        Some("activity"),
    );
    stack.add_named(
        &list(c.news.iter().map(|n| news_card(n).upcast()).collect()),
        Some("news"),
    );
    let mut hub_items: Vec<gtk::Widget> = c
        .hubs
        .iter()
        .enumerate()
        .map(|(i, h)| hub_row(i + 1, h).upcast())
        .collect();
    let all_friends = gtk::Button::with_label("Friends list");
    all_friends.add_css_class("secondary-button");
    all_friends.connect_clicked(|_| shell::open_friends());
    hub_items.push(all_friends.upcast());
    stack.add_named(&list(hub_items), Some("hubs"));
    buttons[0].set_active(true);
    compact.append(&seg);
    compact.append(&stack);
    outer.append(&compact);
    SECTIONS.with(|s| *s.borrow_mut() = Some((stack, buttons)));

    let clamp = adw::Clamp::builder()
        .unit(adw::LengthUnit::Px)
        .maximum_size(1600)
        .tightening_threshold(1600)
        .child(&outer)
        .build();
    let page = adw::NavigationPage::builder()
        .title("Community")
        .tag("root")
        .child(&ui::page_scroller(&clamp))
        .build();
    page.add_css_class("bg-store");
    page
}

fn friend_status(id: &str) -> &'static str {
    snapshot()
        .friend(id)
        .map(|f| f.status.as_str())
        .unwrap_or("offline")
}

fn activity_card(a: &'static ActivityItem) -> gtk::Button {
    let v = ui::vbox(14);
    v.add_css_class("activity-card");

    let head = ui::hbox(12);
    let status = friend_status(&a.friend_id);
    head.append(&ui::avatar(&a.friend_avatar_url, 40, Some(status)));
    let who = ui::vbox(2);
    who.set_valign(gtk::Align::Center);
    let line = ui::markup_label(
        &format!(
            "<span weight=\"bold\" foreground=\"{}\">{}</span> {} <span weight=\"bold\" foreground=\"#ffffff\">{}</span>",
            ui::status_hex(status),
            ui::esc(&a.friend_name),
            ui::esc(&a.headline),
            ui::esc(&a.app_name)
        ),
        &["activity-line"],
    );
    line.set_wrap(true);
    line.set_max_width_chars(1);
    line.set_hexpand(true);
    who.append(&line);
    who.append(&ui::label(&a.time_label, &["meta"]));
    head.append(&who);
    v.append(&head);

    match a.kind.as_str() {
        "achievement" => {
            if let Some(ach) = &a.achievement {
                let body = ui::hbox(14);
                body.add_css_class("achievement-body");
                body.append(
                    &Art::new(Some(&ach.icon_url), 1.0)
                        .fixed(64)
                        .class("achievement-icon"),
                );
                let t = ui::vbox(4);
                t.set_valign(gtk::Align::Center);
                t.append(&ui::fit_label(&ach.name, &["row-title"]));
                if let Some(l) = &ach.unlocked_label {
                    t.append(&ui::label(l, &["meta"]));
                }
                body.append(&t);
                v.append(&body);
            }
        }
        "screenshot" => {
            let art = Art::new(a.image_url.as_deref(), SCREENSHOT)
                .fluid(160, 620)
                .fallbacks([Some(a.app_images.header.as_str())])
                .class("rounded");
            v.append(&art);
        }
        "review" => {
            if let Some(r) = &a.review {
                let verdict = ui::hbox(10);
                verdict.add_css_class("review-verdict");
                verdict.add_css_class(if r.recommended {
                    "recommended"
                } else {
                    "not-recommended"
                });
                verdict.append(&ui::icon(
                    if r.recommended {
                        "ns-thumbs-up-symbolic"
                    } else {
                        "ns-thumbs-down-symbolic"
                    },
                    22,
                ));
                let t = ui::vbox(0);
                t.append(&ui::label(
                    if r.recommended {
                        "Recommended"
                    } else {
                        "Not Recommended"
                    },
                    &["verdict"],
                ));
                t.append(&ui::label(&r.hours_label, &["meta"]));
                verdict.append(&t);
                v.append(&verdict);
                v.append(&ui::wrap_label(
                    &format!("“{}”", r.body),
                    &["review-quote"],
                    0,
                ));
            }
        }
        _ => {
            // nowPlaying / newGame: the game's header with its name.
            let card = ui::hbox(14);
            card.add_css_class("game-ref");
            let url = a.image_url.as_deref().unwrap_or(&a.app_images.header);
            let art = Art::new(Some(url), HEADER).fixed(184).class("rounded");
            responsive::watch(&art, |a, w| {
                a.set_fixed_width(if w.is_compact() { 128 } else { 184 })
            });
            card.append(&art);
            let t = ui::vbox(4);
            t.set_valign(gtk::Align::Center);
            t.append(&ui::fit_label(&a.app_name, &["row-title"]));
            let hint = if a.kind == "nowPlaying" {
                "Playing now"
            } else {
                "New in library"
            };
            t.append(&ui::label(hint, &["meta", "ingame-text"]));
            card.append(&t);
            v.append(&card);
        }
    }

    let foot = ui::hbox(18);
    foot.add_css_class("activity-footer");
    let likes = ui::hbox(6);
    likes.append(&ui::icon("ns-thumbs-up-symbolic", 14));
    likes.append(&ui::label(&a.likes.to_string(), &["meta"]));
    foot.append(&likes);
    let comments = ui::hbox(6);
    comments.append(&ui::icon("ns-comment-symbolic", 14));
    comments.append(&ui::label(&a.comments.to_string(), &["meta"]));
    foot.append(&comments);
    v.append(&foot);

    let id = a.app_id;
    let t = ui::tile(&v, move || shell::open_app(id));
    t.add_css_class("panel-tile");
    t
}

fn news_card(n: &'static NewsItem) -> gtk::Button {
    let h = ui::hbox(14);
    h.add_css_class("news-card");
    let url = n.image_url.as_deref().unwrap_or(&n.app_images.header);
    let art = Art::new(Some(url), HEADER)
        .fixed(132)
        .fallbacks([Some(n.app_images.header.as_str())])
        .class("rounded");
    art.set_valign(gtk::Align::Start);
    h.append(&art);
    let t = ui::vbox(4);
    t.append(&ui::fit_label(
        &format!("{} · {} · {}", n.app_name, n.feed_label, n.date_label),
        &["meta"],
    ));
    t.append(&ui::wrap_label(&n.title, &["news-title"], 2));
    t.append(&ui::wrap_label(&n.excerpt, &["news-excerpt"], 3));
    h.append(&t);
    let id = n.app_id;
    let tile = ui::tile(&h, move || shell::open_app(id));
    tile.add_css_class("panel-tile");
    tile
}

/// Hubs arrive ordered by live player count; `position` is that order (the
/// data's own `rank` field is the store-chart rank and has gaps).
fn hub_row(position: usize, hub: &'static Hub) -> gtk::Button {
    let h = ui::hbox(12);
    h.add_css_class("list-row");
    let rank = ui::label(&format!("#{position}"), &["rank"]);
    rank.set_width_chars(3);
    rank.set_xalign(1.0);
    h.append(&rank);
    h.append(
        &Art::new(Some(&hub.images.header), HEADER)
            .fixed(96)
            .class("rounded"),
    );
    let t = ui::vbox(4);
    t.set_valign(gtk::Align::Center);
    t.append(&ui::fit_label(&hub.name, &["row-title"]));
    let live = ui::hbox(6);
    live.append(&ui::live_dot());
    live.append(&ui::fit_label(&hub.current_players_label, &["live-text"]));
    t.append(&live);
    h.append(&t);
    let id = hub.app_id;
    let tile = ui::tile(&h, move || shell::open_store_app(id));
    tile.add_css_class("row-tile");
    tile
}

/// Avatar + status-coloured name + status label.
pub fn friend_row(f: &'static Friend) -> gtk::Box {
    let h = ui::hbox(12);
    h.add_css_class("friend-row");
    h.add_css_class(ui::status_class(&f.status));
    h.append(&ui::avatar(&f.avatar_url, 36, Some(&f.status)));
    let t = ui::vbox(1);
    t.set_valign(gtk::Align::Center);
    t.append(&ui::fit_label(&f.persona_name, &["friend-name"]));
    t.append(&ui::fit_label(&f.status_label, &["friend-status"]));
    h.append(&t);
    let level = ui::label(
        &f.level.to_string(),
        &["level-chip", "ring", &ui::color_class(&f.level_color)],
    );
    level.set_valign(gtk::Align::Center);
    level.set_tooltip_text(Some(&format!("Steam level {}", f.level)));
    h.append(&level);
    h
}

/// Friends grouped In-Game / Online / Offline.
pub fn friends_list() -> gtk::Box {
    let friends = &snapshot().friends;
    let v = ui::vbox(8);
    v.append(&ui::section_header(
        &format!("Friends  {}", friends.len()),
        None,
    ));
    let groups: [(&str, &[&str]); 3] = [
        ("In-Game", &["inGame"]),
        ("Online", &["online", "away"]),
        ("Offline", &["offline"]),
    ];
    for (title, statuses) in groups {
        let members: Vec<_> = friends
            .iter()
            .filter(|f| statuses.contains(&f.status.as_str()))
            .collect();
        if members.is_empty() {
            continue;
        }
        v.append(&ui::label(
            &format!("{} ({})", title.to_uppercase(), members.len()),
            &["friend-group"],
        ));
        for f in members {
            v.append(&friend_row(f));
        }
    }
    v
}

pub fn friends_page() -> adw::NavigationPage {
    let v = ui::vbox(0);
    v.add_css_class("friends-page");
    let inner = friends_list();
    responsive::gutter(&inner);
    v.append(&inner);
    let clamp = adw::Clamp::builder()
        .unit(adw::LengthUnit::Px)
        .maximum_size(560)
        .child(&v)
        .build();
    shell::detail_page("Friends", &ui::page_scroller(&clamp), "bg-library")
}
