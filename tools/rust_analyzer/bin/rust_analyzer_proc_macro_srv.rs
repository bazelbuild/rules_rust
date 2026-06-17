//! Stable entry point that locates the `rust-analyzer-proc-macro-srv` binary
//! from the registered `rust_analyzer_toolchain` and `exec`s it.
//!
//! For editors that run a separate proc-macro server (via
//! `rust-analyzer.procMacro.server`), pointing at
//! `bazel-bin/tools/rust_analyzer/rust_analyzer_proc_macro_srv` guarantees
//! the server's ABI matches the Bazel-built rustc, avoiding the silent
//! expansion failures that arise when an editor-bundled proc-macro-srv is
//! mismatched against the project's compiler.

use std::process::Command;

use runfiles::{rlocation, Runfiles};

fn main() {
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
