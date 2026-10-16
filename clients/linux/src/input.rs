//! Input model (DESIGN.md §3): mouse & keyboard, touch and gamepad are all
//! first-class. We track the last-used input and adapt:
//!
//! * **Gamepad** (via `gilrs`, polled every 16 ms on the GLib main loop):
//!   D-pad / left stick move focus spatially, A activates, B goes back,
//!   LB/RB switch tabs, Y focuses search, X is the secondary action, LT/RT page
//!   between collections/sections. The Big-Picture-style hints bar is revealed
//!   and the focus ring is always visible.
//! * **Keyboard**: arrow keys use the same spatial navigation, Esc/Backspace
//!   go back; GTK's own focus-visible handling decides when to draw rings.
//! * **Touch**: focus rings are hidden; GTK gestures handle swipes and taps.
//!
//! Spatial navigation picks the nearest focusable widget in the requested
//! direction using window-space bounds, so it works across nested scrollers
//! (shelves inside pages), carousels and the header. Focused items are scrolled
//! into view with an animation and about one card of lookahead.

use crate::responsive;
use crate::shell::{self, Tab};
use crate::ui;
use adw::prelude::*;
use gtk::{gdk, glib, graphene};
use std::cell::{Cell, RefCell};
use std::collections::HashMap;
use std::time::{Duration, Instant};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Mode {
    Mouse,
    Keyboard,
    Touch,
    Gamepad,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Dir {
    Up,
    Down,
    Left,
    Right,
}

/// A gamepad press, used by the poller and by `--nav` scripting.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum PadAction {
    Move(Dir),
    A,
    B,
    X,
    Y,
    Lb,
    Rb,
    Lt,
    Rt,
}

impl PadAction {
    pub fn parse(s: &str) -> Option<PadAction> {
        Some(match s.to_ascii_lowercase().as_str() {
            "u" | "up" => PadAction::Move(Dir::Up),
            "d" | "down" => PadAction::Move(Dir::Down),
            "l" | "left" => PadAction::Move(Dir::Left),
            "r" | "right" => PadAction::Move(Dir::Right),
            "a" => PadAction::A,
            "b" => PadAction::B,
            "x" => PadAction::X,
            "y" => PadAction::Y,
            "lb" => PadAction::Lb,
            "rb" => PadAction::Rb,
            "lt" => PadAction::Lt,
            "rt" => PadAction::Rt,
            _ => return None,
        })
    }
}

/// Performs a gamepad action (switches to gamepad mode first).
pub fn perform(action: PadAction) {
    set_mode(Mode::Gamepad);
    let sh = shell::try_get();
    match action {
        PadAction::Move(dir) => {
            move_focus(dir);
        }
        PadAction::A => activate_focus(),
        PadAction::B => back(),
        PadAction::X => secondary(),
        PadAction::Y => {
            if let Some(sh) = sh {
                sh.focus_search();
            }
        }
        PadAction::Lb => {
            if let Some(sh) = sh {
                sh.cycle_tab(-1);
            }
        }
        PadAction::Rb => {
            if let Some(sh) = sh {
                sh.cycle_tab(1);
            }
        }
        PadAction::Lt => page_sections(-1),
        PadAction::Rt => page_sections(1),
    }
}

thread_local! {
    static MODE: Cell<Mode> = const { Cell::new(Mode::Mouse) };
    static PAD_CONNECTED: Cell<bool> = const { Cell::new(false) };
    static PAD_LABEL: RefCell<Option<gtk::Label>> = const { RefCell::new(None) };
    static LAST_FOCUS: RefCell<HashMap<Tab, glib::WeakRef<gtk::Widget>>> = RefCell::new(HashMap::new());
    static SCROLL_ANIMS: RefCell<Vec<(glib::WeakRef<gtk::Adjustment>, adw::TimedAnimation)>> =
        const { RefCell::new(Vec::new()) };
}

pub fn mode() -> Mode {
    MODE.with(Cell::get)
}

