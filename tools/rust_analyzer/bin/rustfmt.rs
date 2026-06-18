//! Stable entry point that locates the `rustfmt` binary from the registered
//! `rustfmt_toolchain` and `exec`s it. rust-analyzer pipes file contents to
//! this command on stdin and reads formatted output from stdout; pointing
//! `rust-analyzer.rustfmt.overrideCommand` at this wrapper guarantees the
//! formatter version matches the Bazel toolchain and lets users format
//! without ever installing rustfmt on the host.

use std::process::Command;

use runfiles::{rlocation, Runfiles};

fn main() {
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
