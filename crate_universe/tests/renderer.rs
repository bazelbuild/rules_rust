use cargo_raze::context::{
    BuildableTarget, CrateContext, CrateDependencyContext, GitRepo, LicenseData, SourceDetails,
};
use crate_universe_resolver::renderer::{RenderConfig, Renderer};
use crate_universe_resolver::resolver::Dependencies;
use maplit::{btreemap, btreeset};
use semver::Version;
use std::collections::BTreeMap;

#[test]
fn single_git_repository() {
    let renderer = Renderer::new(
        RenderConfig {
            repo_rule_name: String::from("rule_prefix"),
            crate_registry_template: String::from(
                "https://crates.io/api/v1/crates/{crate}/{version}/download",
            ),
            rules_rust_workspace_name: String::from("rules_rust"),
        },
        String::from("598"),
        vec![lazy_static_crate_context(true)],
        Dependencies {
            normal: BTreeMap::new(),
            build: BTreeMap::new(),
            dev: BTreeMap::new(),
        },
        BTreeMap::new(),
    );

    let mut output = Vec::new();

    renderer
        .render_workspaces(&mut output)
        .expect("Error rendering");

    let output = String::from_utf8(output).expect("Non-UTF8 output");

    let expected_repository_rule = format!(
        r###"# rules_rust crate_universe file format 1
# config hash 598

load("@bazel_tools//tools/build_defs/repo:git.bzl", "new_git_repository")

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

def pinned_rust_install():
    new_git_repository(
        name = "rule_prefix__lazy_static__1_4_0",
        strip_prefix = "",
        build_file_content = """{}""",
        remote = "https://github.com/rust-lang-nursery/lazy-static.rs.git",
        commit = "421669662b35fcb455f2902daed2e20bbbba79b6",
    )
"###,
        LAZY_STATIC_BUILD_FILE_CONTENT
    );

    assert_eq!(output, expected_repository_rule);
}

#[test]
fn single_http_archive() {
    let renderer = Renderer::new(
        RenderConfig {
            repo_rule_name: String::from("rule_prefix"),
            crate_registry_template: String::from(
                "https://crates.io/api/v1/crates/{crate}/{version}/download",
            ),
            rules_rust_workspace_name: String::from("rules_rust"),
        },
        String::from("598"),
        vec![lazy_static_crate_context(false)],
        Dependencies {
            normal: BTreeMap::new(),
            build: BTreeMap::new(),
            dev: BTreeMap::new(),
        },
        BTreeMap::new(),
    );

    let mut output = Vec::new();

    renderer
        .render_workspaces(&mut output)
        .expect("Error rendering");

    let output = String::from_utf8(output).expect("Non-UTF8 output");

    // TODO: Don't unconditionally load new_git_repository and http_archive
    let expected_repository_rule = format!(
        r###"# rules_rust crate_universe file format 1
# config hash 598

load("@bazel_tools//tools/build_defs/repo:git.bzl", "new_git_repository")

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

def pinned_rust_install():
    http_archive(
        name = "rule_prefix__lazy_static__1_4_0",
        build_file_content = """{}""",
        sha256 = "e2abad23fbc42b3700f2f279844dc832adb2b2eb069b2df918f455c4e18cc646",
        strip_prefix = "lazy_static-1.4.0",
        type = "tar.gz",
        url = "https://crates.io/api/v1/crates/lazy_static/1.4.0/download",
    )
"###,
        LAZY_STATIC_BUILD_FILE_CONTENT
    );

    assert_eq!(output, expected_repository_rule);
}

