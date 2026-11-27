//! Compiles C the way cc-rs does (absolute source path, output in `OUT_DIR`)
//! and checks that the exec root does not leak into the object.

use std::path::PathBuf;
use std::process::Command;

fn main() {
    let out_dir = std::env::var("OUT_DIR").unwrap();
    let manifest_dir = PathBuf::from(std::env::var("CARGO_MANIFEST_DIR").unwrap());
    let exec_root = &out_dir[..out_dir
        .find("/bazel-out/")
        .unwrap_or_else(|| panic!("OUT_DIR is not under bazel-out: {out_dir}"))];

    let object = PathBuf::from(&out_dir).join("probe.o");
    let cflags = std::env::var("CFLAGS").unwrap();
    // Under `bazel coverage` the toolchain adds `--coverage`, which embeds the
    // absolute `.gcda` path. GCC only remaps that from 12 on
    // (`-fprofile-prefix-map`), so leave coverage out of this check.
    let flags = cflags
        .split_whitespace()
        .filter(|flag| !matches!(*flag, "--coverage" | "-fprofile-arcs" | "-ftest-coverage"));
    let status = Command::new(std::env::var("CC").unwrap())
        .args(flags)
        .args(["-g", "-c"])
        .arg(manifest_dir.join("probe.c"))
        .arg("-o")
        .arg(&object)
        .status()
        .unwrap();
    assert!(status.success(), "compiling probe.c failed: {status}");

    let bytes = std::fs::read(&object).unwrap();
    assert!(
        !bytes
            .windows(exec_root.len())
            .any(|window| window == exec_root.as_bytes()),
        "{} contains the exec root {exec_root}; CFLAGS={cflags}",
        object.display(),
    );
}
