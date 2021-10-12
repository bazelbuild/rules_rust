use cargo_raze::context::{
    BuildableTarget, CrateContext, CrateDependencyContext, GitRepo, LicenseData, SourceDetails,
};
use semver::Version;
use std::collections::{BTreeMap, BTreeSet};

pub(crate) fn lazy_static_crate_context(git: bool) -> CrateContext {
    let source_details = if git {
        SourceDetails {
            git_data: Some(GitRepo {
                remote: String::from("https://github.com/rust-lang-nursery/lazy-static.rs.git"),
                commit: String::from("421669662b35fcb455f2902daed2e20bbbba79b6"),
                path_to_crate_root: None,
            }),
            download_url: None,
        }
    } else {
        SourceDetails {
            git_data: None,
            download_url: Some(
                "https://crates.io/api/v1/crates/lazy_static/1.4.0/download"
                    .parse()
                    .unwrap(),
            ),
        }
    };

    CrateContext {
        pkg_name: String::from("lazy_static"),
        pkg_version: Version::parse("1.4.0").unwrap(),
        edition: String::from("2015"),
        raze_settings: Default::default(),
        canonical_additional_build_file: None,
        default_deps: CrateDependencyContext {
            dependencies: BTreeSet::new(),
            proc_macro_dependencies: BTreeSet::new(),
            data_dependencies: BTreeSet::new(),
            build_dependencies: BTreeSet::new(),
            build_proc_macro_dependencies: BTreeSet::new(),
            build_data_dependencies: BTreeSet::new(),
            dev_dependencies: BTreeSet::new(),
            aliased_dependencies: BTreeMap::new(),
        },
        source_details,
        sha256: Some(String::from(
            "e2abad23fbc42b3700f2f279844dc832adb2b2eb069b2df918f455c4e18cc646",
        )),
        expected_build_path: String::from("UNUSED"),
        lib_target_name: Some(String::from("UNUSED")),
        license: LicenseData::default(),
        features: vec![],
        workspace_path_to_crate: String::from("UNUSED"),
        workspace_member_dependents: vec![],
        workspace_member_dev_dependents: vec![],
        workspace_member_build_dependents: vec![],
        is_workspace_member_dependency: false,
        is_binary_dependency: false,
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
    let source_details = if git {
        SourceDetails {
            git_data: Some(GitRepo {
                remote: String::from("https://github.com/bluss/maplit.git"),
                commit: String::from("04936f703da907bc4ffdaced121e4cfd5ecbaec6"),
                path_to_crate_root: None,
            }),
            download_url: None,
        }
    } else {
        SourceDetails {
            git_data: None,
            download_url: Some(
                "https://crates.io/api/v1/crates/maplit/1.0.2/download"
                    .parse()
                    .unwrap(),
            ),
        }
    };

    CrateContext {
        pkg_name: String::from("maplit"),
        pkg_version: Version::parse("1.0.2").unwrap(),
        edition: String::from("2015"),
        raze_settings: Default::default(),
        canonical_additional_build_file: None,
        default_deps: CrateDependencyContext {
            dependencies: BTreeSet::new(),
            proc_macro_dependencies: BTreeSet::new(),
            data_dependencies: BTreeSet::new(),
            build_dependencies: BTreeSet::new(),
            build_proc_macro_dependencies: BTreeSet::new(),
            build_data_dependencies: BTreeSet::new(),
            dev_dependencies: BTreeSet::new(),
            aliased_dependencies: BTreeMap::new(),
        },
        source_details,
        sha256: Some(String::from(
            "3e2e65a1a2e43cfcb47a895c4c8b10d1f4a61097f9f254f183aee60cad9c651d",
        )),
        expected_build_path: String::from("UNUSED"),
        lib_target_name: Some(String::from("UNUSED")),
        license: LicenseData::default(),
        features: vec![],
        workspace_path_to_crate: String::from("UNUSED"),
        workspace_member_dependents: vec![],
        workspace_member_dev_dependents: vec![],
        workspace_member_build_dependents: vec![],
        is_workspace_member_dependency: false,
        is_binary_dependency: false,
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
