//! The adaptive shell: header bar with the Steam-style tab strip (regular),
//! `AdwViewSwitcherBar` (compact), one `AdwNavigationView` per tab, the
//! gamepad hints bar and the breakpoints that switch between size classes.

use crate::args::Args;
use crate::responsive::{self, Width};
use crate::{community, images, input, library, profile, snapshot, store, ui};
use adw::prelude::*;
use gtk::{gio, glib};
use std::cell::{OnceCell, RefCell};
use std::rc::Rc;

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum Tab {
    Store,
    Library,
    Community,
    Profile,
}

impl Tab {
    pub const ALL: [Tab; 4] = [Tab::Store, Tab::Library, Tab::Community, Tab::Profile];

    pub fn name(self) -> &'static str {
        match self {
            Tab::Store => "store",
            Tab::Library => "library",
            Tab::Community => "community",
            Tab::Profile => "profile",
        }
    }

    pub fn from_name(s: &str) -> Option<Tab> {
        match s.to_ascii_lowercase().as_str() {
            "store" => Some(Tab::Store),
            "library" => Some(Tab::Library),
            "community" => Some(Tab::Community),
            "profile" | "user" | "kestrel" | "you" => Some(Tab::Profile),
            _ => None,
        }
    }

    pub fn index(self) -> usize {
        Tab::ALL.iter().position(|t| *t == self).unwrap_or(0)
    }

    /// Uppercase tab label; the fourth tab is the persona name.
    pub fn title(self) -> String {
        match self {
            Tab::Store => "STORE".into(),
            Tab::Library => "LIBRARY".into(),
            Tab::Community => "COMMUNITY".into(),
            Tab::Profile => snapshot().user.persona_name.to_uppercase(),
        }
    }

    fn icon(self) -> &'static str {
        match self {
            Tab::Store => "ns-store-symbolic",
            Tab::Library => "ns-library-symbolic",
            Tab::Community => "ns-community-symbolic",
            Tab::Profile => "ns-person-symbolic",
        }
    }
}

pub struct Shell {
    pub window: adw::ApplicationWindow,
    pub stack: adw::ViewStack,
    navs: Vec<adw::NavigationView>,
    tab_buttons: Vec<gtk::ToggleButton>,
    bumpers: Vec<gtk::Label>,
    back: gtk::Button,
    pub hints: gtk::Revealer,
    pub switcher_bar: adw::ViewSwitcherBar,
    toasts: adw::ToastOverlay,
}

thread_local! {
    static SHELL: OnceCell<Rc<Shell>> = const { OnceCell::new() };
    static SEARCHES: RefCell<Vec<(Tab, glib::WeakRef<gtk::SearchEntry>)>> = const { RefCell::new(Vec::new()) };
    /// Widgets that had focus when each detail page was pushed.
    static OPENERS: RefCell<Vec<glib::WeakRef<gtk::Widget>>> = const { RefCell::new(Vec::new()) };
}

pub fn get() -> Rc<Shell> {
    SHELL.with(|s| s.get().cloned()).expect("shell is built")
}

pub fn try_get() -> Option<Rc<Shell>> {
    SHELL.with(|s| s.get().cloned())
}

/// Lets a tab register its search field so Ctrl+F / gamepad Y can focus it.
pub fn register_search(tab: Tab, entry: &gtk::SearchEntry) {
    SEARCHES.with(|s| s.borrow_mut().push((tab, entry.downgrade())));
}

impl Shell {
    pub fn current_tab(&self) -> Tab {
        self.stack
            .visible_child_name()
            .and_then(|n| Tab::from_name(&n))
            .unwrap_or(Tab::Store)
    }

    pub fn nav(&self, tab: Tab) -> &adw::NavigationView {
        &self.navs[tab.index()]
    }

    pub fn current_nav(&self) -> &adw::NavigationView {
        self.nav(self.current_tab())
    }

    pub fn select_tab(&self, tab: Tab) {
        self.stack.set_visible_child_name(tab.name());
    }