pub fn set_mode(mode: Mode) {
    if MODE.with(|m| m.replace(mode)) == mode {
        return;
    }
    let Some(sh) = shell::try_get() else { return };
    let gamepad = mode == Mode::Gamepad;
    sh.hints.set_reveal_child(gamepad);
    sh.set_bumpers_visible(gamepad || PAD_CONNECTED.with(Cell::get));
    let w = &sh.window;
    if gamepad {
        w.add_css_class("gamepad");
        w.set_focus_visible(true);
    } else {
        w.remove_css_class("gamepad");
    }
    if mode == Mode::Touch {
        w.add_css_class("touch");
        w.set_focus_visible(false);
    } else {
        w.remove_css_class("touch");
    }
}

// ---------------------------------------------------------------------------
// Hints bar
// ---------------------------------------------------------------------------

fn glyph(text: &str, class: &str) -> gtk::Label {
    let l = ui::label(text, &["pad-glyph", class]);
    l.set_xalign(0.5);
    l.set_valign(gtk::Align::Center);
    l
}

fn hint(glyphs: &[(&str, &str)], action: &str) -> gtk::Box {
    let b = ui::hbox(8);
    b.add_css_class("hint");
    for (g, c) in glyphs {
        b.append(&glyph(g, c));
    }
    b.append(&ui::label(action, &["hint-label"]));
    b
}

/// Big-Picture-style button hints, revealed while the gamepad is in use.
pub fn hints_bar() -> gtk::Revealer {
    let bar = ui::hbox(28);
    bar.add_css_class("hints-bar");
    let device = ui::hbox(8);
    device.append(&ui::icon("ns-controller-symbolic", 18));
    let name = ui::label("Controller", &["hint-device"]);
    device.append(&name);
    PAD_LABEL.with(|l| *l.borrow_mut() = Some(name));
    bar.append(&device);
    bar.append(&ui::spacer());
    bar.append(&hint(&[("A", "a")], "Select"));
    bar.append(&hint(&[("B", "b")], "Back"));
    bar.append(&hint(&[("Y", "y")], "Search"));
    let tabs = hint(&[("LB", "bumper"), ("RB", "bumper")], "Switch tab");
    bar.append(&tabs);
    responsive::watch(&bar, move |bar, w| {
        let compact = w.is_compact();
        bar.set_spacing(if compact { 8 } else { 28 });
        if let Some(device) = bar.first_child() {
            device.set_visible(!compact);
        }
        // Keep the bar within a phone-width window: "LB RB" alone reads fine.
        if let Some(label) = tabs.last_child() {
            label.set_visible(!compact);
        }
    });

    let r = gtk::Revealer::new();
    r.set_transition_type(gtk::RevealerTransitionType::SlideUp);
    r.set_transition_duration(180);
    r.set_child(Some(&bar));
    r.set_reveal_child(false);
    r
}

// ---------------------------------------------------------------------------
// Spatial navigation
// ---------------------------------------------------------------------------

fn is_container(w: &gtk::Widget) -> bool {
    w.is::<gtk::ScrolledWindow>()
        || w.is::<gtk::Viewport>()
        || w.is::<gtk::FlowBox>()
        || w.is::<gtk::FlowBoxChild>()
        || w.is::<gtk::ListBox>()
        || w.is::<gtk::Window>()
        || w.is::<gtk::Popover>()
        || w.is::<gtk::Text>()
        || w.is::<adw::Carousel>()
}

fn is_target(w: &gtk::Widget) -> bool {
    if w.is::<gtk::SearchEntry>() || w.is::<gtk::Entry>() {
        return w.can_focus();
    }
    w.is_focusable() && w.can_focus() && !is_container(w)
}

fn collect(w: &gtk::Widget, out: &mut Vec<gtk::Widget>) {
    let mut child = w.first_child();
    while let Some(c) = child {
        if c.is_visible() && c.is_mapped() && c.is_sensitive() {
            if is_target(&c) {
                out.push(c.clone());
            } else {
                collect(&c, out);
            }
        }
        child = c.next_sibling();
    }
}

