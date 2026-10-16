//! Native Steam — Linux client (GTK 4 + libadwaita).
//!
//! An unofficial concept of a fully native Steam client with one adaptive UI
//! for mouse & keyboard, touch and gamepad. It renders `data/snapshot.json`
//! through the shared `steam-model` crate directly.

mod args;
mod art;
mod community;
mod images;
mod input;
mod library;
mod profile;
mod responsive;
mod shell;
mod store;
mod style;
mod ui;

use adw::prelude::*;
use gtk::{gio, glib};
use std::sync::OnceLock;
use steam_model::Snapshot;

pub const APP_ID: &str = "io.github.swsvindland.NativeSteam";

static EMBEDDED_SNAPSHOT: &str = include_str!("../../../data/snapshot.json");
static SNAPSHOT: OnceLock<Snapshot> = OnceLock::new();

/// The data every view renders. Loaded once at startup.
pub fn snapshot() -> &'static Snapshot {
    SNAPSHOT.get().expect("snapshot loaded before UI")
}

fn load_snapshot(path: Option<&str>) -> Snapshot {
    let path = path
        .map(str::to_owned)
        .or_else(|| std::env::var("NATIVE_STEAM_SNAPSHOT").ok());
    if let Some(path) = path {
        let loaded = std::fs::read_to_string(&path)
            .map_err(|e| e.to_string())
            .and_then(|s| Snapshot::from_json(&s).map_err(|e| e.to_string()));
        match loaded {
            Ok(s) => return s,
            Err(e) => {
                eprintln!("native-steam: couldn't load {path}: {e}; using the bundled snapshot")
            }
        }
    }
    Snapshot::from_json(EMBEDDED_SNAPSHOT).expect("bundled snapshot.json is valid")
}

fn main() -> glib::ExitCode {
    let args = match args::Args::parse(std::env::args().skip(1)) {
        Ok(a) => a,
        Err(msg) => {
            eprintln!("native-steam: {msg}\n\n{}", args::USAGE);
            return glib::ExitCode::FAILURE;
        }
    };
    if args.help {
        println!("{}", args::USAGE);
        return glib::ExitCode::SUCCESS;
    }

    let _ = SNAPSHOT.set(load_snapshot(args.snapshot.as_deref()));
    gio::resources_register_include!("resources.gresource").expect("register bundled resources");

    let app = adw::Application::builder()
        .application_id(APP_ID)
        .flags(gio::ApplicationFlags::NON_UNIQUE)
        .build();
    app.connect_startup(|_| style::init());
    app.connect_activate(move |app| shell::build(app, &args));
    // GTK must not parse our flags.
    app.run_with_args::<&str>(&[])
}