    /// LB / RB: previous / next top-level tab (wraps).
    pub fn cycle_tab(&self, delta: i32) {
        let i = self.current_tab().index() as i32;
        let next = (i + delta).rem_euclid(Tab::ALL.len() as i32) as usize;
        self.select_tab(Tab::ALL[next]);
    }

    pub fn push(&self, page: &adw::NavigationPage) {
        let opener = gtk::prelude::GtkWindowExt::focus(&self.window).map(|w| w.downgrade());
        OPENERS.with(|o| o.borrow_mut().push(opener.unwrap_or_default()));
        self.current_nav().push(page);
    }

    /// Pops the current tab's navigation stack. Returns false at the root.
    pub fn pop(&self) -> bool {
        let nav = self.current_nav();
        let can_pop = nav
            .visible_page()
            .is_some_and(|p| nav.previous_page(&p).is_some());
        can_pop && nav.pop()
    }

    pub fn toast(&self, text: &str) {
        let t = adw::Toast::new(text);
        t.set_timeout(2);
        self.toasts.add_toast(t);
    }

    /// Focuses the visible search field of the current tab (Store / Library).
    /// Other tabs jump to the Store search.
    pub fn focus_search(&self) {
        let mut tab = self.current_tab();
        if !matches!(tab, Tab::Store | Tab::Library) {
            tab = Tab::Store;
            self.select_tab(tab);
        }
        let nav = self.nav(tab);
        if nav
            .visible_page()
            .is_some_and(|p| nav.previous_page(&p).is_some())
        {
            nav.pop_to_tag("root");
        }
        let entry = SEARCHES.with(|s| {
            s.borrow()
                .iter()
                .filter(|(t, _)| *t == tab)
                .filter_map(|(_, w)| w.upgrade())
                .find(|e| e.is_mapped())
        });
        if let Some(e) = entry {
            e.grab_focus();
            input::scroll_focus_into_view(e.upcast_ref());
        }
    }

    /// Moves focus to the active tab in the tab strip (or bottom bar on compact).
    pub fn focus_tab_bar(&self) {
        if responsive::current().is_compact() {
            if let Some(btn) = find_active_toggle(self.switcher_bar.upcast_ref()) {
                btn.grab_focus();
            }
        } else {
            self.tab_buttons[self.current_tab().index()].grab_focus();
        }
    }

    /// Shows the small LB / RB glyphs at either end of the tab strip.
    pub fn set_bumpers_visible(&self, visible: bool) {
        for b in &self.bumpers {
            b.set_visible(visible);
        }
    }

    fn update_back(&self) {
        let nav = self.current_nav();
        let deeper = nav
            .visible_page()
            .is_some_and(|p| nav.previous_page(&p).is_some());
        self.back.set_visible(deeper);
    }
}

fn find_active_toggle(w: &gtk::Widget) -> Option<gtk::ToggleButton> {
    let mut child = w.first_child();
    while let Some(c) = child {
        if let Some(t) = c.downcast_ref::<gtk::ToggleButton>() {
            if t.is_active() {
                return Some(t.clone());
            }
        }
        if let Some(found) = find_active_toggle(&c) {
            return Some(found);
        }
        child = c.next_sibling();
    }
    None
}

// ---------------------------------------------------------------------------
// Navigation helpers used by cards everywhere
// ---------------------------------------------------------------------------

/// Store app page (falls back to whatever data we have for that app).
pub fn open_store_app(app_id: u32) {
    if let Some(page) = store::app_page(app_id) {
        get().push(&page);
    }
}

/// Library game page.
pub fn open_game(app_id: u32) {
    if let Some(page) = library::game_page(app_id) {
        get().push(&page);
    }
}

/// Library page if the game is owned, else the store page.
pub fn open_app(app_id: u32) {
    if snapshot().library_game(app_id).is_some() {
        open_game(app_id);
    } else {
        open_store_app(app_id);
    }
}

pub fn open_friends() {
    get().push(&community::friends_page());
}

// ---------------------------------------------------------------------------
// Construction
// ---------------------------------------------------------------------------

