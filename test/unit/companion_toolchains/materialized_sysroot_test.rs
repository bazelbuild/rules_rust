//! Checks that a generated sysroot is equivalent to a copy of the distribution.
//!
//! Remote executors receive Bazel's symlink artifacts as plain files at the
//! symlink's path, so a generated tree must be complete without the files its
//! symlinks point at. The test copies the sysroot named by `SYSROOT_ANCHOR`
//! into a scratch directory, dereferencing every symlink, and then:
//!
//! * runs `rustc` from the copy: it must load `librustc_driver` from `../lib`
//!   and report the copy as its sysroot;
//! * compiles against the copy's standard library with `--sysroot`;
//! * for a rustdoc sysroot, builds a doctest, which makes rustdoc run the
//!   `rustc` beside itself; for a clippy sysroot, compiles with
//!   `clippy-driver`;
//! * compares the copy's libraries with the downloaded distribution named by
//!   `REAL_RUSTC`, byte for byte, at the same relative paths.

use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

use runfiles::{rlocation, Runfiles};

fn copy_dereferenced(src: &Path, dst: &Path) {
    fs::create_dir_all(dst).unwrap();
    for entry in fs::read_dir(src).unwrap() {
        let entry = entry.unwrap();
        let target = dst.join(entry.file_name());
        // `metadata` follows symlinks: directories are recursed into and files
        // copied by content, so no symlink survives in `dst`.
        if entry.path().metadata().unwrap().is_dir() {
            copy_dereferenced(&entry.path(), &target);
        } else {
            fs::copy(entry.path(), &target).unwrap();
        }
    }
}

fn walk(dir: &Path, files: &mut Vec<PathBuf>) {
    for entry in fs::read_dir(dir).unwrap() {
        let path = entry.unwrap().path();
        if path.metadata().unwrap().is_dir() {
            walk(&path, files);
        } else {
            files.push(path);
        }
    }
}

fn assert_no_symlinks(dir: &Path) {
    for entry in fs::read_dir(dir).unwrap() {
        let path = entry.unwrap().path();
        let metadata = fs::symlink_metadata(&path).unwrap();
        assert!(!metadata.file_type().is_symlink(), "{} is a symlink", path.display());
        if metadata.is_dir() {
            assert_no_symlinks(&path);
        }
    }
}

fn run(command: &mut Command) -> String {
    // Nothing from the environment may help the tools find their libraries.
    command.env_remove("LD_LIBRARY_PATH").env_remove("DYLD_LIBRARY_PATH").env_remove("DYLD_FALLBACK_LIBRARY_PATH");
    let output = command.output().unwrap_or_else(|e| panic!("failed to run {command:?}: {e}"));
    let stdout = String::from_utf8_lossy(&output.stdout).into_owned();
    let stderr = String::from_utf8_lossy(&output.stderr);
    assert!(output.status.success(), "{command:?} failed:\n{stdout}\n{stderr}");
    stdout
}

fn exe(name: &str) -> String {
    format!("{name}{}", if cfg!(windows) { ".exe" } else { "" })
}

const LIBRARY_EXTENSIONS: &[&str] = &["so", "dylib", "dll", "rlib", "rmeta", "a", "o"];

