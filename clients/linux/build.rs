fn main() {
    // Bundles style.css and the symbolic icons into a GResource. Needs the
    // `glib-compile-resources` tool (libglib2.0-dev-bin / glib2-devel / brew glib).
    glib_build_tools::compile_resources(
        &["data"],
        "data/resources.gresource.xml",
        "resources.gresource",
    );
    println!("cargo:rerun-if-changed=../../data/snapshot.json");
}
