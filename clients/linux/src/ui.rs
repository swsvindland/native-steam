//! Shared building blocks: labels, section headers, shelves, price blocks,
//! chips, avatars and the activatable `tile` button used for every card.

use crate::art::Art;
use crate::responsive::{self, Width};
use gtk::prelude::*;
use gtk::{glib, pango};
use std::cell::RefCell;
use std::collections::HashSet;
use steam_model::{Platforms, Price, ReviewSummary};

// ---------------------------------------------------------------------------
// Labels
// ---------------------------------------------------------------------------

pub fn label(text: &str, classes: &[&str]) -> gtk::Label {
    let l = gtk::Label::new(Some(text));
    l.set_xalign(0.0);
    for c in classes {
        l.add_css_class(c);
    }
    l
}

/// Single-line label that ellipsizes instead of widening its container.
pub fn fit_label(text: &str, classes: &[&str]) -> gtk::Label {
    let l = label(text, classes);
    l.set_ellipsize(pango::EllipsizeMode::End);
    l.set_max_width_chars(1);
    l.set_hexpand(true);
    l
}

/// Wrapping label clamped to `lines` lines (0 = unlimited).
pub fn wrap_label(text: &str, classes: &[&str], lines: i32) -> gtk::Label {
    let l = label(text, classes);
    l.set_wrap(true);
    l.set_wrap_mode(pango::WrapMode::WordChar);
    if lines > 0 {
        l.set_lines(lines);
        l.set_ellipsize(pango::EllipsizeMode::End);
    }
    l.set_max_width_chars(1);
    l.set_hexpand(true);
    l
}

pub fn markup_label(markup: &str, classes: &[&str]) -> gtk::Label {
    let l = label("", classes);
    l.set_markup(markup);
    l
}

pub fn esc(s: &str) -> glib::GString {
    glib::markup_escape_text(s)
}

pub fn icon(name: &str, px: i32) -> gtk::Image {
    let i = gtk::Image::from_icon_name(name);
    i.set_pixel_size(px);
    i
}

pub fn vbox(spacing: i32) -> gtk::Box {
    gtk::Box::new(gtk::Orientation::Vertical, spacing)
}

pub fn hbox(spacing: i32) -> gtk::Box {
    gtk::Box::new(gtk::Orientation::Horizontal, spacing)
}

pub fn spacer() -> gtk::Box {
    let b = hbox(0);
    b.set_hexpand(true);
    b
}

// ---------------------------------------------------------------------------
// Scrolling
// ---------------------------------------------------------------------------

/// A viewport that leaves scroll-to-focus to `input::scroll_focus_into_view`,
/// which animates and keeps a card of lookahead.
pub fn viewport(child: &impl IsA<gtk::Widget>) -> gtk::Viewport {
    let vp = gtk::Viewport::new(None::<&gtk::Adjustment>, None::<&gtk::Adjustment>);
    vp.set_scroll_to_focus(false);
    vp.set_child(Some(child));
    vp
}

/// Vertical page scroller.
pub fn page_scroller(child: &impl IsA<gtk::Widget>) -> gtk::ScrolledWindow {
    let sw = gtk::ScrolledWindow::new();
    sw.set_hscrollbar_policy(gtk::PolicyType::Never);
    sw.set_child(Some(&viewport(child)));
    sw.set_vexpand(true);
    sw.add_css_class("page-scroller");
    sw
}

/// Horizontal shelf of cards that scrolls (and swipes) sideways. Cards line up
/// with the page gutter but scroll out to the edge of the content area.
pub fn shelf<W: IsA<gtk::Widget>>(cards: impl IntoIterator<Item = W>) -> gtk::ScrolledWindow {
    let row = hbox(16);
    row.add_css_class("shelf-row");
    for c in cards {
        c.set_valign(gtk::Align::Start);
        row.append(&c);
    }
    responsive::watch(&row, |row, w| {
        row.set_margin_start(w.gutter());
        row.set_margin_end(w.gutter());
        row.set_spacing(if w.is_compact() { 12 } else { 16 });
    });
    let sw = gtk::ScrolledWindow::new();
    sw.set_vscrollbar_policy(gtk::PolicyType::Never);
    sw.set_hscrollbar_policy(gtk::PolicyType::Automatic);
    sw.set_child(Some(&viewport(&row)));
    sw.add_css_class("shelf");
    sw
}

/// Lays `items` out in a grid whose column count follows the width class.
pub fn columns(items: Vec<gtk::Widget>, cols: impl Fn(Width) -> usize + 'static) -> gtk::Grid {
    let grid = gtk::Grid::new();
    grid.set_column_homogeneous(true);
    grid.set_column_spacing(16);
    grid.set_row_spacing(8);
    grid.set_valign(gtk::Align::Start);
    responsive::watch(&grid, move |grid, w| {
        let n = cols(w).max(1);
        for item in &items {
            if item.parent().is_some() {
                grid.remove(item);
            }
        }
        for (i, item) in items.iter().enumerate() {
            grid.attach(item, (i % n) as i32, (i / n) as i32, 1, 1);
        }
    });
    grid
}

