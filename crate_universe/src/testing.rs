use std::{collections::BTreeSet, fs::File, io::Write};

use indoc::{formatdoc, indoc};
use semver::Version;
use tempfile::TempDir;

use crate::{
    context::{
        BuildableTarget, CrateContext, CrateDependencyContext, GitRepo, LicenseData, SourceDetails,
    },
    metadata::{
        tests::{dummy_raze_metadata_fetcher, DummyCargoMetadataFetcher},
        RazeMetadata,
    },
};

pub(crate) fn lazy_static_crate_context(git: bool) -> CrateContext {
    let git_data = if git {
        Some(GitRepo {
            remote: String::from("https://github.com/rust-lang-nursery/lazy-static.rs.git"),
            commit: String::from("421669662b35fcb455f2902daed2e20bbbba79b6"),
            path_to_crate_root: None,
        })
    } else {
        None
    };

    CrateContext {
        pkg_name: String::from("lazy_static"),
        pkg_version: Version::parse("1.4.0").unwrap(),
        edition: String::from("2015"),
        raze_settings: Default::default(),
        canonical_additional_build_file: None,
        default_deps: CrateDependencyContext {
            dependencies: vec![],
            proc_macro_dependencies: vec![],
            data_dependencies: vec![],
            build_dependencies: vec![],
            build_proc_macro_dependencies: vec![],
            build_data_dependencies: vec![],
            dev_dependencies: vec![],
            aliased_dependencies: BTreeSet::new(),
        },
        source_details: SourceDetails { git_data },
        sha256: Some(String::from(
            "e2abad23fbc42b3700f2f279844dc832adb2b2eb069b2df918f455c4e18cc646",
        )),
        registry_url: String::from("https://registry.url/"),
        expected_build_path: String::from("UNUSED"),
        lib_target_name: Some(String::from("UNUSED")),
        license: LicenseData::default(),
        features: vec![],
        workspace_path_to_crate: String::from("UNUSED"),
        workspace_member_dependents: vec![],
        workspace_member_dev_dependents: vec![],
        workspace_member_build_dependents: vec![],
        is_workspace_member_dependency: false,
        targets: vec![BuildableTarget {
            kind: String::from("lib"),
            name: String::from("lazy_static"),
            path: String::from("src/lib.rs"),
            edition: String::from("2015"),
        }],
        build_script_target: None,
        targeted_deps: vec![],
        links: None,
        is_proc_macro: false,
    }
}

pub(crate) fn maplit_crate_context(git: bool) -> CrateContext {
    let git_data = if git {
        Some(GitRepo {
            remote: String::from("https://github.com/bluss/maplit.git"),
            commit: String::from("04936f703da907bc4ffdaced121e4cfd5ecbaec6"),
            path_to_crate_root: None,
        })
    } else {
        None
    };

    CrateContext {
        pkg_name: String::from("maplit"),
        pkg_version: Version::parse("1.0.2").unwrap(),
        edition: String::from("2015"),
        raze_settings: Default::default(),
        canonical_additional_build_file: None,
        default_deps: CrateDependencyContext {
            dependencies: vec![],
            proc_macro_dependencies: vec![],
            data_dependencies: vec![],
            build_dependencies: vec![],
            build_proc_macro_dependencies: vec![],
            build_data_dependencies: vec![],
            dev_dependencies: vec![],
            aliased_dependencies: BTreeSet::new(),
        },
        source_details: SourceDetails { git_data },
        sha256: Some(String::from(
            "3e2e65a1a2e43cfcb47a895c4c8b10d1f4a61097f9f254f183aee60cad9c651d",
        )),
        registry_url: String::from("https://registry.url/"),
        expected_build_path: String::from("UNUSED"),
        lib_target_name: Some(String::from("UNUSED")),
        license: LicenseData::default(),
        features: vec![],
        workspace_path_to_crate: String::from("UNUSED"),
        workspace_member_dependents: vec![],
        workspace_member_dev_dependents: vec![],
        workspace_member_build_dependents: vec![],
        is_workspace_member_dependency: false,
        targets: vec![BuildableTarget {
            kind: String::from("lib"),
            name: String::from("maplit"),
            path: String::from("src/lib.rs"),
            edition: String::from("2015"),
        }],
        build_script_target: None,
        targeted_deps: vec![],
        links: None,
        is_proc_macro: false,
    }
}

