extern crate cargo_bazel;
extern crate serde_json;
extern crate tempfile;

use anyhow::{ensure, Context, Result};
use cargo_bazel::cli::{splice, SpliceOptions};
use serde_json::{json, Value};
use std::collections::HashMap;
use std::env;
use std::fs;
use std::path::PathBuf;

fn setup_cargo_env() -> Result<(PathBuf, PathBuf)> {
    let cargo = std::fs::canonicalize(PathBuf::from(
        env::var("CARGO").context("CARGO environment variable must be set.")?,
    ))
    .unwrap();
    let rustc = std::fs::canonicalize(PathBuf::from(
        env::var("RUSTC").context("RUSTC environment variable must be set.")?,
    ))
    .unwrap();
    ensure!(cargo.exists());
    ensure!(rustc.exists());
    // If $RUSTC is a relative path it can cause issues with
    // `cargo_metadata::MetadataCommand`. Just to be on the safe side, we make
    // both of these env variables absolute paths.
    if cargo != PathBuf::from(env::var("CARGO").unwrap()) {
        env::set_var("CARGO", cargo.as_os_str());
    }
    if rustc != PathBuf::from(env::var("RUSTC").unwrap()) {
        env::set_var("RUSTC", rustc.as_os_str());
    }

    let cargo_home = PathBuf::from(
        env::var("TEST_TMPDIR").context("TEST_TMPDIR environment variable must be set.")?,
    )
    .join("cargo_home");
    env::set_var("CARGO_HOME", cargo_home.as_os_str());
    fs::create_dir_all(&cargo_home)?;

    println!("$RUSTC={}", rustc.display());
    println!("$CARGO={}", cargo.display());
    println!("$CARGO_HOME={}", cargo_home.display());

    Ok((cargo, rustc))
}

fn run(repository_name: &str, manifests: HashMap<String, String>, lockfile: &str) -> Value {
    let (cargo, rustc) = setup_cargo_env().unwrap();

    let scratch = tempfile::tempdir().unwrap();
    let runfiles = runfiles::Runfiles::create().unwrap();

    /*
    let manifest_path = scratch.path().join("Cargo.toml");
    fs::copy(
        runfiles.rlocation(manifest),
        manifest_path,
    )
    .unwrap();
    */

    let splicing_manifest = scratch.path().join("splicing_manifest.json");
    fs::write(
        &splicing_manifest,
        serde_json::to_string(&json!({
            "manifests": manifests,
            "direct_packages": {},
            "resolver_version": "2"
        }))
        .unwrap(),
    )
    .unwrap();

    let config = scratch.path().join("config.json");
    fs::write(
        &config,
        serde_json::to_string(&json!({
            "generate_binaries": false,
            "generate_build_scripts": false,
            "rendering": {
                "repository_name": repository_name,
                "regen_command": "//crate_universe:cargo_integration_test"
            },
            "supported_platform_triples": [
                "x86_64-apple-darwin",
                "x86_64-pc-windows-msvc",
                "x86_64-unknown-linux-gnu",
            ]
        }))
        .unwrap(),
    )
    .unwrap();

    splice(SpliceOptions {
        splicing_manifest,
        cargo_lockfile: Some(runfiles.rlocation(lockfile)),
        repin: None,
        workspace_dir: None,
        output_dir: scratch.path().join("out"),
        dry_run: false,
        cargo_config: None,
        config,
        cargo,
        rustc,
    })
    .unwrap();

    let metadata = serde_json::from_str::<Value>(
        &fs::read_to_string(scratch.path().join("out").join("metadata.json")).unwrap(),
    )
    .unwrap();

    metadata
}

// See crate_universe/test_data/metadata/target_features/Cargo.toml for input.
#[test]
fn feature_generator() {
    // This test case requires network access to build pull crate metadata
    // so that we can actually run `cargo tree`. However, RBE (and perhaps
    // other environments) disallow or don't support this. In those cases,
    // we just skip this test case.
    use std::net::ToSocketAddrs;
    if "github.com:443".to_socket_addrs().is_err() {
        eprintln!("This test case requires network access. Skipping!");
        return;
    }

    let runfiles = runfiles::Runfiles::create().unwrap();
    let metadata = run(
        "target_feature_test",
        HashMap::from([(
            runfiles
                .rlocation(
                    "rules_rust/crate_universe/test_data/metadata/target_features/Cargo.toml",
                )
                .to_string_lossy()
                .to_string(),
            "//:test_input".to_string(),
        )]),
        "rules_rust/crate_universe/test_data/metadata/target_features/Cargo.lock",
    );

    assert_eq!(
        metadata["metadata"]["cargo-bazel"]["features"]["wgpu-hal 0.14.1"],
        json!({
            "selects": {
                "x86_64-apple-darwin": [
                    "block", "foreign-types", "metal",
                ],
                "x86_64-pc-windows-msvc": [
                    "ash", "bit-set", "dx11", "dx12", "gpu-alloc",
                    "gpu-descriptor", "libloading", "native", "range-alloc",
                    "renderdoc", "renderdoc-sys", "smallvec", "vulkan",
                ],
                "x86_64-unknown-linux-gnu": [
                    "ash", "egl", "gles", "glow", "gpu-alloc",
                    "gpu-descriptor", "libloading", "renderdoc", "renderdoc-sys",
                    "smallvec", "vulkan",
                ],
            },
            "common": [
                "default",
            ],
        })
    );
}

