//! The persona tab — KESTREL (DESIGN.md §4.4).

use crate::art::Art;
use crate::responsive::{self, Width};
use crate::{shell, snapshot, ui};
use adw::prelude::*;
use steam_model::group_thousands;

const HERO: f64 = 1920.0 / 620.0;
const HEADER: f64 = 460.0 / 215.0;
const SCREENSHOT: f64 = 16.0 / 9.0;

fn badge_icon(icon: &str) -> &'static str {
    match icon {
        "years" => "ns-calendar-symbolic",
        "sale" => "ns-tag-symbolic",
        "collector" => "ns-layers-symbolic",
        "community" => "ns-community-symbolic",
        "awards" => "ns-medal-symbolic",
        "deck" => "ns-deck-symbolic",
        "trophy" => "ns-trophy-symbolic",
        _ => "ns-star-symbolic",
    }
}

/// Level ring: a circle outlined in the level colour with the number inside.
fn level_ring(level: u32, color: &str, size: i32) -> gtk::Label {
    let l = ui::label(
        &level.to_string(),
        &["level-ring", "ring", &ui::color_class(color)],
    );
    l.set_xalign(0.5);
    l.set_size_request(size, size);
    l.set_valign(gtk::Align::Center);
    l.set_halign(gtk::Align::Center);
    l
}

