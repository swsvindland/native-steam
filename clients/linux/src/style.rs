//! Steam look: force dark, then layer brand tokens over libadwaita.
//!
//! `style.css` (in the GResource at the app's base path) is loaded
//! automatically by `AdwApplication`. libadwaita's own palette is overridden by
//! a version-specific sheet: `@define-color` on 1.5, CSS variables on >= 1.6.

use gtk::gdk;

pub fn init() {
    adw::StyleManager::default().set_color_scheme(adw::ColorScheme::ForceDark);

    let sheet = if adw::major_version() > 1 || adw::minor_version() >= 6 {
        "style-adw16.css"
    } else {
        "style-adw15.css"
    };
    let provider = gtk::CssProvider::new();
    provider.load_from_resource(&format!("/io/github/swsvindland/NativeSteam/{sheet}"));
    if let Some(display) = gdk::Display::default() {
        gtk::style_context_add_provider_for_display(
            &display,
            &provider,
            gtk::STYLE_PROVIDER_PRIORITY_APPLICATION,
        );
    }
}
