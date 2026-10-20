//! Checks that a generated sysroot is equivalent to a copy of the distribution.
//!
//! Remote executors receive Bazel's symlink artifacts as plain files at the
//! symlink's path, so a generated tree must be complete without the files its
//! symlinks point at. The test copies the sysroot named by `SYSROOT_ANCHOR`
//! into a scratch directory, dereferencing every symlink, and then:
//!
//! * runs `rustc` from the copy: it must load `librustc_driver` from `../lib`
//!   (`rustc_driver.dll` beside it on Windows) and report the copy as its
//!   sysroot;
//! * compiles against the copy's standard library with `--sysroot`;
//! * for a rustdoc sysroot, builds a doctest, which makes rustdoc run the
//!   `rustc` beside itself; for a clippy sysroot, compiles with
//!   `clippy-driver`;
//! * compares the copy's standard library with the distribution's, found
//!   beside the rlib named by `REAL_STD`, byte for byte, at the same relative
//!   paths.

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
        assert!(
            !metadata.file_type().is_symlink(),
            "{} is a symlink",
            path.display()
        );
        if metadata.is_dir() {
            assert_no_symlinks(&path);
        }
    }
}

fn run(command: &mut Command) -> String {
    // Nothing from the environment may help the tools find their libraries,
    // and nothing from the test harness may steer them. Clippy in particular
    // looks for a `clippy.toml` under `CARGO_MANIFEST_DIR` and fails when the
    // directory the test runner names does not exist under the working
    // directory, as on Windows, where tests run without a runfiles tree.
    command
        .env_remove("LD_LIBRARY_PATH")
        .env_remove("DYLD_LIBRARY_PATH")
        .env_remove("DYLD_FALLBACK_LIBRARY_PATH")
        .env_remove("CARGO_MANIFEST_DIR")
        .env_remove("CLIPPY_CONF_DIR");
    let output = command
        .output()
        .unwrap_or_else(|e| panic!("failed to run {command:?}: {e}"));
    let stdout = String::from_utf8_lossy(&output.stdout).into_owned();
    let stderr = String::from_utf8_lossy(&output.stderr);
    assert!(
        output.status.success(),
        "{command:?} failed:\n{stdout}\n{stderr}"
    );
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
    // One rlib of the distribution's standard library. The rest of the
    // library is in the same directory, `lib/rustlib/<triple>/lib`.
    let real_std = rlocation!(runfiles, env::var("REAL_STD").unwrap()).unwrap();
    let real_std_dir = real_std.parent().unwrap().to_path_buf();
    let triple = real_std_dir
        .parent()
        .unwrap()
        .file_name()
        .unwrap()
        .to_owned();

    let copy = PathBuf::from(env::var("TEST_TMPDIR").unwrap()).join("sysroot");
    copy_dereferenced(&sysroot, &copy);
    assert_no_symlinks(&copy);
    let bin = copy.join("bin");

    // The layout: `bin/` beside `lib/`, the compiler libraries where the
    // dynamic loader finds them from `bin/` (`lib/` on Unix, `bin/` itself on
    // Windows), and the standard library under `lib/rustlib/<triple>/lib`.
    let mut copied = Vec::new();
    walk(&copy, &mut copied);
    let relative = |path: &Path| path.strip_prefix(&copy).unwrap().to_path_buf();
    let (driver_dir, driver_prefix) = if cfg!(windows) {
        ("bin", "rustc_driver-")
    } else {
        ("lib", "librustc_driver-")
    };
    assert!(
        copied.iter().any(|f| {
            let r = relative(f);
            r.parent() == Some(Path::new(driver_dir))
                && r.file_name()
                    .unwrap()
                    .to_str()
                    .unwrap()
                    .starts_with(driver_prefix)
        }),
        "no {driver_prefix}* in {driver_dir}/"
    );
    assert!(
        copied.iter().any(|f| {
            let r = relative(f);
            r.starts_with("lib/rustlib") && r.extension().is_some_and(|e| e == "rlib")
        }),
        "no standard library under lib/rustlib"
    );

    // `rustc` loads `librustc_driver` from `../lib` and derives its default
    // sysroot from there: the copy, not the original tree.
    let printed = run(Command::new(bin.join(exe("rustc")))
        .arg("--print")
        .arg("sysroot"));
    assert_eq!(
        fs::canonicalize(printed.trim()).unwrap(),
        fs::canonicalize(&copy).unwrap()
    );

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
            assert!(
                report.contains("1 passed"),
                "doctest should have run: {report}"
            );
        }
        "clippy" => {
            run(Command::new(bin.join(exe("clippy-driver"))).arg("--version"));
            compile("clippy-driver");
        }
        other => panic!("unknown sysroot kind {other}"),
    }

    // Vendoring equivalence: every library of the distribution's standard
    // library is in the copy at the same relative path with the same bytes.
    // The compiler's own libraries are covered by the tools having run.
    let copied_std_dir = copy.join("lib").join("rustlib").join(&triple).join("lib");
    let mut real_files = Vec::new();
    walk(&real_std_dir, &mut real_files);
    let mut compared = 0;
    for real_file in real_files {
        let relative = real_file.strip_prefix(&real_std_dir).unwrap();
        let is_library = relative
            .extension()
            .is_some_and(|e| LIBRARY_EXTENSIONS.iter().any(|x| e == *x));
        if !is_library {
            continue;
        }
        let copied_file = copied_std_dir.join(relative);
        assert!(
            copied_file.is_file(),
            "lib/rustlib/{}/lib/{} is missing from the sysroot",
            triple.to_string_lossy(),
            relative.display()
        );
        assert!(
            fs::read(&real_file).unwrap() == fs::read(&copied_file).unwrap(),
            "lib/rustlib/{}/lib/{} differs from the distribution",
            triple.to_string_lossy(),
            relative.display()
        );
        compared += 1;
    }
    assert!(
        compared > 10,
        "expected to compare the distribution's standard library, compared {compared}"
    );
}