pub fn build(app: &adw::Application, args: &Args) {
    images::init();
    let snap = snapshot();
    let (width, height) = args.size.unwrap_or((1440, 900));

    let window = adw::ApplicationWindow::builder()
        .application(app)
        .title("Native Steam")
        .default_width(width)
        .default_height(height)
        .width_request(360)
        .height_request(480)
        .build();
    window.add_css_class("steam");
    window.set_icon_name(Some(crate::APP_ID));

    // --- Tabs: one navigation stack each -----------------------------------
    let stack = adw::ViewStack::new();
    stack.set_vhomogeneous(false);
    let mut navs = Vec::new();
    for tab in Tab::ALL {
        let nav = adw::NavigationView::new();
        let root = match tab {
            Tab::Store => store::root(),
            Tab::Library => library::root(),
            Tab::Community => community::root(),
            Tab::Profile => profile::root(),
        };
        nav.add(&root);
        let page = stack.add_titled_with_icon(&nav, Some(tab.name()), &tab.title(), tab.icon());
        page.set_use_underline(false);
        if tab == Tab::Profile {
            use_avatar_as_tab_icon(&page);
        }
        navs.push(nav);
    }

    // --- Header: [back] STEAM  LB STORE LIBRARY COMMUNITY KESTREL RB … ----
    let header = adw::HeaderBar::new();
    header.set_show_title(false);
    header.add_css_class("steam-header");

    let back = gtk::Button::from_icon_name("ns-back-symbolic");
    back.set_tooltip_text(Some("Back"));
    back.add_css_class("flat");
    back.add_css_class("nav-back");
    back.set_visible(false);
    back.set_action_name(Some("win.back"));
    header.pack_start(&back);

    let wordmark = ui::label("STEAM", &["wordmark"]);
    wordmark.set_valign(gtk::Align::Center);
    header.pack_start(&wordmark);

    let strip = ui::hbox(2);
    strip.add_css_class("tab-strip");
    let lb = ui::label("LB", &["pad-glyph", "bumper"]);
    let rb = ui::label("RB", &["pad-glyph", "bumper"]);
    for b in [&lb, &rb] {
        b.set_valign(gtk::Align::Center);
        b.set_xalign(0.5);
    }
    lb.set_visible(false);
    rb.set_visible(false);
    strip.append(&lb);
    let mut tab_buttons: Vec<gtk::ToggleButton> = Vec::new();
    for tab in Tab::ALL {
        let b = gtk::ToggleButton::with_label(&tab.title());
        b.add_css_class("tab");
        b.add_css_class("flat");
        if let Some(first) = tab_buttons.first() {
            b.set_group(Some(first));
        }
        let stack_ = stack.clone();
        b.connect_toggled(move |b| {
            if b.is_active() {
                stack_.set_visible_child_name(tab.name());
            }
        });
        strip.append(&b);
        tab_buttons.push(b);
    }
    strip.append(&rb);
    header.pack_start(&strip);

    // End side (packed right-to-left): menu, me, friends, search.
    let menu = gio::Menu::new();
    menu.append(Some("Keyboard & Gamepad"), Some("win.controls"));
    menu.append(Some("About Native Steam"), Some("win.about"));
    let menu_btn = gtk::MenuButton::builder()
        .icon_name("ns-menu-symbolic")
        .menu_model(&menu)
        .tooltip_text("Main menu")
        .build();
    menu_btn.add_css_class("flat");
    header.pack_end(&menu_btn);

    let me = ui::hbox(8);
    let me_avatar = ui::avatar(&snap.user.avatar_url, 28, Some(&snap.user.status));
    let me_name = ui::label(&snap.user.persona_name, &["me-name"]);
    me.append(&me_avatar);
    me.append(&me_name);
    let me_btn = gtk::Button::builder()
        .child(&me)
        .tooltip_text("View profile")
        .build();
    me_btn.add_css_class("flat");
    me_btn.add_css_class("me-button");
    {
        let stack = stack.clone();
        me_btn.connect_clicked(move |_| stack.set_visible_child_name(Tab::Profile.name()));
    }
    header.pack_end(&me_btn);

    let online = snap
        .friends
        .iter()
        .filter(|f| f.status != "offline")
        .count();
    let friends_box = ui::hbox(6);
    friends_box.append(&ui::icon("ns-community-symbolic", 16));
    friends_box.append(&ui::label(&online.to_string(), &["friends-count"]));
    let friends_btn = gtk::Button::builder()
        .child(&friends_box)
        .tooltip_text(format!("Friends — {online} online").as_str())
        .build();
    friends_btn.add_css_class("flat");
    friends_btn.connect_clicked(|_| open_friends());
    header.pack_end(&friends_btn);

    let search_btn = gtk::Button::from_icon_name("ns-search-symbolic");
    search_btn.set_tooltip_text(Some("Search (Ctrl+F)"));
    search_btn.add_css_class("flat");
    search_btn.set_action_name(Some("win.search"));
    header.pack_end(&search_btn);

    // --- Content + bottom bars ----------------------------------------------
    let toasts = adw::ToastOverlay::new();
    toasts.set_child(Some(&stack));

    let hints = input::hints_bar();
    let switcher_bar = adw::ViewSwitcherBar::builder().stack(&stack).build();
    switcher_bar.add_css_class("steam-tabbar");

    let toolbar = adw::ToolbarView::new();
    toolbar.set_top_bar_style(adw::ToolbarStyle::Flat);
    toolbar.set_bottom_bar_style(adw::ToolbarStyle::Flat);
    toolbar.add_top_bar(&header);
    toolbar.set_content(Some(&toasts));
    toolbar.add_bottom_bar(&hints);
    toolbar.add_bottom_bar(&switcher_bar);
    window.set_content(Some(&toolbar));
    if args.ignore_pointer {
        // Screenshot automation: a parked cursor must not hover anything.
        toolbar.set_can_target(false);
    }

    // --- Breakpoints ----------------------------------------------------------
    // Only the last matching breakpoint applies, so they're added widest first.
    let cond = |s: &str| adw::BreakpointCondition::parse(s).expect("valid breakpoint");
    let bp_large = adw::Breakpoint::new(cond("max-width: 1099px"));
    let bp_medium = adw::Breakpoint::new(cond("max-width: 999px"));
    let bp_compact = adw::Breakpoint::new(cond("max-width: 699px"));
    bp_compact.add_setter(&switcher_bar, "reveal", Some(&true.to_value()));
    bp_compact.add_setter(&strip, "visible", Some(&false.to_value()));
    bp_compact.add_setter(&friends_btn, "visible", Some(&false.to_value()));
    // Compact: the bottom tab bar already shows the avatar (KESTREL tab).
    bp_compact.add_setter(&me_btn, "visible", Some(&false.to_value()));
    bp_medium.add_setter(&friends_btn, "visible", Some(&false.to_value()));
    bp_medium.add_setter(&me_name, "visible", Some(&false.to_value()));
    bp_medium.add_setter(&wordmark, "visible", Some(&false.to_value()));
    window.add_breakpoint(bp_large.clone());
    window.add_breakpoint(bp_medium.clone());
    window.add_breakpoint(bp_compact.clone());
    window.connect_current_breakpoint_notify(move |w| {
        let width = match w.current_breakpoint() {
            None => Width::Wide,
            Some(b) if b == bp_compact => Width::Compact,
            Some(b) if b == bp_medium => Width::Medium,
            Some(_) => Width::Large,
        };
        responsive::set(width);
        for (class, on) in [
            ("compact", width.is_compact()),
            ("medium", width == Width::Medium),
        ] {
            if on {
                w.add_css_class(class);
            } else {
                w.remove_css_class(class);
            }
        }
    });

    let shell = Rc::new(Shell {
        window: window.clone(),
        stack: stack.clone(),
        navs,
        tab_buttons,
        bumpers: vec![lb, rb],
        back,
        hints,
        switcher_bar,
        toasts,
    });
    SHELL.with(|s| {
        let _ = s.set(shell.clone());
    });

    // Keep tab strip, back button and per-tab focus memory in sync.
    stack.connect_visible_child_name_notify(|stack| {
        let sh = get();
        if let Some(tab) = stack.visible_child_name().and_then(|n| Tab::from_name(&n)) {
            let b = &sh.tab_buttons[tab.index()];
            if !b.is_active() {
                b.set_active(true);
            }
            sh.update_back();
            input::on_tab_changed(tab);
        }
    });
    for nav in &shell.navs {
        nav.connect_visible_page_notify(|_| get().update_back());
        // Keyboard/gamepad focus follows navigation: land on the new page's
        // primary action, and return to the card that opened it on pop.
        nav.connect_pushed(|_| {
            glib::idle_add_local_once(|| {
                if matches!(input::mode(), input::Mode::Gamepad | input::Mode::Keyboard) {
                    input::focus_first_item();
                }
            });
        });
        nav.connect_popped(|_, _| {
            let opener = OPENERS
                .with(|o| o.borrow_mut().pop())
                .and_then(|w| w.upgrade());
            glib::idle_add_local_once(move || {
                if !matches!(input::mode(), input::Mode::Gamepad | input::Mode::Keyboard) {
                    return;
                }
                match opener.filter(|w| w.is_mapped()) {
                    Some(w) => {
                        w.grab_focus();
                        input::scroll_focus_into_view(&w);
                    }
                    None => {
                        input::focus_first_item();
                    }
                }
            });
        });
    }
    shell.tab_buttons[0].set_active(true);

    install_actions(app, &window);
    input::install(&window);
    window.present();

    apply_args(&shell, args);
}

