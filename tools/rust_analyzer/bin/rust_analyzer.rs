//! Stable entry point that locates the `rust-analyzer` binary from the
//! registered `rust_analyzer_toolchain` and `exec`s it. Pointing an editor at
//! `bazel-bin/tools/rust_analyzer/rust_analyzer` guarantees the LSP server
//! is the one matched to the Bazel rustc/sysroot/proc-macro-srv, instead of
//! whatever the editor extension shipped with.
//!
//! All command-line arguments and stdio are forwarded unchanged so the LSP
//! protocol passes through transparently.

use std::path::PathBuf;
use std::process::Command;

use runfiles::{rlocation, Runfiles};

/// Set `RUNFILES_MANIFEST_FILE` if the binary was launched directly (no
/// `bazel run`) and the manifest file sits next to argv[0]. Without this the
/// runfiles crate hits `RunfilesDirNotFound` because Bazel only materializes
/// the `.runfiles/` directory on the `run` action, not the build action.
fn ensure_runfiles_env() {
    if std::env::var_os("RUNFILES_MANIFEST_FILE").is_some()
        || std::env::var_os("RUNFILES_DIR").is_some()
        || std::env::var_os("TEST_SRCDIR").is_some()
    {
        return;
    }
    let argv0 = std::env::args_os().next().unwrap_or_default();
    let exe = PathBuf::from(argv0);
    let dir = match exe.parent() {
        Some(d) => d,
        None => return,
    };
    let file_name = match exe.file_name() {
        Some(n) => n.to_owned(),
        None => return,
    };
    let mut manifest_name = file_name;
    manifest_name.push(".runfiles_manifest");
    let manifest_path = dir.join(&manifest_name);
    if manifest_path.is_file() {
        std::env::set_var("RUNFILES_MANIFEST_FILE", manifest_path);
    }
}

fn main() {
    ensure_runfiles_env();
    let runfiles = Runfiles::create().unwrap_or_else(|e| {
        eprintln!("rust_analyzer wrapper: failed to create runfiles: {e}");
        std::process::exit(1);
    });

    let rust_analyzer =
        rlocation!(runfiles, env!("RUST_ANALYZER_RLOCATIONPATH")).unwrap_or_else(|| {
            eprintln!(
                "rust_analyzer wrapper: could not locate rust-analyzer via runfiles ({})",
                env!("RUST_ANALYZER_RLOCATIONPATH")
            );
            std::process::exit(1);
        });

    let args: Vec<String> = std::env::args().skip(1).collect();
    let mut cmd = Command::new(&rust_analyzer);
    cmd.args(&args);

    #[cfg(unix)]
    {
        use std::os::unix::process::CommandExt;
        // `exec` replaces this process so the LSP client talks directly to
        // rust-analyzer without an intermediate parent buffering stdio.
        let err = cmd.exec();
        eprintln!(
            "rust_analyzer wrapper: exec({}) failed: {err}",
            rust_analyzer.display()
        );
        std::process::exit(1);
    }

    #[cfg(not(unix))]
    {
        // On Windows there's no exec(); spawn and forward the exit code.
        let status = cmd.status().unwrap_or_else(|e| {
            eprintln!(
                "rust_analyzer wrapper: spawn({}) failed: {e}",
                rust_analyzer.display()
            );
            std::process::exit(1);
        });
        std::process::exit(status.code().unwrap_or(1));
    }
}
