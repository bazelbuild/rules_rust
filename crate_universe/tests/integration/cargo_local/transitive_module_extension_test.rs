//! Spawn the binary defined in the transitively-depended
//! `cu_test_complicated_dependencies` module. That module declares
//! `crate.from_specs(name = "complicated_dependencies", ...)` with
//! `crate.annotation(label_injections = ...)` for openssl-sys — but this
//! root module never calls `use_extension` on it. A successful spawn with
//! an OpenSSL version banner on stdout proves the transitively-declared
//! crate_universe extension was invoked, its hub repo rendered, the
//! annotation-injected `@openssl` label propagated to the build script, and
//! the resulting binary linked and ran end-to-end.
//!
//! This root module also `single_version_override`s `openssl` to a different
//! BCR revision than `complicated_dependencies` declared. The build must
//! still succeed without re-pinning `complicated_dependencies`'s lockfile —
//! label_injection's apparent -> canonical substitution is deferred from
//! repin-time to per-session render-time (see
//! `crate_universe/src/config/label_injection.rs`), so the lockfile carries
//! apparent labels and adapts to whatever the current bazel session resolved.
//!
//! Note: this test lives in `cargo_local` rather than in its own module so
//! that one CI job exercises both crate_universe's `from_cargo` resolution
//! (used by `cargo_local`'s own root extension) and a transitively-fetched
//! `from_specs` extension that survives a root-driven override.

use std::process::Command;

use runfiles::{rlocation, Runfiles};

#[test]
fn transitive_binary_prints_openssl_version() {
    let r = Runfiles::create().expect("failed to initialize runfiles");
    let exe = rlocation!(r, env!("EXECUTABLE_RLOCATIONPATH"))
        .expect("failed to resolve transitive binary via runfiles");

    let output = Command::new(&exe)
        .output()
        .expect("failed to spawn transitively-fetched binary");

    assert!(
        output.status.success(),
        "binary exited non-zero: {:?}\nstderr: {}",
        output.status,
        String::from_utf8_lossy(&output.stderr),
    );

    let stdout = String::from_utf8(output.stdout).expect("stdout was not valid UTF-8");
    assert!(
        stdout.starts_with("OpenSSL "),
        "expected OpenSSL version banner, got: {:?}",
        stdout,
    );
}