/// DESIGN.md §2: the compact persona tab shows the user's avatar. View-stack
/// pages only take icon *names*, so once the avatar is downloaded we save it
/// as an unthemed icon in a private icon-theme search path and switch to it.
fn use_avatar_as_tab_icon(page: &adw::ViewStackPage) {
    let page = page.clone();
    images::request(&snapshot().user.avatar_url, move |texture| {
        let Some(texture) = texture else { return };
        let dir = glib::user_cache_dir().join("native-steam").join("icons");
        if std::fs::create_dir_all(&dir).is_err() {
            return;
        }
        if texture
            .save_to_png(dir.join("ns-persona-avatar.png"))
            .is_err()
        {
            return;
        }
        if let Some(display) = gtk::gdk::Display::default() {
            gtk::IconTheme::for_display(&display).add_search_path(&dir);
            page.set_icon_name(Some("ns-persona-avatar"));
        }
    });
}

fn install_actions(app: &adw::Application, window: &adw::ApplicationWindow) {
    let tab = gio::ActionEntry::builder("tab")
        .parameter_type(Some(glib::VariantTy::STRING))
        .activate(|_: &adw::ApplicationWindow, _, param| {
            if let Some(tab) = param.and_then(|p| p.str()).and_then(Tab::from_name) {
                let sh = get();
                sh.select_tab(tab);
                if input::mode() != input::Mode::Mouse {
                    input::focus_first_item();
                }
            }
        })
        .build();
    let search = gio::ActionEntry::builder("search")
        .activate(|_: &adw::ApplicationWindow, _, _| get().focus_search())
        .build();
    let back = gio::ActionEntry::builder("back")
        .activate(|_: &adw::ApplicationWindow, _, _| {
            get().pop();
        })
        .build();
    let about = gio::ActionEntry::builder("about")
        .activate(|w: &adw::ApplicationWindow, _, _| show_about(w))
        .build();
    let controls = gio::ActionEntry::builder("controls")
        .activate(|w: &adw::ApplicationWindow, _, _| show_controls(w))
        .build();
    window.add_action_entries([tab, search, back, about, controls]);

    for (i, t) in Tab::ALL.iter().enumerate() {
        let accel = format!("<Primary>{}", i + 1);
        app.set_accels_for_action(&format!("win.tab::{}", t.name()), &[accel.as_str()]);
    }
    app.set_accels_for_action("win.search", &["<Primary>f"]);
    app.set_accels_for_action("win.back", &["<Primary>bracketleft", "<Alt>Left"]);
}