// See crate_universe/test_data/metadata/target_cfg_features/Cargo.toml for input.
#[test]
fn feature_generator_cfg_features() {
    // This test case requires network access to build pull crate metadata
    // so that we can actually run `cargo tree`. However, RBE (and perhaps
    // other environments) disallow or don't support this. In those cases,
    // we just skip this test case.
    use std::net::ToSocketAddrs;
    if "github.com:443".to_socket_addrs().is_err() {
        eprintln!("This test case requires network access. Skipping!");
        return;
    }

    let runfiles = runfiles::Runfiles::create().unwrap();
    let metadata = run(
        "target_cfg_features_test",
        HashMap::from([(
            runfiles
                .rlocation(
                    "rules_rust/crate_universe/test_data/metadata/target_cfg_features/Cargo.toml",
                )
                .to_string_lossy()
                .to_string(),
            "//:test_input".to_string(),
        )]),
        "rules_rust/crate_universe/test_data/metadata/target_cfg_features/Cargo.lock",
    );

    assert_eq!(
        metadata["metadata"]["cargo-bazel"]["features"],
        json!({
            "target_cfg_features 0.1.0": {
                "common": [],
                "selects": {}
            },
            "autocfg 1.1.0": {
                "common": [],
                "selects": {}
            },
            "pin-project-lite 0.2.9": {
                "common": [],
                "selects": {}
            },
            "tokio 1.25.0": {
                "common": ["default"],
                "selects": {
                    // Note: "x86_64-pc-windows-msvc" is *not* here, despite
                    // being included in `supported_platform_triples` above!
                    "x86_64-apple-darwin": ["fs"],
                    "x86_64-unknown-linux-gnu": ["fs"]
                }
            }
        })
    );
}

#[test]
fn feature_generator_workspace() {
    // This test case requires network access to build pull crate metadata
    // so that we can actually run `cargo tree`. However, RBE (and perhaps
    // other environments) disallow or don't support this. In those cases,
    // we just skip this test case.
    use std::net::ToSocketAddrs;
    if "github.com:443".to_socket_addrs().is_err() {
        eprintln!("This test case requires network access. Skipping!");
        return;
    }

    let runfiles = runfiles::Runfiles::create().unwrap();
    let metadata = run(
        "workspace_test",
        HashMap::from([
            (
                runfiles
                    .rlocation("rules_rust/crate_universe/test_data/metadata/workspace/Cargo.toml")
                    .to_string_lossy()
                    .to_string(),
                "//:test_input".to_string(),
            ),
            (
                runfiles
                    .rlocation(
                        "rules_rust/crate_universe/test_data/metadata/workspace/child/Cargo.toml",
                    )
                    .to_string_lossy()
                    .to_string(),
                "//crate_universe:test_data/metadata/workspace/child/Cargo.toml".to_string(),
            ),
        ]),
        "rules_rust/crate_universe/test_data/metadata/workspace/Cargo.lock",
    );

    assert!(!metadata["metadata"]["cargo-bazel"]["features"]["wgpu 0.14.0"].is_null());
}

#[test]
fn feature_generator_crate_combined_features() {
    // This test case requires network access to build pull crate metadata
    // so that we can actually run `cargo tree`. However, RBE (and perhaps
    // other environments) disallow or don't support this. In those cases,
    // we just skip this test case.
    use std::net::ToSocketAddrs;
    if "github.com:443".to_socket_addrs().is_err() {
        eprintln!("This test case requires network access. Skipping!");
        return;
    }

    let runfiles = runfiles::Runfiles::create().unwrap();
    let metadata = run(
        "crate_combined_features",
        HashMap::from([
            (
                runfiles
                    .rlocation("rules_rust/crate_universe/test_data/metadata/crate_combined_features/Cargo.toml")
                    .to_string_lossy()
                    .to_string(),
                "//:test_input".to_string(),
            )
        ]),
        "rules_rust/crate_universe/test_data/metadata/crate_combined_features/Cargo.lock",
    );

    // serde appears twice in the list of dependencies, with and without derive features
    assert_eq!(
        metadata["metadata"]["cargo-bazel"]["features"]["serde 1.0.158"]["common"],
        json!(["default", "derive", "serde_derive", "std"])
    );
}