fn ancestor<T: IsA<gtk::Widget>>(w: &gtk::Widget) -> Option<T> {
    let mut p = Some(w.clone());
    while let Some(x) = p {
        if let Ok(t) = x.clone().downcast::<T>() {
            return Some(t);
        }
        p = x.parent();
    }
    None
}

/// The navigable widget that owns the focus (e.g. the SearchEntry for its GtkText).
fn current_target(window: &gtk::Window) -> Option<gtk::Widget> {
    let f = gtk::prelude::GtkWindowExt::focus(window)?;
    if let Some(e) = ancestor::<gtk::SearchEntry>(&f) {
        return Some(e.upcast());
    }
    let mut p = Some(f);
    while let Some(w) = p {
        if is_target(&w) {
            return Some(w);
        }
        p = w.parent();
    }
    None
}

struct R {
    l: f32,
    t: f32,
    r: f32,
    b: f32,
}

impl R {
    fn of(w: &gtk::Widget, root: &impl IsA<gtk::Widget>) -> Option<R> {
        let b: graphene::Rect = w.compute_bounds(root)?;
        Some(R {
            l: b.x(),
            t: b.y(),
            r: b.x() + b.width(),
            b: b.y() + b.height(),
        })
    }
    fn cx(&self) -> f32 {
        (self.l + self.r) / 2.0
    }
    fn cy(&self) -> f32 {
        (self.t + self.b) / 2.0
    }
    fn w(&self) -> f32 {
        self.r - self.l
    }
    fn h(&self) -> f32 {
        self.b - self.t
    }
}

fn gap(a0: f32, a1: f32, b0: f32, b1: f32) -> f32 {
    if b1 < a0 {
        a0 - b1
    } else if b0 > a1 {
        b0 - a1
    } else {
        0.0
    }
}

fn score(dir: Dir, cur: &R, c: &R) -> Option<f32> {
    let tol_y = 0.3 * cur.h().min(c.h()).min(40.0);
    let tol_x = 0.3 * cur.w().min(c.w()).min(40.0);
    match dir {
        Dir::Down if c.cy() > cur.cy() + 1.0 && c.t >= cur.b - tol_y => {
            let primary = (c.t - cur.b).max(0.0);
            let ortho = gap(cur.l, cur.r, c.l, c.r);
            Some(primary + ortho * 2.5 + (c.cx() - cur.cx()).abs() * 0.08)
        }
        Dir::Up if c.cy() < cur.cy() - 1.0 && c.b <= cur.t + tol_y => {
            let primary = (cur.t - c.b).max(0.0);
            let ortho = gap(cur.l, cur.r, c.l, c.r);
            Some(primary + ortho * 2.5 + (c.cx() - cur.cx()).abs() * 0.08)
        }
        Dir::Right if c.cx() > cur.cx() + 1.0 && c.l >= cur.r - tol_x => {
            let primary = (c.l - cur.r).max(0.0);
            let ortho = gap(cur.t, cur.b, c.t, c.b);
            Some(primary + ortho * 4.0 + (c.cy() - cur.cy()).abs() * 0.08)
        }
        Dir::Left if c.cx() < cur.cx() - 1.0 && c.r <= cur.l + tol_x => {
            let primary = (cur.l - c.r).max(0.0);
            let ortho = gap(cur.t, cur.b, c.t, c.b);
            Some(primary + ortho * 4.0 + (c.cy() - cur.cy()).abs() * 0.08)
        }
        _ => None,
    }
}

