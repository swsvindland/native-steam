//! Width classes driven by the window's `AdwBreakpoint`s.
//!
//! The shell installs three breakpoints (see `shell.rs`). Static shell chrome
//! uses breakpoint setters directly; content that is built on demand (detail
//! pages, cards) subscribes here with [`watch`] so it can re-flow too.

use gtk::glib;
use gtk::prelude::*;
use std::cell::{Cell, RefCell};

#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub enum Width {
    /// < 700 px: bottom tab bar, single column, compact cards.
    Compact,
    /// 700 – 999 px: top nav, collection chips instead of the sidebar.
    Medium,
    /// 1000 – 1099 px: library collections sidebar.
    Large,
    /// >= 1100 px: community right rail.
    Wide,
}

impl Width {
    pub fn is_compact(self) -> bool {
        self == Width::Compact
    }

    /// Page gutter per DESIGN.md §1 (16 compact / 24–32 regular).
    pub fn gutter(self) -> i32 {
        if self.is_compact() {
            16
        } else {
            32
        }
    }
}

type Listener = Box<dyn Fn(Width) -> bool>;

thread_local! {
    static CURRENT: Cell<Width> = const { Cell::new(Width::Wide) };
    static LISTENERS: RefCell<Vec<Listener>> = const { RefCell::new(Vec::new()) };
}

pub fn current() -> Width {
    CURRENT.with(Cell::get)
}

pub fn set(width: Width) {
    if CURRENT.with(|c| c.replace(width)) == width {
        return;
    }
    // Listeners may register new listeners while running, so take the list out.
    let listeners = LISTENERS.with(|l| std::mem::take(&mut *l.borrow_mut()));
    let mut alive: Vec<Listener> = listeners.into_iter().filter(|f| f(width)).collect();
    LISTENERS.with(|l| {
        let mut l = l.borrow_mut();
        alive.append(&mut l);
        *l = alive;
    });
}

/// Calls `f` now and whenever the width class changes, for as long as `obj` lives.
pub fn watch<O: IsA<glib::Object>>(obj: &O, f: impl Fn(&O, Width) + 'static) {
    f(obj, current());
    let weak = obj.downgrade();
    LISTENERS.with(|l| {
        l.borrow_mut().push(Box::new(move |w| match weak.upgrade() {
            Some(o) => {
                f(&o, w);
                true
            }
            None => false,
        }))
    });
}

/// Applies the page gutter as start/end margin on `w`.
pub fn gutter<W: IsA<gtk::Widget>>(w: &W) {
    watch(w.upcast_ref::<gtk::Widget>(), |w, width| {
        w.set_margin_start(width.gutter());
        w.set_margin_end(width.gutter());
    });
}

/// Horizontal on regular widths, vertical on compact.
pub fn stack_on_compact(b: &gtk::Box) {
    watch(b, |b, width| {
        b.set_orientation(if width.is_compact() {
            gtk::Orientation::Vertical
        } else {
            gtk::Orientation::Horizontal
        });
    });
}

/// Shows `w` only when `pred(width)` holds.
pub fn visible_when<W: IsA<gtk::Widget>>(w: &W, pred: impl Fn(Width) -> bool + 'static) {
    watch(w.upcast_ref::<gtk::Widget>(), move |w, width| {
        w.set_visible(pred(width))
    });
}