/// A module containing constants for each metadata template
pub mod templates {
    pub const BASIC_METADATA: &str = "basic_metadata.json.template";
    pub const DUMMY_MODIFIED_METADATA: &str = "dummy_modified_metadata.json.template";
    pub const PLAN_BUILD_PRODUCES_ALIASED_DEPENDENCIES: &str =
        "plan_build_produces_aliased_dependencies.json.template";
    pub const PLAN_BUILD_PRODUCES_BUILD_PROC_MACRO_DEPENDENCIES: &str =
        "plan_build_produces_build_proc_macro_dependencies.json.template";
    pub const PLAN_BUILD_PRODUCES_PROC_MACRO_DEPENDENCIES: &str =
        "plan_build_produces_proc_macro_dependencies.json.template";
    pub const SEMVER_MATCHING: &str = "semver_matching.json.template";
    pub const SUBPLAN_PRODUCES_CRATE_ROOT_WITH_FORWARD_SLASH: &str =
        "subplan_produces_crate_root_with_forward_slash.json.template";
}

pub const fn basic_toml_contents() -> &'static str {
    indoc! { r#"
    [package]
    name = "test"
    version = "0.0.1"
  
    [lib]
    path = "not_a_file.rs"
  "# }
}

pub const fn basic_lock_contents() -> &'static str {
    indoc! { r#"
    [[package]]
    name = "test"
    version = "0.0.1"
    dependencies = [
    ]
  "# }
}

pub const fn advanced_toml_contents() -> &'static str {
    indoc! { r#"
    [package]
    name = "cargo-raze-test"
    version = "0.1.0"

    [lib]
    path = "not_a_file.rs"

    [dependencies]
    proc-macro2 = "1.0.24"
  "# }
}

pub const fn advanced_lock_contents() -> &'static str {
    indoc! { r#"
    # This file is automatically @generated by Cargo.
    # It is not intended for manual editing.
    [[package]]
    name = "cargo-raze-test"
    version = "0.1.0"
    dependencies = [
      "proc-macro2",
    ]

    [[package]]
    name = "proc-macro2"
    version = "1.0.24"
    source = "registry+https://github.com/rust-lang/crates.io-index"
    checksum = "1e0704ee1a7e00d7bb417d0770ea303c1bccbabf0ef1667dae92b5967f5f8a71"
    dependencies = [
      "unicode-xid",
    ]

    [[package]]
    name = "unicode-xid"
    version = "0.2.1"
    source = "registry+https://github.com/rust-lang/crates.io-index"
    checksum = "f7fe0bb3479651439c9112f72b6c505038574c9fbb575ed1bf3b797fa39dd564"
  "# }
}

pub fn named_toml_contents(name: &str, version: &str) -> String {
    formatdoc! { r#"
    [package]
    name = "{name}"
    version = "{version}"

    [lib]
    path = "not_a_file.rs"

  "#, name = name, version = version }
}

pub fn make_workspace(toml_file: &str, lock_file: Option<&str>) -> TempDir {
    let dir = TempDir::new().unwrap();
    // Create Cargo.toml
    {
        let path = dir.path().join("Cargo.toml");
        let mut toml = File::create(&path).unwrap();
        toml.write_all(toml_file.as_bytes()).unwrap();
    }

    if let Some(lock_file) = lock_file {
        let path = dir.path().join("Cargo.lock");
        let mut lock = File::create(&path).unwrap();
        lock.write_all(lock_file.as_bytes()).unwrap();
    }

    File::create(dir.as_ref().join("WORKSPACE.bazel")).unwrap();
    dir
}

pub fn make_basic_workspace() -> TempDir {
    make_workspace(basic_toml_contents(), Some(basic_lock_contents()))
}

pub fn make_workspace_with_dependency() -> TempDir {
    make_workspace(advanced_toml_contents(), Some(advanced_lock_contents()))
}

/// Generate RazeMetadata from a cargo metadata template
pub fn template_raze_metadata(template_path: &str) -> RazeMetadata {
    let dir = make_basic_workspace();
    let mut fetcher = dummy_raze_metadata_fetcher();

    // Always render basic metadata
    fetcher.set_metadata_fetcher(Box::new(DummyCargoMetadataFetcher {
        metadata_template: Some(template_path.to_string()),
    }));

    fetcher.fetch_metadata(dir.as_ref(), None).unwrap()
}
