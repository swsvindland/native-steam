//! `Art`: a lazily-loaded, aspect-ratio-aware artwork widget.
//!
//! Steam artwork comes in fixed aspect ratios (portrait 2:3, header 460:215,
//! capsule 616:353, hero ~3.1:1). `Art` measures height-for-width from its
//! aspect ratio, so it works both at a fixed width (shelf cards) and fluid
//! (grids, banners). The image is requested the first time the widget is mapped,
//! shown with `ContentFit::Cover` (never letterboxed), and fades in over a
//! `surface`-coloured placeholder that can show the game's name.
//!
//! In "logo" mode the widget instead sizes itself to the transparent logo's own
//! aspect ratio within a bounding box, so logos can be aligned bottom-start.

use crate::images;
use gtk::glib;
use gtk::prelude::*;
use gtk::subclass::prelude::*;

type ResultFn = Box<dyn Fn(&Art, bool)>;

mod imp {
    use super::*;
    use std::cell::{Cell, RefCell};

    pub struct Art {
        pub picture: gtk::Picture,
        pub label: RefCell<Option<gtk::Label>>,
        pub urls: RefCell<Vec<String>>,
        pub requested: Cell<bool>,
        pub loaded: Cell<bool>,
        pub aspect: Cell<f64>,
        pub fixed_width: Cell<i32>,
        pub min_width: Cell<i32>,
        pub nat_width: Cell<i32>,
        pub min_height: Cell<i32>,
        pub max_height: Cell<i32>,
        pub logo_box: Cell<Option<(i32, i32)>>,
        pub on_result: RefCell<Option<ResultFn>>,
    }

    impl Default for Art {
        fn default() -> Self {
            let picture = gtk::Picture::new();
            picture.set_content_fit(gtk::ContentFit::Cover);
            picture.set_can_shrink(true);
            Self {
                picture,
                label: RefCell::new(None),
                urls: RefCell::new(Vec::new()),
                requested: Cell::new(false),
                loaded: Cell::new(false),
                aspect: Cell::new(16.0 / 9.0),
                fixed_width: Cell::new(-1),
                min_width: Cell::new(0),
                nat_width: Cell::new(200),
                min_height: Cell::new(0),
                max_height: Cell::new(0),
                logo_box: Cell::new(None),
                on_result: RefCell::new(None),
            }
        }
    }

    #[glib::object_subclass]
    impl ObjectSubclass for Art {
        const NAME: &'static str = "NsArt";
        type Type = super::Art;
        type ParentType = gtk::Widget;

        fn class_init(klass: &mut Self::Class) {
            klass.set_css_name("art");
            klass.set_accessible_role(gtk::AccessibleRole::Img);
        }
    }

    impl ObjectImpl for Art {
        fn constructed(&self) {
            self.parent_constructed();
            let obj = self.obj();
            obj.set_overflow(gtk::Overflow::Hidden);
            self.picture.set_parent(&*obj);
        }

        fn dispose(&self) {
            self.picture.unparent();
            if let Some(label) = self.label.take() {
                label.unparent();
            }
        }
    }

    impl WidgetImpl for Art {
        fn request_mode(&self) -> gtk::SizeRequestMode {
            if self.logo_box.get().is_some() {
                gtk::SizeRequestMode::ConstantSize
            } else {
                gtk::SizeRequestMode::HeightForWidth
            }
        }

        fn measure(&self, orientation: gtk::Orientation, for_size: i32) -> (i32, i32, i32, i32) {
            let aspect = self.aspect.get().max(0.05);
            if let Some((max_w, max_h)) = self.logo_box.get() {
                // Constant size: the logo's own aspect, contained in the box.
                let w = ((max_h as f64) * aspect).min(max_w as f64).round() as i32;
                let h = (w as f64 / aspect).round() as i32;
                return match orientation {
                    gtk::Orientation::Horizontal => (w, w, -1, -1),
                    _ => (h, h, -1, -1),
                };
            }
            let fixed = self.fixed_width.get();
            match orientation {
                gtk::Orientation::Horizontal => {
                    if fixed >= 0 {
                        (fixed, fixed, -1, -1)
                    } else {
                        let min = self.min_width.get();
                        (min, self.nat_width.get().max(min), -1, -1)
                    }
                }
                _ => {
                    let height_for = |w: i32| {
                        let mut h = w as f64 / aspect;
                        if self.max_height.get() > 0 {
                            h = h.min(self.max_height.get() as f64);
                        }
                        if self.min_height.get() > 0 {
                            h = h.max(self.min_height.get() as f64);
                        }
                        h.round() as i32
                    };
                    // Fixed-width art keeps its height no matter how much
                    // width a parent offers; fluid art follows the offer.
                    if fixed >= 0 {
                        let h = height_for(fixed);
                        (h, h, -1, -1)
                    } else if for_size >= 0 {
                        let h = height_for(for_size);
                        (h, h, -1, -1)
                    } else {
                        let min = self.min_width.get();
                        (
                            height_for(min),
                            height_for(self.nat_width.get().max(min)),
                            -1,
                            -1,
                        )
                    }
                }
            }
        }

        fn size_allocate(&self, width: i32, height: i32, baseline: i32) {
            self.picture.measure(gtk::Orientation::Horizontal, -1);
            self.picture.allocate(width, height, baseline, None);
            if let Some(label) = self.label.borrow().as_ref() {
                if label.is_visible() {
                    label.measure(gtk::Orientation::Horizontal, -1);
                    label.measure(gtk::Orientation::Vertical, width);
                    label.allocate(width, height, -1, None);
                }
            }
        }