fn show_about(window: &adw::ApplicationWindow) {
    let about = adw::AboutDialog::builder()
        .application_name("Native Steam")
        .application_icon(crate::APP_ID)
        .developer_name("Native Steam contributors")
        .version(env!("CARGO_PKG_VERSION"))
        .license_type(gtk::License::MitX11)
        .website("https://github.com/swsvindland/native-steam")
        .comments(
            "An unofficial concept: what a fully native Steam client could look like on Linux, \
             built with GTK 4 and libadwaita. Not affiliated with or endorsed by Valve. \
             Purchases and installs are purely visual.",
        )
        .build();
    about.present(Some(window));
}

fn show_controls(window: &adw::ApplicationWindow) {
    let rows = [
        ("Arrow keys · D-pad · Left stick", "Move focus"),
        ("Enter · Space · Ⓐ", "Activate"),
        ("Esc · Backspace · Ctrl+[ · Ⓑ", "Back"),
        ("Ctrl+F · Ⓨ", "Search"),
        ("Ctrl+1…4 · LB / RB", "Switch tab"),
        ("Ⓧ", "Favorite (Library) · Wishlist (Store)"),
        ("LT / RT", "Previous / next collection or section"),
    ];
    let list = gtk::ListBox::new();
    list.add_css_class("boxed-list");
    list.set_selection_mode(gtk::SelectionMode::None);
    for (keys, action) in rows {
        let row = adw::ActionRow::builder()
            .title(action)
            .subtitle(keys)
            .build();
        list.append(&row);
    }
    let body = ui::vbox(12);
    body.set_margin_top(12);
    body.set_margin_bottom(24);
    body.set_margin_start(24);
    body.set_margin_end(24);
    body.append(&list);
    let tv = adw::ToolbarView::new();
    tv.add_top_bar(&adw::HeaderBar::new());
    tv.set_content(Some(&body));
    let dialog = adw::Dialog::builder()
        .title("Keyboard & Gamepad")
        .content_width(460)
        .child(&tv)
        .build();
    dialog.present(Some(window));
}

