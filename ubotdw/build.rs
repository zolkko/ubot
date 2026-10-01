use std::env;
use std::path::PathBuf;

fn main() {
    let crate_dir = env::var("CARGO_MANIFEST_DIR").unwrap();
    let out_dir = PathBuf::from(&crate_dir).join("include");

    std::fs::create_dir_all(&out_dir).expect("failed to create include dir");

    cbindgen::Builder::new()
        .with_crate(&crate_dir)
        .with_config(
            cbindgen::Config::from_file("cbindgen.toml").expect("failed to read cbindgen.toml"),
        )
        .generate()
        .expect("failed to generate C bindings")
        .write_to_file(out_dir.join("ubotdw.h"));
}
