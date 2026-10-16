//! Asynchronous image loading with a memory cache and an on-disk cache.
//!
//! Requests are deduplicated per URL on the main thread. A small pool of worker
//! threads fetches the bytes (disk cache first, then HTTPS via `ureq`) and
//! decodes them into a `gdk::Texture` off the main thread
//! (`gdk_texture_new_from_bytes` is documented as thread-safe). Results are sent
//! back to the GLib main loop over an `async-channel`.

use gtk::glib::translate::{FromGlibPtrFull, ToGlibPtr};
use gtk::{gdk, glib};
use std::cell::RefCell;
use std::collections::{HashMap, HashSet};
use std::path::{Path, PathBuf};
use std::sync::{mpsc, Arc, Mutex};
use std::time::Duration;

const WORKERS: usize = 8;

type Callback = Box<dyn FnOnce(Option<gdk::Texture>)>;

struct Loader {
    cache: HashMap<String, gdk::Texture>,
    failed: HashSet<String>,
    pending: HashMap<String, Vec<Callback>>,
    jobs: mpsc::Sender<String>,
}

thread_local! {
    static LOADER: RefCell<Option<Loader>> = const { RefCell::new(None) };
}

/// Directory used for the on-disk image cache.
pub fn cache_dir() -> PathBuf {
    glib::user_cache_dir().join("native-steam").join("images")
}

/// Starts the worker pool. Must be called once on the main thread.
pub fn init() {
    let (job_tx, job_rx) = mpsc::channel::<String>();
    let job_rx = Arc::new(Mutex::new(job_rx));
    let (done_tx, done_rx) = async_channel::unbounded::<(String, Option<gdk::Texture>)>();

    let dir = cache_dir();
    if let Err(err) = std::fs::create_dir_all(&dir) {
        eprintln!("native-steam: image disk cache disabled ({err})");
    }

    let agent: ureq::Agent = ureq::Agent::config_builder()
        .timeout_global(Some(Duration::from_secs(30)))
        .user_agent("NativeSteam-GTK/0.1 (+https://github.com/swsvindland/native-steam)")
        .build()
        .into();

    for i in 0..WORKERS {
        let rx = job_rx.clone();
        let tx = done_tx.clone();
        let agent = agent.clone();
        let dir = dir.clone();
        std::thread::Builder::new()
            .name(format!("image-worker-{i}"))
            .spawn(move || loop {
                let next = rx.lock().map(|r| r.recv());
                let Ok(Ok(url)) = next else { break };
                let texture = fetch(&agent, &dir, &url).and_then(decode);
                if tx.send_blocking((url, texture)).is_err() {
                    break;
                }
            })
            .expect("spawn image worker");
    }

    glib::spawn_future_local(async move {
        while let Ok((url, texture)) = done_rx.recv().await {
            complete(url, texture);
        }
    });

    LOADER.with(|l| {
        *l.borrow_mut() = Some(Loader {
            cache: HashMap::new(),
            failed: HashSet::new(),
            pending: HashMap::new(),
            jobs: job_tx,
        })
    });
}

/// Returns the texture immediately if it's already in the memory cache.
pub fn cached(url: &str) -> Option<gdk::Texture> {
    LOADER.with(|l| l.borrow().as_ref().and_then(|l| l.cache.get(url).cloned()))
}

/// Loads `url` and calls `done` on the main thread with the texture, or `None`
/// if it couldn't be fetched or decoded. Cache hits and known failures resolve
/// synchronously; concurrent requests for the same URL share one fetch.
pub fn request(url: &str, done: impl FnOnce(Option<gdk::Texture>) + 'static) {
    enum Outcome {
        Hit(gdk::Texture),
        Failed,
        Queued,
    }
    let mut done: Option<Callback> = Some(Box::new(done));
    let outcome = LOADER.with(|l| {
        let mut guard = l.borrow_mut();
        let Some(loader) = guard.as_mut() else {
            return Outcome::Failed;
        };
        if let Some(t) = loader.cache.get(url) {
            return Outcome::Hit(t.clone());
        }
        if loader.failed.contains(url) {
            return Outcome::Failed;
        }
        let callbacks = loader.pending.entry(url.to_owned()).or_default();
        let first = callbacks.is_empty();
        callbacks.extend(done.take());
        if first && loader.jobs.send(url.to_owned()).is_err() {
            done = loader.pending.remove(url).and_then(|mut v| v.pop());
            return Outcome::Failed;
        }
        Outcome::Queued
    });
    // Callbacks run outside the RefCell borrow so they may request more images.
    match (outcome, done) {
        (Outcome::Hit(t), Some(cb)) => cb(Some(t)),
        (Outcome::Failed, Some(cb)) => cb(None),
        _ => {}
    }
}

fn complete(url: String, texture: Option<gdk::Texture>) {
    let callbacks = LOADER.with(|l| {
        let mut guard = l.borrow_mut();
        let loader = guard.as_mut()?;
        match &texture {
            Some(t) => {
                loader.cache.insert(url.clone(), t.clone());
            }
            None => {
                loader.failed.insert(url.clone());
            }
        }
        loader.pending.remove(&url)
    });
    for cb in callbacks.unwrap_or_default() {
        cb(texture.clone());
    }
}

fn fnv1a(s: &str) -> u64 {
    let mut h: u64 = 0xcbf29ce484222325;
    for b in s.bytes() {
        h ^= u64::from(b);
        h = h.wrapping_mul(0x100000001b3);
    }
    h
}

fn fetch(agent: &ureq::Agent, dir: &Path, url: &str) -> Option<Vec<u8>> {
    let path = dir.join(format!("{:016x}", fnv1a(url)));
    if let Ok(bytes) = std::fs::read(&path) {
        if !bytes.is_empty() {
            return Some(bytes);
        }
    }
    let mut response = agent.get(url).call().ok()?;
    let bytes = response
        .body_mut()
        .with_config()
        .limit(32 * 1024 * 1024)
        .read_to_vec()
        .ok()?;
    let tmp = path.with_extension("part");
    if std::fs::write(&tmp, &bytes).is_ok() {
        let _ = std::fs::rename(&tmp, &path);
    }
    Some(bytes)
}

fn decode(bytes: Vec<u8>) -> Option<gdk::Texture> {
    let bytes = glib::Bytes::from_owned(bytes);
    // SAFETY: gdk_texture_new_from_bytes() is documented as thread-safe ("so that
    // you can e.g. use GTask and g_task_run_in_thread() to avoid blocking the main
    // thread while loading a big image"). The safe binding asserts the main
    // thread, so we call the C function directly. Textures are immutable and
    // gdk4 marks `Texture` as Send + Sync.
    unsafe {
        let mut error = std::ptr::null_mut();
        let ptr = gdk::ffi::gdk_texture_new_from_bytes(bytes.to_glib_none().0, &mut error);
        if !error.is_null() {
            glib::ffi::g_error_free(error);
            return None;
        }
        if ptr.is_null() {
            return None;
        }
        Some(gdk::Texture::from_glib_full(ptr))
    }
}
