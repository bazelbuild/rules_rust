//! A module containing common test helpers

pub fn mock_cargo_metadata_package() -> cargo_metadata::Package {
    serde_json::from_value(serde_json::json!({
        "name": "mock-pkg",
        "version": "3.3.3",
        "id": "mock-pkg 3.3.3 (registry+https://github.com/rust-lang/crates.io-index)",
        "license": "Unlicense/MIT",
        "license_file": null,
        "description": "Fast multiple substring searching.",
        "source": "registry+https://github.com/rust-lang/crates.io-index",
        "dependencies": [],
        "targets": [],
        "features": {},
        "manifest_path": "/tmp/mock-pkg-3.3.3/Cargo.toml",
        "metadata": null,
        "publish": null,
        "authors": [],
        "categories": [],
        "keywords": [],
        "readme": "README.md",
        "repository": "",
        "homepage": "",
        "documentation": null,
        "edition": "2021",
        "links": null,
        "default_run": null
    }))
    .unwrap()
}

pub fn mock_cargo_lock_package() -> cargo_lock::Package {
    toml::from_str(&textwrap::dedent(
        r#"
        name = "mock-pkg"
        version = "3.3.3"
        source = "registry+https://github.com/rust-lang/crates.io-index"
        checksum = "ee49baf6cb617b853aa8d93bf420db2383fab46d314482ca2803b40d5fde979b"
        dependencies = []
        "#,
    ))
    .unwrap()
}

pub mod metadata {
    pub fn alias() -> cargo_metadata::Metadata {
        serde_json::from_str(include_str!(concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/test_data/metadata/aliases/metadata.json"
        )))
        .unwrap()
    }

    pub fn build_scripts() -> cargo_metadata::Metadata {
        serde_json::from_str(include_str!(concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/test_data/metadata/build_scripts/metadata.json"
        )))
        .unwrap()
    }

    pub fn crate_types() -> cargo_metadata::Metadata {
        serde_json::from_str(include_str!(concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/test_data/metadata/crate_types/metadata.json"
        )))
        .unwrap()
    }

    pub fn multi_cfg_dep() -> cargo_metadata::Metadata {
        serde_json::from_str(include_str!(concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/test_data/metadata/multi_cfg_dep/metadata.json"
        )))
        .unwrap()
    }

    pub fn no_deps() -> cargo_metadata::Metadata {
        serde_json::from_str(include_str!(concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/test_data/metadata/no_deps/metadata.json"
        )))
        .unwrap()
    }

    pub fn optional_deps_disabled() -> cargo_metadata::Metadata {
        serde_json::from_str(include_str!(concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/test_data/metadata/crate_optional_deps_disabled/metadata.json"
        )))
        .unwrap()
    }

    pub fn optional_deps_enabled() -> cargo_metadata::Metadata {
        serde_json::from_str(include_str!(concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/test_data/metadata/crate_optional_deps_enabled/metadata.json"
        )))
        .unwrap()
    }

    pub fn common() -> cargo_metadata::Metadata {
        serde_json::from_str(include_str!(concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/test_data/metadata/common/metadata.json"
        )))
        .unwrap()
    }

    pub fn git_repos() -> cargo_metadata::Metadata {
        serde_json::from_str(include_str!(concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/test_data/metadata/git_repos/metadata.json"
        )))
        .unwrap()
    }

    pub fn has_package_metadata() -> cargo_metadata::Metadata {
        serde_json::from_str(include_str!(concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/test_data/metadata/has_package_metadata/metadata.json"
        )))
        .unwrap()
    }
}

pub mod lockfile {
    use std::str::FromStr;

    pub fn alias() -> cargo_lock::Lockfile {
        cargo_lock::Lockfile::from_str(include_str!(concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/test_data/metadata/aliases/Cargo.lock"
        )))
        .unwrap()
    }

    pub fn build_scripts() -> cargo_lock::Lockfile {
        cargo_lock::Lockfile::from_str(include_str!(concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/test_data/metadata/build_scripts/Cargo.lock"
        )))
        .unwrap()
    }

    pub fn crate_types() -> cargo_lock::Lockfile {
        cargo_lock::Lockfile::from_str(include_str!(concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/test_data/metadata/crate_types/Cargo.lock"
        )))
        .unwrap()
    }

    pub fn multi_cfg_dep() -> cargo_lock::Lockfile {
        cargo_lock::Lockfile::from_str(include_str!(concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/test_data/metadata/multi_cfg_dep/Cargo.lock"
        )))
        .unwrap()
    }

    pub fn no_deps() -> cargo_lock::Lockfile {
        cargo_lock::Lockfile::from_str(include_str!(concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/test_data/metadata/no_deps/Cargo.lock"
        )))
        .unwrap()
    }

    pub fn common() -> cargo_lock::Lockfile {
        cargo_lock::Lockfile::from_str(include_str!(concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/test_data/metadata/common/Cargo.lock"
        )))
        .unwrap()
    }

    pub fn git_repos() -> cargo_lock::Lockfile {
        cargo_lock::Lockfile::from_str(include_str!(concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/test_data/metadata/git_repos/Cargo.lock"
        )))
        .unwrap()
    }

    pub fn has_package_metadata() -> cargo_lock::Lockfile {
        cargo_lock::Lockfile::from_str(include_str!(concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/test_data/metadata/has_package_metadata/Cargo.lock"
        )))
        .unwrap()
    }
}