#[test]
fn sysroot_is_equivalent_to_a_copied_distribution() {
    let runfiles = Runfiles::create().unwrap();
    let kind = env::var("KIND").unwrap();
    // The anchor resolves to the generated sysroot itself, in the output
    // tree, whether runfiles are a symlink tree or a manifest, so the tree is
    // walked there rather than through runfiles.
    let anchor = rlocation!(runfiles, env::var("SYSROOT_ANCHOR").unwrap()).unwrap();
    let sysroot = anchor.parent().unwrap().to_path_buf();
    let real = rlocation!(runfiles, env::var("REAL_RUSTC").unwrap()).unwrap();
    let real_root = real.parent().unwrap().parent().unwrap().to_path_buf();

    let copy = PathBuf::from(env::var("TEST_TMPDIR").unwrap()).join("sysroot");
    copy_dereferenced(&sysroot, &copy);
    assert_no_symlinks(&copy);
    let bin = copy.join("bin");

    // The layout: `bin/` beside `lib/`, the compiler libraries directly in
    // `lib/`, and the standard library under `lib/rustlib/<triple>/lib`.
    let mut copied = Vec::new();
    walk(&copy, &mut copied);
    let relative = |path: &Path| path.strip_prefix(&copy).unwrap().to_path_buf();
    assert!(copied.iter().any(|f| relative(f).to_str().unwrap().starts_with("lib/librustc_driver")), "no librustc_driver in lib/");
    assert!(copied.iter().any(|f| {
        let r = relative(f);
        r.starts_with("lib/rustlib") && r.extension().is_some_and(|e| e == "rlib")
    }), "no standard library under lib/rustlib");

    // `rustc` loads `librustc_driver` from `../lib` and derives its default
    // sysroot from there: the copy, not the original tree.
    let printed = run(Command::new(bin.join(exe("rustc"))).arg("--print").arg("sysroot"));
    assert_eq!(fs::canonicalize(printed.trim()).unwrap(), fs::canonicalize(&copy).unwrap());

    // The standard library resolves out of the copy through `--sysroot`.
    let lib_rs = copy.join("lib.rs");
    fs::write(&lib_rs, "pub fn documented() -> Vec<u8> { Vec::new() }\n").unwrap();
    let compile = |driver: &str| {
        run(Command::new(bin.join(exe(driver)))
            .arg("--sysroot")
            .arg(&copy)
            .arg("--edition=2021")
            .arg("--crate-type=lib")
            .arg("--emit=metadata")
            .arg("-o")
            .arg(copy.join(format!("{driver}.rmeta")))
            .arg(&lib_rs));
    };
    compile("rustc");

    match kind.as_str() {
        "rust" => {}
        "rustdoc" => {
            run(Command::new(bin.join(exe("rustdoc"))).arg("--version"));

            // A `compile_fail` doctest makes rustdoc run the `rustc` beside
            // itself without needing a linker.
            let doctest = copy.join("doctest.rs");
            fs::write(
                &doctest,
                "/// ```compile_fail\n/// let mistyped: u32 = \"not a number\";\n/// ```\npub fn documented() {}\n",
            )
            .unwrap();
            let report = run(Command::new(bin.join(exe("rustdoc")))
                .arg("--test")
                .arg("--edition=2021")
                .arg("--crate-name=doctest")
                .arg("--sysroot")
                .arg(&copy)
                .arg(&doctest));
            assert!(report.contains("1 passed"), "doctest should have run: {report}");
        }
        "clippy" => {
            run(Command::new(bin.join(exe("clippy-driver"))).arg("--version"));
            compile("clippy-driver");
        }
        other => panic!("unknown sysroot kind {other}"),
    }

    // Vendoring equivalence: every library of the downloaded distribution is
    // in the copy at the same relative path with the same bytes. Tool
    // directories under `lib/rustlib/<triple>/bin` are only present when a
    // toolchain declares a linker, so they are left out.
    let mut real_files = Vec::new();
    walk(&real_root.join("lib"), &mut real_files);
    let mut compared = 0;
    for real_file in real_files {
        let relative = real_file.strip_prefix(&real_root).unwrap();
        let is_library = relative.extension().is_some_and(|e| LIBRARY_EXTENSIONS.iter().any(|x| e == *x));
        let in_tool_dir = relative.components().any(|c| c.as_os_str() == "bin");
        if !is_library || in_tool_dir {
            continue;
        }
        let copied_file = copy.join(relative);
        assert!(copied_file.is_file(), "{} is missing from the sysroot", relative.display());
        assert!(
            fs::read(&real_file).unwrap() == fs::read(&copied_file).unwrap(),
            "{} differs from the distribution",
            relative.display()
        );
        compared += 1;
    }
    assert!(compared > 10, "expected to compare the distribution's libraries, compared {compared}");
    for binary in ["rustc"].iter().chain(match kind.as_str() {
        "rustdoc" => ["rustdoc"].iter(),
        "clippy" => ["clippy-driver"].iter(),
        _ => [].iter(),
    }) {
        let name = exe(binary);
        assert!(
            fs::read(real_root.join("bin").join(&name)).unwrap() == fs::read(bin.join(&name)).unwrap(),
            "bin/{name} differs from the distribution"
        );
    }
}