pub fn root() -> adw::NavigationPage {
    let snap = snapshot();
    let u = &snap.user;
    let content = ui::vbox(0);
    content.add_css_class("profile-page");

    // --- Banner ----------------------------------------------------------------
    let banner = gtk::Overlay::new();
    banner.add_css_class("profile-banner");
    let bg = Art::new(Some(&u.background_url), HERO)
        .fluid(0, 1440)
        .min_height(300)
        .max_height(380)
        .class("banner-art");
    banner.set_child(Some(&bg));
    banner.add_overlay(&ui::scrim("scrim-banner"));

    let head = ui::hbox(28);
    head.add_css_class("profile-head");
    head.set_valign(gtk::Align::End);
    let avatar = ui::avatar(&u.avatar_url, 164, Some(&u.status));
    avatar.add_css_class("profile-avatar");
    avatar.set_valign(gtk::Align::End);
    head.append(&avatar);

    let who = ui::vbox(6);
    who.set_valign(gtk::Align::End);
    who.set_hexpand(true);
    who.append(&ui::label(&u.persona_name, &["persona-name"]));
    who.append(&ui::label(
        &format!("{} · {}", u.real_name, u.country),
        &["persona-sub"],
    ));
    let online = ui::hbox(6);
    online.append(&ui::live_dot());
    online.append(&ui::label("Online", &["online-text"]));
    who.append(&online);
    head.append(&who);

    let level_box = ui::vbox(8);
    level_box.add_css_class("level-box");
    level_box.set_valign(gtk::Align::End);
    let lvl = ui::hbox(12);
    lvl.append(&ui::label("Level", &["level-word"]));
    lvl.append(&level_ring(u.level, &u.level_color, 46));
    level_box.append(&lvl);
    level_box.append(&ui::label(&u.xp_to_next_label, &["meta"]));
    let xp = ui::progress(u.xp_fraction as f64);
    xp.set_width_request(190);
    level_box.append(&xp);
    let edit = gtk::Button::with_label("Edit Profile");
    edit.add_css_class("secondary-button");
    edit.connect_clicked(|_| shell::get().toast("Profile editing isn't part of this concept"));
    level_box.append(&edit);
    head.append(&level_box);

    responsive::watch(&head, move |h, w| {
        let compact = w.is_compact();
        h.set_margin_start(w.gutter());
        h.set_margin_end(w.gutter());
        h.set_margin_bottom(if compact { 16 } else { 28 });
        h.set_spacing(if compact { 14 } else { 28 });
    });
    responsive::watch(&avatar, |a, w| {
        a.set_fixed_width(if w.is_compact() { 88 } else { 164 })
    });
    responsive::visible_when(&level_box, |w| !w.is_compact());
    // Align the banner content with the clamped body below it.
    let head_clamp = adw::Clamp::builder()
        .unit(adw::LengthUnit::Px)
        .maximum_size(1280)
        .tightening_threshold(1280)
        .child(&head)
        .build();
    head_clamp.set_valign(gtk::Align::End);
    banner.add_overlay(&head_clamp);
    content.append(&banner);

    // --- Body (clamped) --------------------------------------------------------
    let body = ui::vbox(28);
    body.add_css_class("profile-body");
    responsive::gutter(&body);

    // Summary + member since (+ level on compact).
    let summary = ui::vbox(8);
    summary.add_css_class("summary");
    summary.append(&ui::wrap_label(
        &u.summary,
        &["body-text", "summary-text"],
        0,
    ));
    let since = ui::hbox(10);
    since.append(&ui::label(&u.member_since_label, &["meta"]));
    since.append(&ui::pill(&u.years_label, &["years-pill"]));
    summary.append(&since);
    let compact_level = ui::hbox(12);
    compact_level.append(&level_ring(u.level, &u.level_color, 40));
    let xpv = ui::vbox(4);
    xpv.set_valign(gtk::Align::Center);
    xpv.set_hexpand(true);
    xpv.append(&ui::label(&u.xp_to_next_label, &["meta"]));
    xpv.append(&ui::progress(u.xp_fraction as f64));
    compact_level.append(&xpv);
    responsive::visible_when(&compact_level, Width::is_compact);
    summary.append(&compact_level);
    body.append(&summary);

    // Stats row.
    let st = &u.stats;
    let stats: Vec<(String, &str)> = vec![
        (group_thousands(st.games_owned as u64), "Games"),
        (group_thousands(st.achievements as u64), "Achievements"),
        (group_thousands(st.perfect_games as u64), "Perfect games"),
        (st.hours_label.clone(), "Hours played"),
        (group_thousands(st.friends as u64), "Friends"),
        (group_thousands(st.screenshots as u64), "Screenshots"),
        (group_thousands(st.reviews as u64), "Reviews"),
    ];
    let cells: Vec<gtk::Widget> = stats
        .into_iter()
        .map(|(n, k)| {
            let c = ui::vbox(2);
            c.add_css_class("stat-cell");
            let num = ui::label(&n, &["stat-number"]);
            num.set_xalign(0.5);
            let key = ui::wrap_label(&k.to_uppercase(), &["stat-caption"], 2);
            key.set_xalign(0.5);
            key.set_justify(gtk::Justification::Center);
            key.set_wrap_mode(gtk::pango::WrapMode::Word);
            c.append(&num);
            c.append(&key);
            c.upcast()
        })
        .collect();
    let stats_grid = ui::columns(cells, |w| if w <= Width::Medium { 4 } else { 7 });
    stats_grid.add_css_class("stats-card");
    stats_grid.set_column_spacing(0);
    stats_grid.set_row_spacing(14);
    body.append(&stats_grid);

    // Two columns on regular widths.
    let main = ui::vbox(28);
    main.set_hexpand(true);
    let side = ui::vbox(28);
    responsive::watch(&side, |s, w| {
        s.set_width_request(if w <= Width::Medium { -1 } else { 360 })
    });

    // Favorite game.
    if let Some(fav) = snap.library_game(u.favorite_game.app_id) {
        let sec = ui::vbox(12);
        sec.append(&ui::section_header("Favorite Game", None));
        let overlay = gtk::Overlay::new();
        let art = Art::new(fav.images.hero.as_deref(), HERO)
            .fluid(240, 760)
            .min_height(180)
            .max_height(250)
            .fallbacks([Some(fav.images.capsule.as_str())])
            .placeholder(&fav.name);
        overlay.set_child(Some(&art));
        overlay.add_overlay(&ui::scrim("scrim-bottom"));
        let row = ui::hbox(16);
        row.add_css_class("favorite-info");
        row.set_valign(gtk::Align::End);
        let name = ui::wrap_label(&fav.name, &["hero-title", "small"], 1);
        name.set_visible(fav.images.logo.is_none());
        if let Some(url) = &fav.images.logo {
            let n = name.clone();
            let logo = Art::new(Some(url), 2.4)
                .logo(260, 90)
                .on_result(move |_, ok| n.set_visible(!ok));
            logo.set_valign(gtk::Align::End);
            responsive::watch(&logo, |l, w| {
                if w.is_compact() {
                    l.set_logo_box(130, 48);
                } else {
                    l.set_logo_box(260, 90);
                }
            });
            row.append(&logo);
        }
        row.append(&name);
        row.append(&ui::spacer());
        let facts = ui::vbox(6);
        facts.set_valign(gtk::Align::End);
        let hours = ui::label(&fav.playtime_label, &["fact-value"]);
        hours.set_xalign(1.0);
        responsive::visible_when(&hours, |w| !w.is_compact());
        facts.append(&hours);
        if let Some(a) = &fav.achievements {
            let l = ui::label(
                &format!("{} of {} achievements", a.unlocked, a.total),
                &["meta"],
            );
            l.set_xalign(1.0);
            facts.append(&l);
            let p = ui::progress(a.fraction as f64);
            responsive::watch(&p, |p, w| {
                p.set_width_request(if w.is_compact() { 110 } else { 170 })
            });
            p.set_halign(gtk::Align::End);
            facts.append(&p);
        }
        row.append(&facts);
        overlay.add_overlay(&row);
        let id = fav.app_id;
        let t = ui::tile(&overlay, move || shell::open_game(id));
        t.add_css_class("favorite-card");
        t.set_widget_name(&format!("game-{id}"));
        sec.append(&t);
        main.append(&sec);
    }

    // Recent activity.
    let recent = ui::vbox(12);
    recent.append(&ui::section_header("Recent Activity", None));
    for g in &u.recent_games {
        let h = ui::hbox(16);
        h.add_css_class("recent-row");
        let art = Art::new(Some(&g.images.header), HEADER)
            .fixed(184)
            .class("rounded");
        responsive::watch(&art, |a, w| {
            a.set_fixed_width(match w {
                Width::Compact => 120,
                Width::Medium => 150,
                _ => 184,
            })
        });
        h.append(&art);
        let t = ui::vbox(6);
        t.set_valign(gtk::Align::Center);
        t.append(&ui::fit_label(&g.name, &["row-title"]));
        t.append(&ui::fit_label(
            &format!("{}  ·  {}", g.total_label, g.last_played_label),
            &["meta"],
        ));
        if let Some(a) = &g.achievements {
            let row = ui::hbox(10);
            let progress_label = ui::label(
                &format!("Achievement progress  {} of {}", a.unlocked, a.total),
                &["meta"],
            );
            responsive::watch(&progress_label, move |l, w| {
                l.set_text(&if w <= Width::Medium {
                    format!("{} / {}", a.unlocked, a.total)
                } else {
                    format!("Achievement progress  {} of {}", a.unlocked, a.total)
                });
            });
            row.append(&progress_label);
            let p = ui::progress(a.fraction as f64);
            p.set_hexpand(true);
            row.append(&p);
            t.append(&row);
            let icons = ui::hbox(6);
            for ach in a.highlighted.iter().filter(|x| x.unlocked).take(5) {
                let i = Art::new(Some(&ach.icon_url), 1.0)
                    .fixed(28)
                    .class("achievement-icon");
                i.set_tooltip_text(Some(&ach.name));
                icons.append(&i);
            }
            responsive::visible_when(&icons, |w| w >= Width::Large);
            t.append(&icons);
        }
        h.append(&t);
        let id = g.app_id;
        let tile = ui::tile(&h, move || shell::open_game(id));
        tile.add_css_class("row-tile");
        tile.set_widget_name(&format!("game-{id}"));
        recent.append(&tile);
    }
    main.append(&recent);

    // Rare achievement showcase.
    let rare = ui::vbox(12);
    rare.append(&ui::section_header("Rare Achievement Showcase", None));
    let items: Vec<gtk::Widget> = u
        .rare_achievements
        .iter()
        .map(|r| {
            let v = ui::vbox(6);
            v.add_css_class("rare-item");
            let art = Art::new(Some(&r.achievement.icon_url), 1.0)
                .fixed(72)
                .class("achievement-icon");
            art.set_halign(gtk::Align::Center);
            v.append(&art);
            let name = ui::wrap_label(&r.achievement.name, &["rare-name"], 2);
            name.set_justify(gtk::Justification::Center);
            name.set_xalign(0.5);
            v.append(&name);
            let game = ui::fit_label(&r.app_name, &["meta"]);
            game.set_xalign(0.5);
            v.append(&game);
            v.set_tooltip_text(Some(&format!(
                "{} — {}{}",
                r.achievement.name,
                r.app_name,
                r.achievement
                    .unlocked_label
                    .as_deref()
                    .map(|l| format!("\n{l}"))
                    .unwrap_or_default()
            )));
            v.upcast()
        })
        .collect();
    let rare_grid = ui::columns(items, |w| match w {
        Width::Compact => 3,
        Width::Medium => 4,
        _ => 6,
    });
    rare_grid.add_css_class("showcase");
    rare.append(&rare_grid);
    main.append(&rare);

    // Screenshot showcase: one large + three small.
    if !u.screenshots.is_empty() {
        let sec = ui::vbox(12);
        sec.append(&ui::section_header("Screenshot Showcase", None));
        let grid = gtk::Grid::new();
        grid.set_column_homogeneous(true);
        grid.set_row_spacing(10);
        grid.set_column_spacing(10);
        for (i, s) in u.screenshots.iter().take(4).enumerate() {
            let art = Art::new(Some(&s.url), SCREENSHOT)
                .fluid(60, 760)
                .class("rounded");
            art.set_tooltip_text(Some(&s.app_name));
            if i == 0 {
                grid.attach(&art, 0, 0, 3, 1);
            } else {
                grid.attach(&art, (i - 1) as i32, 1, 1, 1);
            }
        }
        sec.append(&grid);
        main.append(&sec);
    }

    // Side: badges + friends.
    let badges = ui::vbox(12);
    badges.add_css_class("side-card");
    badges.append(&ui::section_header(
        &format!("Badges  {}", u.stats.badges),
        None,
    ));
    let medals: Vec<gtk::Widget> = u
        .badges
        .iter()
        .map(|b| {
            let v = ui::vbox(6);
            v.add_css_class("badge");
            let medal = gtk::Overlay::new();
            let disc = ui::vbox(0);
            disc.add_css_class("medal");
            disc.add_css_class(&ui::color_class(&b.color));
            disc.set_size_request(58, 58);
            disc.set_halign(gtk::Align::Center);
            disc.set_valign(gtk::Align::Start);
            let icon = ui::icon(badge_icon(&b.icon), 26);
            icon.set_halign(gtk::Align::Center);
            icon.set_valign(gtk::Align::Center);
            icon.set_margin_top(16);
            disc.append(&icon);
            medal.set_child(Some(&disc));
            medal.set_valign(gtk::Align::Start);
            let lvl = ui::label(&b.level.to_string(), &["badge-level"]);
            lvl.set_halign(gtk::Align::End);
            lvl.set_valign(gtk::Align::End);
            medal.add_overlay(&lvl);
            medal.set_halign(gtk::Align::Center);
            v.append(&medal);
            let name = ui::wrap_label(&b.name, &["badge-name"], 2);
            name.set_justify(gtk::Justification::Center);
            name.set_xalign(0.5);
            v.append(&name);
            let xp = ui::label(&format!("{} XP", group_thousands(b.xp as u64)), &["meta"]);
            xp.set_xalign(0.5);
            v.append(&xp);
            v.set_tooltip_text(Some(&b.description));
            v.upcast()
        })
        .collect();
    badges.append(&ui::columns(medals, |_| 3));
    side.append(&badges);

    let friends = ui::vbox(12);
    friends.add_css_class("side-card");
    friends.append(&ui::section_header(
        &format!("Friends  {}", snap.friends.len()),
        None,
    ));
    let faces: Vec<gtk::Widget> = snap
        .friends
        .iter()
        .take(8)
        .map(|f| {
            let v = ui::vbox(4);
            let a = ui::avatar(&f.avatar_url, 56, Some(&f.status));
            a.set_halign(gtk::Align::Center);
            v.append(&a);
            let n = ui::fit_label(&f.persona_name, &["face-name", ui::status_class(&f.status)]);
            n.set_xalign(0.5);
            v.append(&n);
            v.set_tooltip_text(Some(&f.status_label));
            v.upcast()
        })
        .collect();
    friends.append(&ui::columns(faces, |_| 4));
    let all = gtk::Button::with_label("View all friends");
    all.add_css_class("secondary-button");
    all.connect_clicked(|_| shell::open_friends());
    friends.append(&all);
    side.append(&friends);

    let cols = ui::column_layout_stacked_when(vec![main.upcast(), side.upcast()], 32, |w| {
        w <= Width::Medium
    });
    body.append(&cols);

    let clamp = adw::Clamp::builder()
        .unit(adw::LengthUnit::Px)
        .maximum_size(1280)
        .tightening_threshold(1280)
        .child(&body)
        .build();
    content.append(&clamp);

    let page = adw::NavigationPage::builder()
        .title(&u.persona_name)
        .tag("root")
        .child(&ui::page_scroller(&content))
        .build();
    page.add_css_class("bg-library");
    page.add_css_class("detail");
    page
}