/// Moves focus to the nearest focusable widget in `dir`. Returns false if
/// there's nothing in that direction.
pub fn move_focus(dir: Dir) -> bool {
    let Some(sh) = shell::try_get() else {
        return false;
    };
    let window: gtk::Window = sh.window.clone().upcast();

    // Inside popovers (menus, dropdowns) defer to GTK's own focus chain.
    if let Some(f) = gtk::prelude::GtkWindowExt::focus(&window) {
        if let Some(pop) = ancestor::<gtk::Popover>(&f) {
            let gdir = match dir {
                Dir::Up => gtk::DirectionType::Up,
                Dir::Down => gtk::DirectionType::Down,
                Dir::Left => gtk::DirectionType::Left,
                Dir::Right => gtk::DirectionType::Right,
            };
            return pop.child_focus(gdir);
        }
    }

    let Some(cur) = current_target(&window) else {
        return focus_first_item();
    };
    let Some(cur_r) = R::of(&cur, &window) else {
        return focus_first_item();
    };
    let mut targets = Vec::new();
    collect(window.upcast_ref(), &mut targets);
    let best = targets
        .iter()
        .filter(|t| **t != cur)
        .filter_map(|t| {
            let r = R::of(t, &window)?;
            score(dir, &cur_r, &r).map(|s| (s, t))
        })
        .min_by(|a, b| a.0.total_cmp(&b.0))
        .map(|(_, t)| t.clone());
    match best {
        Some(t) => {
            t.grab_focus();
            true
        }
        None => false,
    }
}

/// Focuses the first card of the current tab's visible page.
pub fn focus_first_item() -> bool {
    let Some(sh) = shell::try_get() else {
        return false;
    };
    let Some(page) = sh.current_nav().visible_page() else {
        return false;
    };
    let mut targets = Vec::new();
    collect(page.upcast_ref(), &mut targets);
    let pick = targets
        .iter()
        .find(|t| t.has_css_class("tile") || t.has_css_class("primary-action"))
        .or(targets.first())
        .cloned();
    match pick {
        Some(t) => {
            t.grab_focus();
            scroll_focus_into_view(&t);
            true
        }
        None => false,
    }
}

pub fn on_tab_changed(tab: Tab) {
    if !matches!(mode(), Mode::Gamepad | Mode::Keyboard) {
        return;
    }
    let remembered = LAST_FOCUS.with(|l| l.borrow().get(&tab).and_then(|w| w.upgrade()));
    // Wait a frame so the new page is mapped before we look for targets.
    glib::idle_add_local_once(move || {
        if let Some(w) = remembered.filter(|w| w.is_mapped()) {
            w.grab_focus();
        } else {
            focus_first_item();
        }
    });
}

// ---------------------------------------------------------------------------
// Keep the focused item visible
// ---------------------------------------------------------------------------

fn animate_to(adj: &gtk::Adjustment, target: f64, widget: &gtk::Widget) {
    let target = target.clamp(
        adj.lower(),
        (adj.upper() - adj.page_size()).max(adj.lower()),
    );
    let from = adj.value();
    if (from - target).abs() < 1.0 {
        return;
    }
    SCROLL_ANIMS.with(|a| {
        a.borrow_mut().retain(|(w, anim)| match w.upgrade() {
            Some(x) if x == *adj => {
                anim.pause();
                false
            }
            Some(_) => anim.state() != adw::AnimationState::Finished,
            None => false,
        })
    });
    let a = adj.clone();
    let cb = adw::CallbackAnimationTarget::new(move |v| a.set_value(v));
    let anim = adw::TimedAnimation::new(widget, from, target, 240, cb);
    anim.set_easing(adw::Easing::EaseOutCubic);
    anim.play();
    SCROLL_ANIMS.with(|s| s.borrow_mut().push((adj.downgrade(), anim)));
}