#[test]
fn crate_helper_function_mapping() {
    let crate_context = lazy_static_crate_context(false);

    let normal_deps = btreemap! {
        crate_context.pkg_name.clone() => crate_context.pkg_version.clone(),
    };

    let renderer = Renderer::new(
        RenderConfig {
            repo_rule_name: String::from("rule_prefix"),
            crate_registry_template: String::from(
                "https://crates.io/api/v1/crates/{crate}/{version}/download",
            ),
            rules_rust_workspace_name: String::from("rules_rust"),
        },
        String::from("598"),
        vec![crate_context],
        Dependencies {
            normal: normal_deps,
            build: BTreeMap::new(),
            dev: BTreeMap::new(),
        },
        btreemap! {
            String::from("//some:Cargo.toml") => btreeset!{ String::from("lazy_static") },
        },
    );

    let mut output = Vec::new();

    renderer
        .render_helper_functions(&mut output)
        .expect("Error rendering");

    let output = String::from_utf8(output).expect("Non-UTF8 output");

    // TODO: Have a single function with kwargs to enable each kind of dep, rather than multiple functions.
    let expected_repository_rule = r###"CRATE_TARGET_NAMES = {
    "lazy_static": "@rule_prefix__lazy_static__1_4_0//:lazy_static",
}

def crate(crate_name):
    """Return the name of the target for the given crate.
    """
    target_name = CRATE_TARGET_NAMES.get(crate_name)
    if target_name == None:
        fail("Unknown crate name: {}".format(crate_name))
    return target_name

def all_deps():
    """Return all standard dependencies explicitly listed in the Cargo.toml or packages list."""
    return [
        crate(crate_name) for crate_name in [
            "lazy_static",
        ]
    ]

def all_proc_macro_deps():
    """Return all proc-macro dependencies explicitly listed in the Cargo.toml or packages list."""
    return [
        crate(crate_name) for crate_name in [
        ]
    ]

def crates_from(label):
    mapping = {
        "//some:Cargo.toml": [
            crate("lazy_static"),
        ],
    }
    return mapping[_absolutify(label)]

def dev_crates_from(label):
    mapping = {
        "//some:Cargo.toml": [
        ],
    }
    return mapping[_absolutify(label)]

def build_crates_from(label):
    mapping = {
        "//some:Cargo.toml": [
        ],
    }
    return mapping[_absolutify(label)]

def proc_macro_crates_from(label):
    mapping = {
        "//some:Cargo.toml": [
        ],
    }
    return mapping[_absolutify(label)]

def _absolutify(label):
    if label.startswith("//") or label.startswith("@"):
        return label
    if label.startswith(":"):
        return "//" + native.package_name() + label
    return "//" + native.package_name() + ":" + label
"###;

    assert_eq!(output, expected_repository_rule);
}

fn lazy_static_crate_context(git: bool) -> CrateContext {
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

// TODO: Make these files buildifier-compliant when generated to remote the buildifier comments.
// TODO: Conditionally add loads and attributes only if needed
const LAZY_STATIC_BUILD_FILE_CONTENT: &str = r###"# buildifier: disable=load
load(
    "@rules_rust//rust:defs.bzl",
    "rust_binary",
    "rust_library",
    "rust_proc_macro",
    "rust_test",
)

# buildifier: disable=load
load("@bazel_skylib//lib:selects.bzl", "selects")

package(default_visibility = [
    "//visibility:public",
])

licenses([
    "restricted",  # no license
])

# Generated targets

# buildifier: leave-alone
rust_library(
    name = "lazy_static",
    deps = [
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2015",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    data = glob(["**"], exclude=[
        # These can be manually added with overrides if needed.

        # If you run `cargo build` in this dir, the target dir can get very big very quick.
        "target/**",

        # These are not vendored from the crate - we exclude them to avoid busting caches
        # when we change how we generate BUILD files and such.
        "BUILD.bazel",
        "WORKSPACE.bazel",
        "WORKSPACE",
    ]),
    version = "1.4.0",
    tags = [
        "cargo-raze",
        "manual",
    ],
    crate_features = [
    ],
    aliases = select({
        # Default
        "//conditions:default": {
        },
    }),
)
"###;

// TODO: Add more tests for build_file_content
