//! Checks the `CARGO` a build script is given.

use std::env;
use std::path::Path;

fn main() {
    let cargo = env::var("CARGO").expect("`cargo_build_script` sets `CARGO`");
    assert!(
        Path::new(&cargo).is_file(),
        "`CARGO` should name an existing file, got `{cargo}`"
    );

    // The `cargo_toolchain` points at the distribution's own `bin/cargo`.
    // The deprecated `rust_toolchain.cargo` is a symlink inside the
    // generated sysroot, under a `rust_toolchain/` directory.
    assert!(
        !cargo.replace('\\', "/").contains("/rust_toolchain/"),
        "`CARGO` should come from the `cargo_toolchain`, not the `rust_toolchain` sysroot, got `{cargo}`"
    );

    println!("cargo:rustc-env=CARGO_FROM_BUILD_SCRIPT={cargo}");
}
