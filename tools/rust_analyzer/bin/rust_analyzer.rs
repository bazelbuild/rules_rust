//! Stable entry point that locates the `rust-analyzer` binary from the
//! registered `rust_analyzer_toolchain` and `exec`s it. Pointing an editor at
//! `bazel-bin/tools/rust_analyzer/rust_analyzer` guarantees the LSP server
//! is the one matched to the Bazel rustc/sysroot/proc-macro-srv, instead of
//! whatever the editor extension shipped with.
//!
//! All command-line arguments and stdio are forwarded unchanged so the LSP
//! protocol passes through transparently.

use std::process::Command;

use runfiles::{rlocation, Runfiles};

fn main() {
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