/// Side-by-side columns on regular widths, stacked on compact.
///
/// Built on `GtkGrid` rather than a horizontal `GtkBox`: since GTK 4.20 the box
/// layout binary-searches the minimum height assuming children get shorter as
/// they get wider, which isn't true for columns holding fluid artwork.
pub fn column_layout(cols: Vec<gtk::Widget>, spacing: i32) -> gtk::Grid {
    column_layout_stacked_when(cols, spacing, Width::is_compact)
}

/// Like [`column_layout`], stacking whenever `stacked(width)` holds.
pub fn column_layout_stacked_when(
    cols: Vec<gtk::Widget>,
    spacing: i32,
    stacked: impl Fn(Width) -> bool + 'static,
) -> gtk::Grid {
    let grid = gtk::Grid::new();
    responsive::watch(&grid, move |grid, w| {
        let compact = stacked(w);
        grid.set_column_spacing(spacing as u32);
        grid.set_row_spacing(if compact { spacing as u32 } else { 0 });
        for c in &cols {
            if c.parent().is_some() {
                grid.remove(c);
            }
        }
        for (i, c) in cols.iter().enumerate() {
            if compact {
                grid.attach(c, 0, i as i32, 1, 1);
            } else {
                grid.attach(c, i as i32, 0, 1, 1);
            }
        }
    });
    grid
}

// ---------------------------------------------------------------------------
// Sections
// ---------------------------------------------------------------------------

/// UPPERCASE tracked section title with an optional trailing "See all ›".
pub fn section_header(title: &str, trailing: Option<&str>) -> gtk::Box {
    let b = hbox(8);
    b.add_css_class("section-header");
    b.append(&label(&title.to_uppercase(), &["section-title"]));
    b.append(&spacer());
    if let Some(t) = trailing {
        let btn = gtk::Button::with_label(&format!("{t}  ›"));
        btn.add_css_class("see-all");
        btn.add_css_class("flat");
        // Mouse/touch convenience only; keeps gamepad focus on content.
        btn.set_focusable(false);
        b.append(&btn);
    }
    b
}

/// Section header with the page gutter applied.
pub fn section(title: &str, trailing: Option<&str>) -> gtk::Box {
    let h = section_header(title, trailing);
    responsive::gutter(&h);
    h
}

// ---------------------------------------------------------------------------
// Activatable tiles
// ---------------------------------------------------------------------------

/// The one activatable card primitive: a flat button that clips its artwork,
/// lifts on hover and gets the focus ring + scale from CSS.
pub fn tile(child: &impl IsA<gtk::Widget>, on_activate: impl Fn() + 'static) -> gtk::Button {
    let b = gtk::Button::new();
    b.set_child(Some(child));
    b.add_css_class("tile");
    b.set_overflow(gtk::Overflow::Hidden);
    b.connect_clicked(move |_| on_activate());
    b
}

pub fn chip(text: &str) -> gtk::Button {
    let b = gtk::Button::with_label(text);
    b.add_css_class("chip");
    b
}

pub fn pill(text: &str, classes: &[&str]) -> gtk::Label {
    let l = label(text, &["pill"]);
    for c in classes {
        l.add_css_class(c);
    }
    l
}

// ---------------------------------------------------------------------------
// Price block (DESIGN.md §4.1) — reused everywhere
// ---------------------------------------------------------------------------

pub fn price_block(price: Option<&Price>, large: bool) -> gtk::Box {
    let b = hbox(0);
    b.add_css_class("price-block");
    if large {
        b.add_css_class("large");
    }
    b.set_valign(gtk::Align::Center);
    b.set_halign(gtk::Align::End);
    match price {
        Some(p) => match p.discount_label.as_deref() {
            Some(discount) => {
                b.append(&label(discount, &["discount-badge"]));
                let stack = vbox(0);
                stack.add_css_class("price-stack");
                stack.set_valign(gtk::Align::Center);
                let orig = markup_label(
                    &format!("<s>{}</s>", esc(&p.initial_label)),
                    &["price-original"],
                );
                orig.set_xalign(1.0);
                let fin = label(&p.final_label, &["price-final", "discounted"]);
                fin.set_xalign(1.0);
                stack.append(&orig);
                stack.append(&fin);
                b.append(&stack);
            }
            None => {
                let l = label(&p.final_label, &["price-final", "price-plain"]);
                if p.is_free {
                    l.add_css_class("free");
                }
                b.append(&l);
            }
        },
        None => b.append(&label(
            "Coming soon",
            &["price-final", "price-plain", "soon"],
        )),
    }
    b
}