/// Scrolls every scrolling ancestor so `w` is visible, with lookahead:
/// horizontal shelves keep ~1 card visible past the focused one, pages keep the
/// section header above the focused row in view. Carousels page to it.
pub fn scroll_focus_into_view(w: &gtk::Widget) {
    let mut child = w.clone();
    let mut parent = w.parent();
    while let Some(p) = parent {
        if let Some(carousel) = p.downcast_ref::<adw::Carousel>() {
            carousel.scroll_to(&child, true);
        }
        if let Some(sw) = p.downcast_ref::<gtk::ScrolledWindow>() {
            let content = sw
                .child()
                .and_then(|c| c.downcast::<gtk::Viewport>().ok())
                .and_then(|vp| vp.child());
            if let Some(content) = content {
                if let Some(r) = R::of(w, &content) {
                    let horizontal = sw.vscrollbar_policy() == gtk::PolicyType::Never;
                    if horizontal {
                        let adj = sw.hadjustment();
                        let page = adj.page_size() as f32;
                        let look = (r.w() + 16.0).min(((page - r.w()) / 2.0).max(0.0));
                        let (a, b) = (r.l - look, r.r + look);
                        let v = adj.value() as f32;
                        if a < v {
                            animate_to(&adj, a as f64, &p);
                        } else if b > v + page {
                            animate_to(&adj, (b - page) as f64, &p);
                        }
                    } else {
                        let adj = sw.vadjustment();
                        let page = adj.page_size() as f32;
                        let top_look = 64.0_f32.min(((page - r.h()) / 2.0).max(0.0));
                        let bottom_look = 40.0_f32.min(((page - r.h()) / 2.0).max(0.0));
                        let (a, b) = (r.t - top_look, r.b + bottom_look);
                        let v = adj.value() as f32;
                        if a < v {
                            animate_to(&adj, a as f64, &p);
                        } else if b > v + page {
                            animate_to(&adj, (b - page) as f64, &p);
                        }
                    }
                }
            }
        }
        child = p.clone();
        parent = p.parent();
    }
}

// ---------------------------------------------------------------------------
// Actions shared by keyboard and gamepad
// ---------------------------------------------------------------------------

fn activate_focus() {
    let Some(sh) = shell::try_get() else { return };
    match gtk::prelude::GtkWindowExt::focus(&sh.window) {
        Some(f) if !f.is::<gtk::Text>() => {
            f.activate();
        }
        Some(_) => {}
        None => {
            focus_first_item();
        }
    }
}

fn back() {
    let Some(sh) = shell::try_get() else { return };
    if let Some(f) = gtk::prelude::GtkWindowExt::focus(&sh.window) {
        if let Some(pop) = ancestor::<gtk::Popover>(&f) {
            pop.popdown();
            return;
        }
        if f.is::<gtk::Text>() {
            // Leave the search field and return to content.
            focus_first_item();
            return;
        }
    }
    if !sh.pop() {
        sh.focus_tab_bar();
    }
}

/// X: favorite in Library, wishlist in Store (purely visual).
fn secondary() {
    let Some(sh) = shell::try_get() else { return };
    let Some(f) = gtk::prelude::GtkWindowExt::focus(&sh.window) else {
        return;
    };
    let name = f.widget_name();
    if let Some(id) = name
        .strip_prefix("game-")
        .and_then(|s| s.parse::<u32>().ok())
    {
        crate::library::toggle_favorite(id);
    } else if let Some(id) = name
        .strip_prefix("store-")
        .and_then(|s| s.parse::<u32>().ok())
    {
        let game = crate::store::find_item(id)
            .map(|i| i.name.as_str())
            .unwrap_or("Game");
        sh.toast(&format!("{game} added to your wishlist"));
    }
}

/// LT / RT: page between Library collections / Community sections.
fn page_sections(delta: i32) {
    let Some(sh) = shell::try_get() else { return };
    match sh.current_tab() {
        Tab::Library => crate::library::cycle_collection(delta),
        Tab::Community => crate::community::cycle_section(delta),
        _ => {}
    }
}

// ---------------------------------------------------------------------------
// Installation: event controllers + gamepad polling
// ---------------------------------------------------------------------------

