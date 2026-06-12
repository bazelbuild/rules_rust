//! Stable entry point that locates the `rustfmt` binary from the registered
//! `rustfmt_toolchain` and `exec`s it. rust-analyzer pipes file contents to
//! this command on stdin and reads formatted output from stdout; pointing
//! `rust-analyzer.rustfmt.overrideCommand` at this wrapper guarantees the
//! formatter version matches the Bazel toolchain and lets users format
//! without ever installing rustfmt on the host.

use std::path::PathBuf;
use std::process::Command;

use runfiles::{rlocation, Runfiles};

/// Mirror of the same helper in `rust_analyzer.rs`. Editors spawn the
/// underlying binary directly (no `bazel run`), so we have to find our
/// runfiles via the `.runfiles_manifest` file sitting next to argv[0]
/// — `Runfiles::create()` only looks at env vars and a `.runfiles/` dir.
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
        eprintln!("rustfmt wrapper: failed to create runfiles: {e}");
        std::process::exit(1);
    });

    let rustfmt = rlocation!(runfiles, env!("RUSTFMT_RLOCATIONPATH")).unwrap_or_else(|| {
        eprintln!(
            "rustfmt wrapper: could not locate rustfmt via runfiles ({})",
            env!("RUSTFMT_RLOCATIONPATH")
        );
        std::process::exit(1);
    });

    let args: Vec<String> = std::env::args().skip(1).collect();
    let mut cmd = Command::new(&rustfmt);
    cmd.args(&args);

    #[cfg(unix)]
    {
        use std::os::unix::process::CommandExt;
        let err = cmd.exec();
        eprintln!("rustfmt wrapper: exec({}) failed: {err}", rustfmt.display());
        std::process::exit(1);
    }

    #[cfg(not(unix))]
    {
        let status = cmd.status().unwrap_or_else(|e| {
            eprintln!("rustfmt wrapper: spawn({}) failed: {e}", rustfmt.display());
            std::process::exit(1);
        });
        std::process::exit(status.code().unwrap_or(1));
    }
}