// ---------------------------------------------------------------------------
// Small glyphs
// ---------------------------------------------------------------------------

pub fn platform_icons(p: &Platforms) -> gtk::Box {
    let b = hbox(6);
    b.add_css_class("platforms");
    b.set_valign(gtk::Align::Center);
    for (on, icon_name, tip) in [
        (p.windows, "ns-windows-symbolic", "Windows"),
        (p.mac, "ns-mac-symbolic", "macOS"),
        (p.linux, "ns-linux-symbolic", "Linux / SteamOS"),
    ] {
        if on {
            let i = icon(icon_name, 14);
            i.set_tooltip_text(Some(tip));
            b.append(&i);
        }
    }
    b
}

pub fn tone_class(tone: &str) -> &'static str {
    match tone {
        "positive" => "tone-positive",
        "negative" => "tone-negative",
        _ => "tone-mixed",
    }
}

pub fn tone_dot(review: Option<&ReviewSummary>) -> gtk::Box {
    let d = hbox(0);
    d.add_css_class("tone-dot");
    d.set_valign(gtk::Align::Center);
    match review {
        Some(r) => {
            d.add_css_class(tone_class(&r.tone));
            d.set_tooltip_text(Some(&format!("{} · {}", r.label, r.total_label)));
        }
        None => d.add_css_class("tone-none"),
    }
    d
}

pub fn live_dot() -> gtk::Box {
    let d = hbox(0);
    d.add_css_class("live-dot");
    d.set_valign(gtk::Align::Center);
    d
}

pub fn progress(fraction: f64) -> gtk::ProgressBar {
    let p = gtk::ProgressBar::new();
    p.set_fraction(fraction.clamp(0.0, 1.0));
    p.add_css_class("thin");
    p.set_valign(gtk::Align::Center);
    p
}

pub fn status_class(status: &str) -> &'static str {
    match status {
        "inGame" => "status-ingame",
        "online" => "status-online",
        "away" => "status-away",
        _ => "status-offline",
    }
}

pub fn status_hex(status: &str) -> &'static str {
    match status {
        "inGame" => "#90ba3c",
        "online" => "#57cbde",
        "away" => "#3f8d9b",
        _ => "#898989",
    }
}

/// Square Steam avatar (4 px radius) with a status-coloured border.
pub fn avatar(url: &str, size: i32, status: Option<&str>) -> Art {
    let a = Art::new(Some(url), 1.0).fixed(size).class("avatar");
    a.set_halign(gtk::Align::Start);
    a.set_valign(gtk::Align::Center);
    if let Some(s) = status {
        a.add_css_class(status_class(s));
    }
    a
}

/// A dark gradient laid over artwork so text stays legible.
pub fn scrim(class: &str) -> gtk::Box {
    let b = vbox(0);
    b.add_css_class("scrim");
    b.add_css_class(class);
    b.set_can_target(false);
    b
}

// ---------------------------------------------------------------------------
// Data-driven colours (level rings, badges)
// ---------------------------------------------------------------------------

thread_local! {
    static COLORS: RefCell<(HashSet<String>, Option<gtk::CssProvider>)> =
        RefCell::new((HashSet::new(), None));
}

/// Returns a CSS class that sets `--ring`/`--fill` style colours for `hex`.
/// Generates `.c-xxxxxx.ring`, `.c-xxxxxx.fill`, `.c-xxxxxx.text` rules on demand.
pub fn color_class(hex: &str) -> String {
    let clean: String = hex
        .trim_start_matches('#')
        .chars()
        .filter(|c| c.is_ascii_hexdigit())
        .take(6)
        .collect::<String>()
        .to_lowercase();
    let clean = if clean.len() == 6 {
        clean
    } else {
        "8f98a0".to_owned()
    };
    let class = format!("c-{clean}");
    COLORS.with(|c| {
        let mut c = c.borrow_mut();
        if c.0.insert(clean.clone()) {
            let mut css = String::new();
            let mut all: Vec<_> = c.0.iter().cloned().collect();
            all.sort();
            for h in all {
                css.push_str(&format!(
                    ".c-{h}.ring {{ border-color: #{h}; }}\n\
                     .c-{h}.fill {{ background-color: #{h}; }}\n\
                     .c-{h}.medal {{ background-image: radial-gradient(circle at 35% 30%, shade(#{h}, 1.35), #{h} 55%, shade(#{h}, 0.6)); }}\n\
                     .c-{h}.text {{ color: #{h}; }}\n"
                ));
            }
            let provider = c.1.get_or_insert_with(|| {
                let p = gtk::CssProvider::new();
                if let Some(display) = gtk::gdk::Display::default() {
                    gtk::style_context_add_provider_for_display(
                        &display,
                        &p,
                        gtk::STYLE_PROVIDER_PRIORITY_APPLICATION + 1,
                    );
                }
                p
            });
            provider.load_from_string(&css);
        }
    });
    class
}