pub fn install(window: &adw::ApplicationWindow) {
    // Track the last-used input device.
    let legacy = gtk::EventControllerLegacy::new();
    legacy.set_propagation_phase(gtk::PropagationPhase::Capture);
    legacy.connect_event(|_, ev| {
        match ev.event_type() {
            gdk::EventType::ButtonPress => {
                let touch = ev
                    .device()
                    .is_some_and(|d| d.source() == gdk::InputSource::Touchscreen);
                set_mode(if touch { Mode::Touch } else { Mode::Mouse });
            }
            gdk::EventType::TouchBegin => set_mode(Mode::Touch),
            gdk::EventType::Scroll if mode() == Mode::Gamepad => set_mode(Mode::Mouse),
            gdk::EventType::KeyPress => {
                let modifier_only = ev
                    .downcast_ref::<gdk::KeyEvent>()
                    .is_some_and(|k| k.is_modifier());
                if !modifier_only {
                    set_mode(Mode::Keyboard);
                }
            }
            _ => {}
        }
        glib::Propagation::Proceed
    });
    window.add_controller(legacy);

    // Arrow keys = spatial navigation; Esc / Backspace = back.
    let keys = gtk::EventControllerKey::new();
    keys.set_propagation_phase(gtk::PropagationPhase::Capture);
    let win = window.clone();
    keys.connect_key_pressed(move |_, key, _, state| {
        use gdk::Key;
        let mods = state
            & (gdk::ModifierType::CONTROL_MASK
                | gdk::ModifierType::ALT_MASK
                | gdk::ModifierType::SHIFT_MASK
                | gdk::ModifierType::SUPER_MASK
                | gdk::ModifierType::META_MASK);
        if !mods.is_empty() {
            return glib::Propagation::Proceed;
        }
        let focus = gtk::prelude::GtkWindowExt::focus(&win);
        let in_text = focus.as_ref().is_some_and(|f| f.is::<gtk::Text>());
        let in_popover = focus
            .as_ref()
            .is_some_and(|f| ancestor::<gtk::Popover>(f).is_some());
        if in_popover {
            return glib::Propagation::Proceed;
        }
        let dir = match key {
            Key::Up | Key::KP_Up => Some(Dir::Up),
            Key::Down | Key::KP_Down => Some(Dir::Down),
            Key::Left | Key::KP_Left if !in_text => Some(Dir::Left),
            Key::Right | Key::KP_Right if !in_text => Some(Dir::Right),
            _ => None,
        };
        if let Some(dir) = dir {
            return if move_focus(dir) {
                glib::Propagation::Stop
            } else {
                glib::Propagation::Proceed
            };
        }
        match key {
            Key::Escape if in_text => {
                let empty = focus
                    .as_ref()
                    .and_then(ancestor::<gtk::SearchEntry>)
                    .is_none_or(|e| e.text().is_empty());
                if empty {
                    focus_first_item();
                    return glib::Propagation::Stop;
                }
                glib::Propagation::Proceed
            }
            Key::Escape | Key::BackSpace if !in_text => {
                if shell::get().pop() {
                    glib::Propagation::Stop
                } else {
                    glib::Propagation::Proceed
                }
            }
            _ => glib::Propagation::Proceed,
        }
    });
    window.add_controller(keys);

    // Keep keyboard/gamepad focus visible; remember it per tab.
    window.connect_focus_widget_notify(|w| {
        let Some(f) = gtk::prelude::GtkWindowExt::focus(w) else {
            return;
        };
        if let Some(sh) = shell::try_get() {
            let tab = sh.current_tab();
            LAST_FOCUS.with(|l| l.borrow_mut().insert(tab, f.downgrade()));
        }
        if matches!(mode(), Mode::Keyboard | Mode::Gamepad) {
            let target = ancestor::<gtk::SearchEntry>(&f)
                .map(|e| e.upcast::<gtk::Widget>())
                .unwrap_or(f);
            scroll_focus_into_view(&target);
        }
    });

    start_gamepad();
}

struct Pad {
    gilrs: gilrs::Gilrs,
    held: Option<(Dir, Instant)>,
    stick: Option<Dir>,
}

const REPEAT_DELAY: Duration = Duration::from_millis(380);
const REPEAT_RATE: Duration = Duration::from_millis(90);

