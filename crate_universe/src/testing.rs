use cargo_raze::context::{
    BuildableTarget, CrateContext, CrateDependencyContext, GitRepo, LicenseData, SourceDetails,
};
use semver::Version;

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
            aliased_dependencies: vec![],
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