fn apply_args(shell: &Rc<Shell>, args: &Args) {
    if let Some(tab) = args.tab {
        shell.select_tab(tab);
    }
    if let Some(id) = args.app {
        if args.tab.is_none() {
            shell.select_tab(Tab::Store);
        }
        if let Some(page) = store::app_page(id) {
            shell.push(&page);
        } else {
            eprintln!("native-steam: no store data for app {id}");
        }
    }
    if let Some(id) = args.game {
        if args.tab.is_none() {
            shell.select_tab(Tab::Library);
        }
        if let Some(page) = library::game_page(id) {
            shell.push(&page);
        } else {
            eprintln!("native-steam: app {id} is not in the library");
        }
    }

    let gamepad = args.gamepad;
    let nav = args.nav.clone();
    let window = shell.window.clone();
    // Let the first layout settle so the initial focus lands on real cards.
    glib::timeout_add_local_once(std::time::Duration::from_millis(350), move || {
        if gamepad {
            input::set_mode(input::Mode::Gamepad);
            input::focus_first_item();
        } else {
            gtk::prelude::GtkWindowExt::set_focus(&window, None::<&gtk::Widget>);
        }
        // Scripted gamepad presses for screenshot automation (`--nav d,r,a`).
        for (i, action) in nav.into_iter().enumerate() {
            let delay = std::time::Duration::from_millis(400 * (i as u64 + 1));
            glib::timeout_add_local_once(delay, move || input::perform(action));
        }
    });
}

/// Small helper for detail pages: a page titled `title` with `class` background.
pub fn detail_page(title: &str, child: &impl IsA<gtk::Widget>, class: &str) -> adw::NavigationPage {
    let page = adw::NavigationPage::builder()
        .title(title)
        .child(child)
        .build();
    page.add_css_class(class);
    page.add_css_class("detail");
    page
}
