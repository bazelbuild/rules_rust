//! Stable entry point that locates the `rust-analyzer-proc-macro-srv` binary
//! from the registered `rust_analyzer_toolchain` and `exec`s it.
//!
//! For editors that run a separate proc-macro server (via
//! `rust-analyzer.procMacro.server`), pointing at
//! `bazel-bin/tools/rust_analyzer/rust_analyzer_proc_macro_srv` guarantees
//! the server's ABI matches the Bazel-built rustc, avoiding the silent
//! expansion failures that arise when an editor-bundled proc-macro-srv is
//! mismatched against the project's compiler.

use std::path::PathBuf;
use std::process::Command;

use runfiles::{rlocation, Runfiles};

/// See `rust_analyzer.rs` for the rationale; mirrors the same fallback so
/// editors that spawn the wrapper directly don't trip RunfilesDirNotFound.
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
        eprintln!("rust_analyzer_proc_macro_srv wrapper: failed to create runfiles: {e}");
        std::process::exit(1);
    });

    let proc_macro_srv = rlocation!(
        runfiles,
        env!("RUST_ANALYZER_PROC_MACRO_SRV_RLOCATIONPATH")
    )
    .unwrap_or_else(|| {
        eprintln!(
            "rust_analyzer_proc_macro_srv wrapper: could not locate proc-macro-srv via runfiles ({})",
            env!("RUST_ANALYZER_PROC_MACRO_SRV_RLOCATIONPATH")
        );
        std::process::exit(1);
    });

    let args: Vec<String> = std::env::args().skip(1).collect();
    let mut cmd = Command::new(&proc_macro_srv);
    cmd.args(&args);

    #[cfg(unix)]
    {
        use std::os::unix::process::CommandExt;
        let err = cmd.exec();
        eprintln!(
            "rust_analyzer_proc_macro_srv wrapper: exec({}) failed: {err}",
            proc_macro_srv.display()
        );
        std::process::exit(1);
    }

    #[cfg(not(unix))]
    {
        let status = cmd.status().unwrap_or_else(|e| {
            eprintln!(
                "rust_analyzer_proc_macro_srv wrapper: spawn({}) failed: {e}",
                proc_macro_srv.display()
            );
            std::process::exit(1);
        });
        std::process::exit(status.code().unwrap_or(1));
    }
}