        fn map(&self) {
            self.parent_map();
            self.obj().ensure_requested();
        }
    }
}

glib::wrapper! {
    pub struct Art(ObjectSubclass<imp::Art>)
        @extends gtk::Widget,
        @implements gtk::Accessible, gtk::Buildable, gtk::ConstraintTarget;
}

impl Art {
    /// `aspect` is width / height. `url` may be `None` (placeholder only).
    pub fn new(url: Option<&str>, aspect: f64) -> Self {
        let art: Self = glib::Object::new();
        art.imp().aspect.set(aspect);
        if let Some(url) = url.filter(|u| !u.is_empty()) {
            art.imp().urls.borrow_mut().push(url.to_owned());
        }
        art
    }

    /// Fixed width in px; height follows the aspect ratio.
    pub fn fixed(self, width: i32) -> Self {
        self.imp().fixed_width.set(width);
        self
    }

    /// Fluid width with a minimum and natural width; height follows the aspect.
    pub fn fluid(self, min: i32, natural: i32) -> Self {
        let imp = self.imp();
        imp.fixed_width.set(-1);
        imp.min_width.set(min);
        imp.nat_width.set(natural);
        self.set_hexpand(true);
        self
    }

    pub fn max_height(self, h: i32) -> Self {
        self.imp().max_height.set(h);
        self
    }

    pub fn min_height(self, h: i32) -> Self {
        self.imp().min_height.set(h);
        self
    }

    /// URLs to try, in order, if the primary one fails.
    pub fn fallbacks<'a>(self, urls: impl IntoIterator<Item = Option<&'a str>>) -> Self {
        {
            let mut list = self.imp().urls.borrow_mut();
            for url in urls.into_iter().flatten() {
                if !url.is_empty() && !list.iter().any(|u| u == url) {
                    list.push(url.to_owned());
                }
            }
        }
        self
    }

    /// Shows `text` centred over the placeholder until the image arrives.
    pub fn placeholder(self, text: &str) -> Self {
        let label = gtk::Label::new(Some(text));
        label.set_wrap(true);
        label.set_wrap_mode(gtk::pango::WrapMode::WordChar);
        label.set_justify(gtk::Justification::Center);
        label.set_max_width_chars(1);
        label.set_ellipsize(gtk::pango::EllipsizeMode::End);
        label.set_lines(3);
        label.add_css_class("art-placeholder");
        label.set_parent(&self);
        *self.imp().label.borrow_mut() = Some(label);
        self
    }

    /// Logo mode: keep the image's own aspect ratio, contained in max_w x max_h.
    pub fn logo(self, max_w: i32, max_h: i32) -> Self {
        let imp = self.imp();
        imp.logo_box.set(Some((max_w, max_h)));
        imp.aspect.set(2.4);
        imp.picture.set_content_fit(gtk::ContentFit::Contain);
        self.add_css_class("logo");
        self
    }

    pub fn class(self, class: &str) -> Self {
        self.add_css_class(class);
        self
    }

    /// Called once the image loads (`true`) or every URL failed (`false`).
    pub fn on_result(self, f: impl Fn(&Art, bool) + 'static) -> Self {
        *self.imp().on_result.borrow_mut() = Some(Box::new(f));
        self
    }

    pub fn set_fixed_width(&self, width: i32) {
        if self.imp().fixed_width.replace(width) != width {
            self.queue_resize();
        }
    }

    /// Changes the logo bounding box (logo mode only).
    pub fn set_logo_box(&self, max_w: i32, max_h: i32) {
        if self.imp().logo_box.get().is_some() {
            self.imp().logo_box.set(Some((max_w, max_h)));
            self.queue_resize();
        }
    }

    pub fn set_aspect(&self, aspect: f64) {
        if (self.imp().aspect.replace(aspect) - aspect).abs() > f64::EPSILON {
            self.queue_resize();
        }
    }

    pub fn is_loaded(&self) -> bool {
        self.imp().loaded.get()
    }

    fn ensure_requested(&self) {
        let imp = self.imp();
        if imp.requested.get() {
            return;
        }
        imp.requested.set(true);
        self.try_next(0);
    }

    fn try_next(&self, index: usize) {
        let url = self.imp().urls.borrow().get(index).cloned();
        let Some(url) = url else {
            self.add_css_class("failed");
            if let Some(f) = self.imp().on_result.borrow().as_ref() {
                f(self, false);
            }
            return;
        };
        let instant = images::cached(&url).is_some();
        let weak = self.downgrade();
        images::request(&url, move |texture| {
            let Some(art) = weak.upgrade() else { return };
            match texture {
                Some(texture) => art.show_texture(&texture, instant),
                None => art.try_next(index + 1),
            }
        });
    }

    fn show_texture(&self, texture: &gtk::gdk::Texture, instant: bool) {
        let imp = self.imp();
        if imp.logo_box.get().is_some() && texture.height() > 0 {
            imp.aspect
                .set(texture.width() as f64 / texture.height() as f64);
            self.queue_resize();
        }
        imp.picture.set_paintable(Some(texture));
        imp.loaded.set(true);
        if let Some(label) = imp.label.borrow().as_ref() {
            label.set_visible(false);
        }
        if instant {
            self.add_css_class("instant");
        }
        self.add_css_class("loaded");
        if let Some(f) = imp.on_result.borrow().as_ref() {
            f(self, true);
        }
    }
}