fn start_gamepad() {
    let gilrs = match gilrs::Gilrs::new() {
        Ok(g) => g,
        Err(gilrs::Error::NotImplemented(g)) => g,
        Err(e) => {
            eprintln!("native-steam: gamepad support unavailable ({e})");
            return;
        }
    };
    let connected = gilrs.gamepads().next().map(|(_, g)| g.name().to_owned());
    if let Some(name) = connected {
        on_pad_connected(Some(&name));
    }
    let pad = RefCell::new(Pad {
        gilrs,
        held: None,
        stick: None,
    });
    glib::timeout_add_local(Duration::from_millis(16), move || {
        poll(&mut pad.borrow_mut());
        glib::ControlFlow::Continue
    });
}

fn on_pad_connected(name: Option<&str>) {
    PAD_CONNECTED.with(|c| c.set(name.is_some()));
    PAD_LABEL.with(|l| {
        if let Some(l) = l.borrow().as_ref() {
            l.set_text(name.unwrap_or("Controller"));
        }
    });
    if let Some(sh) = shell::try_get() {
        sh.set_bumpers_visible(name.is_some() || mode() == Mode::Gamepad);
    }
}

fn press_dir(pad: &mut Pad, dir: Dir) {
    set_mode(Mode::Gamepad);
    move_focus(dir);
    pad.held = Some((dir, Instant::now() + REPEAT_DELAY));
}

fn poll(pad: &mut Pad) {
    use gilrs::{Axis, Button, EventType};
    while let Some(ev) = pad.gilrs.next_event() {
        match ev.event {
            EventType::ButtonPressed(button, _) => {
                let action = match button {
                    Button::DPadUp => {
                        press_dir(pad, Dir::Up);
                        None
                    }
                    Button::DPadDown => {
                        press_dir(pad, Dir::Down);
                        None
                    }
                    Button::DPadLeft => {
                        press_dir(pad, Dir::Left);
                        None
                    }
                    Button::DPadRight => {
                        press_dir(pad, Dir::Right);
                        None
                    }
                    Button::South => Some(PadAction::A),
                    Button::East => Some(PadAction::B),
                    Button::West => Some(PadAction::X),
                    Button::North => Some(PadAction::Y),
                    Button::LeftTrigger => Some(PadAction::Lb),
                    Button::RightTrigger => Some(PadAction::Rb),
                    Button::LeftTrigger2 => Some(PadAction::Lt),
                    Button::RightTrigger2 => Some(PadAction::Rt),
                    _ => {
                        set_mode(Mode::Gamepad);
                        None
                    }
                };
                if let Some(action) = action {
                    perform(action);
                }
            }
            EventType::ButtonReleased(
                Button::DPadUp | Button::DPadDown | Button::DPadLeft | Button::DPadRight,
                _,
            ) => pad.held = None,
            EventType::AxisChanged(Axis::LeftStickX | Axis::LeftStickY, _, _) => {
                let gp = pad.gilrs.gamepad(ev.id);
                let x = gp.value(Axis::LeftStickX);
                let y = gp.value(Axis::LeftStickY);
                let mag = x.abs().max(y.abs());
                let dir = if mag > 0.6 {
                    Some(if x.abs() > y.abs() {
                        if x > 0.0 {
                            Dir::Right
                        } else {
                            Dir::Left
                        }
                    } else if y > 0.0 {
                        Dir::Up
                    } else {
                        Dir::Down
                    })
                } else if mag < 0.3 {
                    None
                } else {
                    pad.stick
                };
                if dir != pad.stick {
                    pad.stick = dir;
                    match dir {
                        Some(d) => press_dir(pad, d),
                        None => pad.held = None,
                    }
                }
            }
            EventType::Connected => {
                let name = pad.gilrs.gamepad(ev.id).name().to_owned();
                on_pad_connected(Some(&name));
            }
            EventType::Disconnected => {
                let next = pad
                    .gilrs
                    .gamepads()
                    .next()
                    .map(|(_, g)| g.name().to_owned());
                on_pad_connected(next.as_deref());
            }
            _ => {}
        }
    }
    if let Some((dir, next)) = pad.held {
        let now = Instant::now();
        if now >= next {
            move_focus(dir);
            pad.held = Some((dir, now + REPEAT_RATE));
        }
    }
}
