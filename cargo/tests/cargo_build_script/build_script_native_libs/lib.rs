//! Native artifacts for `cargo_build_script` tests, produced with the tools
//! the build script environment provides (`RUSTC`, `AR`) so they are valid on
//! every platform CI runs. Hand-written archives are not: `link.exe` rejects
//! an archive that lacks the second linker member.

use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

fn run(command: &mut Command) {
    let status = command
        .status()
        .unwrap_or_else(|err| panic!("failed to run {command:?}: {err}"));
    assert!(status.success(), "{command:?} exited with {status}");
}

/// Compile an empty `#![no_std]` crate into `<dir>/<name>.o` and return it.
pub fn empty_object(dir: &Path, name: &str) -> PathBuf {
    let source = dir.join(format!("{name}.rs"));
    fs::write(&source, "#![no_std]\n").unwrap();
    let object = dir.join(format!("{name}.o"));
    let mut rustc = Command::new(env::var("RUSTC").expect("RUSTC is set for build scripts"));
    rustc
        .arg("--crate-type=lib")
        .arg("--emit=obj")
        .arg("-Ccodegen-units=1")
        .arg(format!("--crate-name={name}"))
        .arg("-o")
        .arg(&object)
        .arg(&source);
    if let Ok(target) = env::var("TARGET") {
        rustc.arg(format!("--target={target}"));
    }
    run(&mut rustc);
    object
}

/// Archive an empty object into a static library in `dir`, named so that
/// `-l static=<name>` finds it (`lib<name>.a`, or `<name>.lib` for MSVC), and
/// return its path.
pub fn empty_static_lib(dir: &Path, name: &str) -> PathBuf {
    let object = empty_object(dir, name);
    let msvc = env::var("CARGO_CFG_TARGET_ENV").as_deref() == Ok("msvc");
    let lib = if msvc {
        dir.join(format!("{name}.lib"))
    } else {
        dir.join(format!("lib{name}.a"))
    };
    // `cargo_build_script` exports the cc toolchain's archiver as `AR`, except
    // on macOS where the toolchain's `libtool` is dropped and `ar` from `PATH`
    // is the fallback.
    let archiver = env::var("AR").unwrap_or_else(|_| "ar".to_owned());
    let mut command = Command::new(archiver);
    if msvc {
        command
            .arg("/nologo")
            .arg(format!("/OUT:{}", lib.display()))
            .arg(&object);
    } else {
        command.arg("crs").arg(&lib).arg(&object);
    }
    run(&mut command);
    lib
}
