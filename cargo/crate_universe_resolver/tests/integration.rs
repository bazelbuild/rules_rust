use std::collections::{BTreeMap, BTreeSet, HashMap};
use std::fs::create_dir_all;
use std::path::PathBuf;

use assert_cmd::assert::Assert;
use assert_cmd::Command;
use maplit::btreemap;
use predicates::boolean::PredicateBooleanExt;
use predicates::ord::eq;
use semver::VersionReq;

use crate_universe_resolver::config::{Config, Override, Package};
use crate_universe_resolver::NamedTempFile;

#[test]
fn basic() {
    let cargo_toml_file = NamedTempFile::with_str_content(
        "Cargo.toml",
        r#"[package]
name = "basic"
version = "0.1.0"
edition = "2018"

[dependencies]
lazy_static = "=1.4.0"
"#,
    )
    .expect("Error making temporary file");

    let config = Config {
        repository_name: "beep".to_owned(),
        cargo_toml_files: btreemap! { String::from("//some:Cargo.toml") => cargo_toml_file.path().to_path_buf() },
        overrides: Default::default(),
        repository_template: "https://crates-io.s3-us-west-1.amazonaws.com/crates/crates/{crate}/{crate}-{version}.crate".to_owned(),
        target_triples: vec!["x86_64-apple-darwin".to_owned()],
        packages: vec![],
        cargo: PathBuf::from(env!("CARGO")),
        rust_rules_workspace_name: crate_universe_resolver::config::default_rules_rust_workspace_name(),
        index_url: crate_universe_resolver::config::default_index_url(),
    };

    let want_output = r##"
load("@bazel_tools//tools/build_defs/repo:git.bzl", "new_git_repository")

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

def pinned_rust_install():
    http_archive(
        name = "beep__lazy_static__1_4_0",
        # TODO: Allow configuring where rust_library comes from
        build_file_content = """# buildifier: disable=load
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
    "notice",  # MIT from expression "MIT OR Apache-2.0"
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
# Unsupported target "no_std" with type "test" omitted
# Unsupported target "test" with type "test" omitted
""",
        sha256 = "e2abad23fbc42b3700f2f279844dc832adb2b2eb069b2df918f455c4e18cc646",
        strip_prefix = "lazy_static-1.4.0",
        type = "tar.gz",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/crates/lazy_static/lazy_static-1.4.0.crate",
    )


CRATE_TARGET_NAMES = {
    "lazy_static": "@beep__lazy_static__1_4_0//:lazy_static",
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
        "//some:Cargo.toml": [crate("lazy_static")],
    }
    return mapping[_absolutify(label)]

def dev_crates_from(label):
    mapping = {
        "//some:Cargo.toml": [],
    }
    return mapping[_absolutify(label)]

def build_crates_from(label):
    mapping = {
        "//some:Cargo.toml": [],
    }
    return mapping[_absolutify(label)]

def proc_macro_crates_from(label):
    mapping = {
        "//some:Cargo.toml": [],
    }
    return mapping[_absolutify(label)]

def _absolutify(label):
    if label.startswith("//") or label.startswith("@"):
        return label
    if label.startswith(":"):
        return "//" + native.package_name() + label
    return "//" + native.package_name() + ":" + label
"##;

    // Ignore header which contains a hash
    test(&config)
        .success()
        .stdout(predicates::str::ends_with(want_output));
}

#[test]
fn intermediate() {
    let cargo_toml_file = NamedTempFile::with_str_content(
        "Cargo.toml",
        r#"[package]
name = "intermediate"
version = "0.1.0"
edition = "2018"

# TODO: support lockfile instead of passing the transitive pinned list as "packages" directly.
[dependencies]
lazy_static = "=1.4.0"
bytes = "=0.5.6"
pin-project-lite = "=0.1.12"
bitflags = "=1.2.1"

# System dependency (libz-sys) and its transitive deps.
libz-sys = "=1.1.2"
cc = "=1.0.62"
libc = "=0.2.80"
pkg-config = "=0.3.19"
vcpkg = "=0.2.10"

# TODO: do not depend on this section to be present rules_rust_external.
[[bin]]
name = "basic"
path = "src/main.rs"
"#,
    )
    .expect("Error making temporary file");

    let mut tokio_extra_rust_env_vars = BTreeMap::<String, String>::new();
    tokio_extra_rust_env_vars.insert("ENV_VAR_1".to_owned(), "value1".to_owned());
    tokio_extra_rust_env_vars.insert("ENV_VAR_2".to_owned(), "value2".to_owned());

    let mut tokio_extra_bazel_deps = BTreeMap::<String, Vec<String>>::new();
    tokio_extra_bazel_deps.insert(
        "x86_64-apple-darwin".to_owned(),
        vec!["@some//:dep".to_owned(), "@other//:dep".to_owned()],
    );
    tokio_extra_bazel_deps.insert("cfg(unix)".to_owned(), vec!["@yetanother//:dep".to_owned()]);

    let mut bitflags_extra_build_script_env_vars = BTreeMap::<String, String>::new();
    bitflags_extra_build_script_env_vars
        .insert("BUILD_SCRIPT_ENV_VAR".to_owned(), "value".to_owned());

    let mut bitflags_extra_bazel_builds_script_deps = BTreeMap::<String, Vec<String>>::new();
    bitflags_extra_bazel_builds_script_deps.insert(
        "x86_64-unknown-linux-gnu".to_owned(),
        vec!["@buildscriptdep//:dep".to_owned()],
    );

    let mut bitflags_extra_bazel_builds_script_data_deps = BTreeMap::<String, Vec<String>>::new();
    bitflags_extra_bazel_builds_script_data_deps.insert(
        "x86_64-unknown-linux-gnu".to_owned(),
        vec!["@buildscriptdep//:somedata".to_owned()],
    );

    let mut lazy_static_extra_bazel_deps = BTreeMap::<String, Vec<String>>::new();
    lazy_static_extra_bazel_deps.insert("cfg(all())".to_owned(), vec!["@such//:dep".to_owned()]);

    let mut lazy_static_extra_bazel_data_deps = BTreeMap::<String, Vec<String>>::new();
    lazy_static_extra_bazel_data_deps.insert(
        "x86_64-unknown-linux-gnu".to_owned(),
        vec!["@such//:somedata".to_owned()],
    );

    let mut overrides = HashMap::new();
    overrides.insert(
        "tokio".into(),
        Override {
            extra_rust_env_vars: tokio_extra_rust_env_vars,
            extra_build_script_env_vars: Default::default(),
            extra_bazel_deps: tokio_extra_bazel_deps,
            extra_build_script_bazel_deps: Default::default(),
            extra_bazel_data_deps: Default::default(),
            extra_build_script_bazel_data_deps: Default::default(),
            features_to_remove: BTreeSet::new(),
        },
    );
    overrides.insert(
        "lazy_static".into(),
        Override {
            extra_rust_env_vars: Default::default(),
            extra_build_script_env_vars: Default::default(),
            extra_bazel_deps: lazy_static_extra_bazel_deps,
            extra_build_script_bazel_deps: Default::default(),
            extra_bazel_data_deps: lazy_static_extra_bazel_data_deps,
            extra_build_script_bazel_data_deps: Default::default(),
            features_to_remove: BTreeSet::new(),
        },
    );
    overrides.insert(
        "bitflags".into(),
        Override {
            extra_rust_env_vars: Default::default(),
            extra_build_script_env_vars: bitflags_extra_build_script_env_vars,
            extra_bazel_deps: Default::default(),
            extra_build_script_bazel_deps: bitflags_extra_bazel_builds_script_deps,
            extra_bazel_data_deps: Default::default(),
            extra_build_script_bazel_data_deps: bitflags_extra_bazel_builds_script_data_deps,
            features_to_remove: BTreeSet::new(),
        },
    );

    let config = Config {
        repository_name: "beep".to_owned(),
        cargo_toml_files: btreemap! { String::from("//some:Cargo.toml") => cargo_toml_file.path().to_path_buf() },
        overrides,
        repository_template: "https://crates-io.s3-us-west-1.amazonaws.com/crates/crates/{crate}/{crate}-{version}.crate".to_owned(),
        target_triples: vec![
            "x86_64-apple-darwin".to_owned(),
            "x86_64-unknown-linux-gnu".to_owned(),
            "x86_64-pc-windows-gnu".to_owned(),
        ],
        packages: vec![Package {
            name: "tokio".to_string(),
            semver: VersionReq::parse("=0.2.22").unwrap(),
            features: vec![],
        }],
        cargo: PathBuf::from(env!("CARGO")),
        rust_rules_workspace_name: crate_universe_resolver::config::default_rules_rust_workspace_name(),
        index_url: crate_universe_resolver::config::default_index_url(),
    };

    let want_output = r##"
load("@bazel_tools//tools/build_defs/repo:git.bzl", "new_git_repository")

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

def pinned_rust_install():
    http_archive(
        name = "beep__bitflags__1_2_1",
        # TODO: Allow configuring where rust_library comes from
        build_file_content = """# buildifier: disable=load
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
    "notice",  # MIT from expression "MIT OR Apache-2.0"
])

# Generated targets
# buildifier: disable=load-on-top
load(
    "@rules_rust//cargo:cargo_build_script.bzl",
    "cargo_build_script",
)

# buildifier: leave-alone
cargo_build_script(
    name = "bitflags_build_script",
    srcs = glob(["**/*.rs"]),
    crate_root = "build.rs",
    edition = "2015",
    deps = [
    ] + selects.with_or({
        # x86_64-unknown-linux-gnu
        (
            "@rules_rust//rust/platform:x86_64-unknown-linux-gnu",
        ): [
            "@buildscriptdep//:dep",
        ],
        "//conditions:default": [],
    }),
    rustc_flags = [
        "--cap-lints=allow",
    ],
    crate_features = [
      "default",
    ],
    build_script_env = {
        "BUILD_SCRIPT_ENV_VAR": "value",
    },
    data = glob(["**"], exclude=[
        # These can be manually added with overrides if needed.

        # If you run `cargo build` in this dir, the target dir can get very big very quick.
        "target/**",

        # These are not vendored from the crate - we exclude them to avoid busting caches
        # when we change how we generate BUILD files and such.
        "BUILD.bazel",
        "WORKSPACE.bazel",
        "WORKSPACE",
    ]) + selects.with_or({
        # x86_64-unknown-linux-gnu
        (
            "@rules_rust//rust/platform:x86_64-unknown-linux-gnu",
        ): [
            "@buildscriptdep//:somedata",
        ],
        "//conditions:default": [],
    }),
    tags = [
        "cargo-raze",
        "manual",
    ],
    version = "1.2.1",
    visibility = ["//visibility:private"],
)


# buildifier: leave-alone
rust_library(
    name = "bitflags",
    deps = [
        ":bitflags_build_script",
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
    version = "1.2.1",
    tags = [
        "cargo-raze",
        "manual",
    ],
    crate_features = [
        "default",
    ],
    aliases = select({
        # Default
        "//conditions:default": {
        },
        #  x86_64-unknown-linux-gnu
        "@rules_rust//rust/platform:x86_64-unknown-linux-gnu": {
        },
    }),
)
""",
        sha256 = "cf1de2fe8c75bc145a2f577add951f8134889b4795d47466a54a5c846d691693",
        strip_prefix = "bitflags-1.2.1",
        type = "tar.gz",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/crates/bitflags/bitflags-1.2.1.crate",
    )

    http_archive(
        name = "beep__bytes__0_5_6",
        # TODO: Allow configuring where rust_library comes from
        build_file_content = """# buildifier: disable=load
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
    "notice",  # MIT from expression "MIT"
])

# Generated targets
# Unsupported target "buf" with type "bench" omitted
# Unsupported target "bytes" with type "bench" omitted
# Unsupported target "bytes_mut" with type "bench" omitted

# buildifier: leave-alone
rust_library(
    name = "bytes",
    deps = [
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2018",
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
    version = "0.5.6",
    tags = [
        "cargo-raze",
        "manual",
    ],
    crate_features = [
        "default",
        "std",
    ],
    aliases = select({
        # Default
        "//conditions:default": {
        },
    }),
)
# Unsupported target "test_buf" with type "test" omitted
# Unsupported target "test_buf_mut" with type "test" omitted
# Unsupported target "test_bytes" with type "test" omitted
# Unsupported target "test_bytes_odd_alloc" with type "test" omitted
# Unsupported target "test_bytes_vec_alloc" with type "test" omitted
# Unsupported target "test_chain" with type "test" omitted
# Unsupported target "test_debug" with type "test" omitted
# Unsupported target "test_iter" with type "test" omitted
# Unsupported target "test_reader" with type "test" omitted
# Unsupported target "test_serde" with type "test" omitted
# Unsupported target "test_take" with type "test" omitted
""",
        sha256 = "0e4cec68f03f32e44924783795810fa50a7035d8c8ebe78580ad7e6c703fba38",
        strip_prefix = "bytes-0.5.6",
        type = "tar.gz",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/crates/bytes/bytes-0.5.6.crate",
    )

    http_archive(
        name = "beep__cc__1_0_62",
        # TODO: Allow configuring where rust_library comes from
        build_file_content = """# buildifier: disable=load
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
    "notice",  # MIT from expression "MIT OR Apache-2.0"
])

# Generated targets

# buildifier: leave-alone
rust_binary(
    # Prefix bin name to disambiguate from (probable) collision with lib name
    # N.B.: The exact form of this is subject to change.
    name = "cargo_bin_gcc_shim",
    deps = [
        # Binaries get an implicit dependency on their crate's lib
        ":cc",
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/bin/gcc-shim.rs",
    edition = "2018",
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
    version = "1.0.62",
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

# buildifier: leave-alone
rust_library(
    name = "cc",
    deps = [
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2018",
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
    version = "1.0.62",
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
# Unsupported target "cc_env" with type "test" omitted
# Unsupported target "cflags" with type "test" omitted
# Unsupported target "cxxflags" with type "test" omitted
# Unsupported target "test" with type "test" omitted
""",
        sha256 = "f1770ced377336a88a67c473594ccc14eca6f4559217c34f64aac8f83d641b40",
        strip_prefix = "cc-1.0.62",
        type = "tar.gz",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/crates/cc/cc-1.0.62.crate",
    )

    http_archive(
        name = "beep__lazy_static__1_4_0",
        # TODO: Allow configuring where rust_library comes from
        build_file_content = """# buildifier: disable=load
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
    "notice",  # MIT from expression "MIT OR Apache-2.0"
])

# Generated targets

# buildifier: leave-alone
rust_library(
    name = "lazy_static",
    deps = [
    ] + selects.with_or({
        # cfg(all())
        (
            "@rules_rust//rust/platform:x86_64-apple-darwin",
            "@rules_rust//rust/platform:x86_64-unknown-linux-gnu",
        ): [
            "@such//:dep",
        ],
        "//conditions:default": [],
    }),
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
    ]) + selects.with_or({
        # x86_64-unknown-linux-gnu
        (
            "@rules_rust//rust/platform:x86_64-unknown-linux-gnu",
        ): [
            "@such//:somedata",
        ],
        "//conditions:default": [],
    }),
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
        #  cfg(all())
        "@rules_rust//rust/platform:x86_64-apple-darwin": {
        },
        #  cfg(all()) x86_64-unknown-linux-gnu
        "@rules_rust//rust/platform:x86_64-unknown-linux-gnu": {
        },
    }),
)
# Unsupported target "no_std" with type "test" omitted
# Unsupported target "test" with type "test" omitted
""",
        sha256 = "e2abad23fbc42b3700f2f279844dc832adb2b2eb069b2df918f455c4e18cc646",
        strip_prefix = "lazy_static-1.4.0",
        type = "tar.gz",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/crates/lazy_static/lazy_static-1.4.0.crate",
    )

    http_archive(
        name = "beep__libc__0_2_80",
        # TODO: Allow configuring where rust_library comes from
        build_file_content = """# buildifier: disable=load
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
    "notice",  # MIT from expression "MIT OR Apache-2.0"
])

# Generated targets
# buildifier: disable=load-on-top
load(
    "@rules_rust//cargo:cargo_build_script.bzl",
    "cargo_build_script",
)

# buildifier: leave-alone
cargo_build_script(
    name = "libc_build_script",
    srcs = glob(["**/*.rs"]),
    crate_root = "build.rs",
    edition = "2015",
    deps = [
    ],
    rustc_flags = [
        "--cap-lints=allow",
    ],
    crate_features = [
      "default",
      "std",
    ],
    build_script_env = {
    },
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
    tags = [
        "cargo-raze",
        "manual",
    ],
    version = "0.2.80",
    visibility = ["//visibility:private"],
)


# buildifier: leave-alone
rust_library(
    name = "libc",
    deps = [
        ":libc_build_script",
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
    version = "0.2.80",
    tags = [
        "cargo-raze",
        "manual",
    ],
    crate_features = [
        "default",
        "std",
    ],
    aliases = select({
        # Default
        "//conditions:default": {
        },
    }),
)
# Unsupported target "const_fn" with type "test" omitted
""",
        sha256 = "4d58d1b70b004888f764dfbf6a26a3b0342a1632d33968e4a179d8011c760614",
        strip_prefix = "libc-0.2.80",
        type = "tar.gz",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/crates/libc/libc-0.2.80.crate",
    )

    http_archive(
        name = "beep__libz_sys__1_1_2",
        # TODO: Allow configuring where rust_library comes from
        build_file_content = """# buildifier: disable=load
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
    "notice",  # MIT from expression "MIT OR Apache-2.0"
])

# Generated targets
# buildifier: disable=load-on-top
load(
    "@rules_rust//cargo:cargo_build_script.bzl",
    "cargo_build_script",
)

# buildifier: leave-alone
cargo_build_script(
    name = "libz_sys_build_script",
    srcs = glob(["**/*.rs"]),
    crate_root = "build.rs",
    edition = "2015",
    deps = [
        "@beep__cc__1_0_62//:cc",
        "@beep__pkg_config__0_3_19//:pkg_config",
    ],
    rustc_flags = [
        "--cap-lints=allow",
    ],
    crate_features = [
      "default",
      "libc",
      "stock-zlib",
    ],
    build_script_env = {
    },
    links = "z",
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
    tags = [
        "cargo-raze",
        "manual",
    ],
    version = "1.1.2",
    visibility = ["//visibility:private"],
)


# buildifier: leave-alone
rust_library(
    name = "libz_sys",
    deps = [
        ":libz_sys_build_script",
        "@beep__libc__0_2_80//:libc",
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
    version = "1.1.2",
    tags = [
        "cargo-raze",
        "manual",
    ],
    crate_features = [
        "default",
        "libc",
        "stock-zlib",
    ],
    aliases = select({
        # Default
        "//conditions:default": {
        },
    }),
)
""",
        sha256 = "602113192b08db8f38796c4e85c39e960c145965140e918018bcde1952429655",
        strip_prefix = "libz-sys-1.1.2",
        type = "tar.gz",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/crates/libz-sys/libz-sys-1.1.2.crate",
    )

    http_archive(
        name = "beep__pin_project_lite__0_1_12",
        # TODO: Allow configuring where rust_library comes from
        build_file_content = """# buildifier: disable=load
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
    "notice",  # Apache-2.0 from expression "Apache-2.0 OR MIT"
])

# Generated targets

# buildifier: leave-alone
rust_library(
    name = "pin_project_lite",
    deps = [
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2018",
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
    version = "0.1.12",
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
# Unsupported target "compiletest" with type "test" omitted
# Unsupported target "lint" with type "test" omitted
# Unsupported target "proper_unpin" with type "test" omitted
# Unsupported target "test" with type "test" omitted
""",
        sha256 = "257b64915a082f7811703966789728173279bdebb956b143dbcd23f6f970a777",
        strip_prefix = "pin-project-lite-0.1.12",
        type = "tar.gz",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/crates/pin-project-lite/pin-project-lite-0.1.12.crate",
    )

    http_archive(
        name = "beep__pkg_config__0_3_19",
        # TODO: Allow configuring where rust_library comes from
        build_file_content = """# buildifier: disable=load
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
    "notice",  # MIT from expression "MIT OR Apache-2.0"
])

# Generated targets

# buildifier: leave-alone
rust_library(
    name = "pkg_config",
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
    version = "0.3.19",
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
# Unsupported target "test" with type "test" omitted
""",
        sha256 = "3831453b3449ceb48b6d9c7ad7c96d5ea673e9b470a1dc578c2ce6521230884c",
        strip_prefix = "pkg-config-0.3.19",
        type = "tar.gz",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/crates/pkg-config/pkg-config-0.3.19.crate",
    )

    http_archive(
        name = "beep__tokio__0_2_22",
        # TODO: Allow configuring where rust_library comes from
        build_file_content = """# buildifier: disable=load
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
    "notice",  # MIT from expression "MIT"
])

# Generated targets

# buildifier: leave-alone
rust_library(
    name = "tokio",
    deps = [
        "@beep__bytes__0_5_6//:bytes",
        "@beep__pin_project_lite__0_1_12//:pin_project_lite",
    ] + selects.with_or({
        # cfg(unix)
        (
            "@rules_rust//rust/platform:x86_64-apple-darwin",
            "@rules_rust//rust/platform:x86_64-unknown-linux-gnu",
        ): [
            "@yetanother//:dep",
        ],
        "//conditions:default": [],
    }) + selects.with_or({
        # x86_64-apple-darwin
        (
            "@rules_rust//rust/platform:x86_64-apple-darwin",
        ): [
            "@some//:dep",
            "@other//:dep",
        ],
        "//conditions:default": [],
    }),
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2018",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    rustc_env = {
        "ENV_VAR_1": "value1",
        "ENV_VAR_2": "value2",
    },
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
    version = "0.2.22",
    tags = [
        "cargo-raze",
        "manual",
    ],
    crate_features = [
        "default",
    ],
    aliases = select({
        # Default
        "//conditions:default": {
        },
        #  cfg(unix) cfg(unix) x86_64-apple-darwin
        "@rules_rust//rust/platform:x86_64-apple-darwin": {
        },
        #  cfg(unix) cfg(unix)
        "@rules_rust//rust/platform:x86_64-unknown-linux-gnu": {
        },
    }),
)
# Unsupported target "_require_full" with type "test" omitted
# Unsupported target "async_send_sync" with type "test" omitted
# Unsupported target "buffered" with type "test" omitted
# Unsupported target "fs" with type "test" omitted
# Unsupported target "fs_copy" with type "test" omitted
# Unsupported target "fs_dir" with type "test" omitted
# Unsupported target "fs_file" with type "test" omitted
# Unsupported target "fs_file_mocked" with type "test" omitted
# Unsupported target "fs_link" with type "test" omitted
# Unsupported target "io_async_read" with type "test" omitted
# Unsupported target "io_chain" with type "test" omitted
# Unsupported target "io_copy" with type "test" omitted
# Unsupported target "io_driver" with type "test" omitted
# Unsupported target "io_driver_drop" with type "test" omitted
# Unsupported target "io_lines" with type "test" omitted
# Unsupported target "io_read" with type "test" omitted
# Unsupported target "io_read_exact" with type "test" omitted
# Unsupported target "io_read_line" with type "test" omitted
# Unsupported target "io_read_to_end" with type "test" omitted
# Unsupported target "io_read_to_string" with type "test" omitted
# Unsupported target "io_read_until" with type "test" omitted
# Unsupported target "io_split" with type "test" omitted
# Unsupported target "io_take" with type "test" omitted
# Unsupported target "io_write" with type "test" omitted
# Unsupported target "io_write_all" with type "test" omitted
# Unsupported target "io_write_int" with type "test" omitted
# Unsupported target "macros_join" with type "test" omitted
# Unsupported target "macros_pin" with type "test" omitted
# Unsupported target "macros_select" with type "test" omitted
# Unsupported target "macros_test" with type "test" omitted
# Unsupported target "macros_try_join" with type "test" omitted
# Unsupported target "net_bind_resource" with type "test" omitted
# Unsupported target "net_lookup_host" with type "test" omitted
# Unsupported target "no_rt" with type "test" omitted
# Unsupported target "process_issue_2174" with type "test" omitted
# Unsupported target "process_issue_42" with type "test" omitted
# Unsupported target "process_kill_on_drop" with type "test" omitted
# Unsupported target "process_smoke" with type "test" omitted
# Unsupported target "read_to_string" with type "test" omitted
# Unsupported target "rt_basic" with type "test" omitted
# Unsupported target "rt_common" with type "test" omitted
# Unsupported target "rt_threaded" with type "test" omitted
# Unsupported target "signal_ctrl_c" with type "test" omitted
# Unsupported target "signal_drop_recv" with type "test" omitted
# Unsupported target "signal_drop_rt" with type "test" omitted
# Unsupported target "signal_drop_signal" with type "test" omitted
# Unsupported target "signal_multi_rt" with type "test" omitted
# Unsupported target "signal_no_rt" with type "test" omitted
# Unsupported target "signal_notify_both" with type "test" omitted
# Unsupported target "signal_twice" with type "test" omitted
# Unsupported target "signal_usr1" with type "test" omitted
# Unsupported target "stream_chain" with type "test" omitted
# Unsupported target "stream_collect" with type "test" omitted
# Unsupported target "stream_empty" with type "test" omitted
# Unsupported target "stream_fuse" with type "test" omitted
# Unsupported target "stream_iter" with type "test" omitted
# Unsupported target "stream_merge" with type "test" omitted
# Unsupported target "stream_once" with type "test" omitted
# Unsupported target "stream_pending" with type "test" omitted
# Unsupported target "stream_reader" with type "test" omitted
# Unsupported target "stream_stream_map" with type "test" omitted
# Unsupported target "stream_timeout" with type "test" omitted
# Unsupported target "sync_barrier" with type "test" omitted
# Unsupported target "sync_broadcast" with type "test" omitted
# Unsupported target "sync_cancellation_token" with type "test" omitted
# Unsupported target "sync_errors" with type "test" omitted
# Unsupported target "sync_mpsc" with type "test" omitted
# Unsupported target "sync_mutex" with type "test" omitted
# Unsupported target "sync_mutex_owned" with type "test" omitted
# Unsupported target "sync_notify" with type "test" omitted
# Unsupported target "sync_oneshot" with type "test" omitted
# Unsupported target "sync_rwlock" with type "test" omitted
# Unsupported target "sync_semaphore" with type "test" omitted
# Unsupported target "sync_semaphore_owned" with type "test" omitted
# Unsupported target "sync_watch" with type "test" omitted
# Unsupported target "task_blocking" with type "test" omitted
# Unsupported target "task_local" with type "test" omitted
# Unsupported target "task_local_set" with type "test" omitted
# Unsupported target "tcp_accept" with type "test" omitted
# Unsupported target "tcp_connect" with type "test" omitted
# Unsupported target "tcp_echo" with type "test" omitted
# Unsupported target "tcp_into_split" with type "test" omitted
# Unsupported target "tcp_peek" with type "test" omitted
# Unsupported target "tcp_shutdown" with type "test" omitted
# Unsupported target "tcp_split" with type "test" omitted
# Unsupported target "test_clock" with type "test" omitted
# Unsupported target "time_delay" with type "test" omitted
# Unsupported target "time_delay_queue" with type "test" omitted
# Unsupported target "time_interval" with type "test" omitted
# Unsupported target "time_rt" with type "test" omitted
# Unsupported target "time_throttle" with type "test" omitted
# Unsupported target "time_timeout" with type "test" omitted
# Unsupported target "udp" with type "test" omitted
# Unsupported target "uds_cred" with type "test" omitted
# Unsupported target "uds_datagram" with type "test" omitted
# Unsupported target "uds_split" with type "test" omitted
# Unsupported target "uds_stream" with type "test" omitted
""",
        sha256 = "5d34ca54d84bf2b5b4d7d31e901a8464f7b60ac145a284fba25ceb801f2ddccd",
        strip_prefix = "tokio-0.2.22",
        type = "tar.gz",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/crates/tokio/tokio-0.2.22.crate",
    )

    http_archive(
        name = "beep__vcpkg__0_2_10",
        # TODO: Allow configuring where rust_library comes from
        build_file_content = """# buildifier: disable=load
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
    "notice",  # MIT from expression "MIT OR Apache-2.0"
])

# Generated targets

# buildifier: leave-alone
rust_library(
    name = "vcpkg",
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
    version = "0.2.10",
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
""",
        sha256 = "6454029bf181f092ad1b853286f23e2c507d8e8194d01d92da4a55c274a5508c",
        strip_prefix = "vcpkg-0.2.10",
        type = "tar.gz",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/crates/vcpkg/vcpkg-0.2.10.crate",
    )


CRATE_TARGET_NAMES = {
    "bitflags": "@beep__bitflags__1_2_1//:bitflags",
    "bytes": "@beep__bytes__0_5_6//:bytes",
    "cc": "@beep__cc__1_0_62//:cc",
    "lazy_static": "@beep__lazy_static__1_4_0//:lazy_static",
    "libc": "@beep__libc__0_2_80//:libc",
    "libz-sys": "@beep__libz_sys__1_1_2//:libz_sys",
    "pin-project-lite": "@beep__pin_project_lite__0_1_12//:pin_project_lite",
    "pkg-config": "@beep__pkg_config__0_3_19//:pkg_config",
    "tokio": "@beep__tokio__0_2_22//:tokio",
    "vcpkg": "@beep__vcpkg__0_2_10//:vcpkg",
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
            "bitflags",
            "bytes",
            "cc",
            "lazy_static",
            "libc",
            "libz-sys",
            "pin-project-lite",
            "pkg-config",
            "tokio",
            "vcpkg",
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
        "//some:Cargo.toml": [crate("bitflags"), crate("bytes"), crate("cc"), crate("lazy_static"), crate("libc"), crate("libz-sys"), crate("pin-project-lite"), crate("pkg-config"), crate("vcpkg")],
    }
    return mapping[_absolutify(label)]

def dev_crates_from(label):
    mapping = {
        "//some:Cargo.toml": [],
    }
    return mapping[_absolutify(label)]

def build_crates_from(label):
    mapping = {
        "//some:Cargo.toml": [],
    }
    return mapping[_absolutify(label)]

def proc_macro_crates_from(label):
    mapping = {
        "//some:Cargo.toml": [],
    }
    return mapping[_absolutify(label)]

def _absolutify(label):
    if label.startswith("//") or label.startswith("@"):
        return label
    if label.startswith(":"):
        return "//" + native.package_name() + label
    return "//" + native.package_name() + ":" + label
"##;

    // Ignore header which contains a hash
    test(&config)
        .success()
        .stdout(predicates::str::ends_with(want_output));
}

#[test]
fn aliased_deps() {
    let cargo_toml_file = NamedTempFile::with_str_content(
        "Cargo.toml",
        r#"[package]
name = "basic"
version = "0.1.0"
edition = "2018"

[dependencies]
plist = "=1.0.0"
"#,
    )
    .expect("Error making temporary file");

    let config = Config {
        repository_name: "hurrah".to_owned(),
        cargo_toml_files: btreemap! { String::from("//some:Cargo.toml") => cargo_toml_file.path().to_path_buf() },
        overrides: Default::default(),
        repository_template: "https://crates-io.s3-us-west-1.amazonaws.com/crates/crates/{crate}/{crate}-{version}.crate".to_owned(),
        target_triples: vec!["x86_64-apple-darwin".to_owned()],
        packages: vec![],
        cargo: PathBuf::from(env!("CARGO")),
        rust_rules_workspace_name:crate_universe_resolver::config::default_rules_rust_workspace_name(),
        index_url:crate_universe_resolver::config::default_index_url(),
    };

    let want_output = r#"aliases = select({
        # Default
        "//conditions:default": {
            "@hurrah__xml_rs__0_8_3//:xml_rs": "xml_rs",
        },
    })"#;

    // Ignore header which contains a hash
    test(&config)
        .success()
        .stdout(predicates::str::contains(want_output));
}

#[test]
fn git_deps() {
    let cargo_toml_file = NamedTempFile::with_str_content(
        "Cargo.toml",
        r#"[package]
name = "has_git_deps"
version = "0.1.0"
edition = "2018"

[dependencies]
tonic-build = "=0.3.1"
anyhow = "=1.0.33"
itertools = "=0.9.0"
proc-macro2 = "=1.0.24"
quote = "=1.0.7"
syn = "=1.0.45"

[patch.crates-io]
prost = { git = "https://github.com/danburkert/prost.git", rev = "4ded4a98ef339da0b7babd4efee3fbe8adaf746b" }
prost-build = { git = "https://github.com/danburkert/prost.git", rev = "4ded4a98ef339da0b7babd4efee3fbe8adaf746b" }
prost-derive = { git = "https://github.com/danburkert/prost.git", rev = "4ded4a98ef339da0b7babd4efee3fbe8adaf746b" }
prost-types = { git = "https://github.com/danburkert/prost.git", rev = "4ded4a98ef339da0b7babd4efee3fbe8adaf746b" }
"#,
    )
        .expect("Error making temporary file");

    let config = Config {
        repository_name: "yep".to_owned(),
        cargo_toml_files: btreemap! { String::from("//some:Cargo.toml") => cargo_toml_file.path().to_path_buf() },
        overrides: Default::default(),
        repository_template: "https://crates-io.s3-us-west-1.amazonaws.com/crates/crates/{crate}/{crate}-{version}.crate".to_owned(),
        target_triples: vec!["x86_64-apple-darwin".to_owned()],
        packages: vec![],
        cargo: PathBuf::from(env!("CARGO")),
        rust_rules_workspace_name:crate_universe_resolver::config::default_rules_rust_workspace_name(),
        index_url:crate_universe_resolver::config::default_index_url(),
    };

    let wanted_prost = r###"    new_git_repository(
        name = "yep__prost__0_6_1",
        strip_prefix = "",
        build_file_content = """# buildifier: disable=load
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
    "notice",  # Apache-2.0 from expression "Apache-2.0"
])

# Generated targets
# Unsupported target "varint" with type "bench" omitted

# buildifier: leave-alone
rust_library(
    name = "prost",
    deps = [
        "@yep__bytes__0_5_6//:bytes",
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2018",
    proc_macro_deps = [
        "@yep__prost_derive__0_6_1//:prost_derive",
    ],
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
    version = "0.6.1",
    tags = [
        "cargo-raze",
        "manual",
    ],
    crate_features = [
        "prost-derive",
    ],
    aliases = select({
        # Default
        "//conditions:default": {
        },
    }),
)
""",
        remote = "https://github.com/danburkert/prost.git",
        # TODO: tag?
        commit = "4ded4a98ef339da0b7babd4efee3fbe8adaf746b",
    )"###;

    let unwanted_prost = r###"http_archive(
        name = "yep__prost__0_6_1","###;

    let wanted_prost_build = r###"    new_git_repository(
        name = "yep__prost_build__0_6_1",
        strip_prefix = "prost-build",
        build_file_content = """# buildifier: disable=load
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
    "notice",  # Apache-2.0 from expression "Apache-2.0"
])

# Generated targets
# buildifier: disable=load-on-top
load(
    "@rules_rust//cargo:cargo_build_script.bzl",
    "cargo_build_script",
)

# buildifier: leave-alone
cargo_build_script(
    name = "prost_build_build_script",
    srcs = glob(["**/*.rs"]),
    crate_root = "build.rs",
    edition = "2018",
    deps = [
        "@yep__which__4_0_2//:which",
    ],
    rustc_flags = [
        "--cap-lints=allow",
    ],
    crate_features = [
    ],
    build_script_env = {
    },
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
    tags = [
        "cargo-raze",
        "manual",
    ],
    version = "0.6.1",
    visibility = ["//visibility:private"],
)


# buildifier: leave-alone
rust_library(
    name = "prost_build",
    deps = [
        ":prost_build_build_script",
        "@yep__bytes__0_5_6//:bytes",
        "@yep__heck__0_3_2//:heck",
        "@yep__itertools__0_9_0//:itertools",
        "@yep__log__0_4_14//:log",
        "@yep__multimap__0_8_3//:multimap",
        "@yep__petgraph__0_5_1//:petgraph",
        "@yep__prost__0_6_1//:prost",
        "@yep__prost_types__0_6_1//:prost_types",
        "@yep__tempfile__3_2_0//:tempfile",
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2018",
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
    version = "0.6.1",
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
""",
        remote = "https://github.com/danburkert/prost.git",
        # TODO: tag?
        commit = "4ded4a98ef339da0b7babd4efee3fbe8adaf746b",
    )"###;

    let unwanted_prost_build = r###"http_archive(
        name = "yep__prost_build__0_6_1","###;

    let wanted_prost_derive = r###"    new_git_repository(
        name = "yep__prost_derive__0_6_1",
        strip_prefix = "prost-derive",
        build_file_content = """# buildifier: disable=load
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
    "notice",  # Apache-2.0 from expression "Apache-2.0"
])

# Generated targets

# buildifier: leave-alone
rust_proc_macro(
    name = "prost_derive",
    deps = [
        "@yep__anyhow__1_0_33//:anyhow",
        "@yep__itertools__0_9_0//:itertools",
        "@yep__proc_macro2__1_0_24//:proc_macro2",
        "@yep__quote__1_0_7//:quote",
        "@yep__syn__1_0_45//:syn",
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2018",
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
    version = "0.6.1",
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
""",
        remote = "https://github.com/danburkert/prost.git",
        # TODO: tag?
        commit = "4ded4a98ef339da0b7babd4efee3fbe8adaf746b",
    )"###;

    let unwanted_prost_derive = r###"http_archive(
        name = "yep__prost_derive__0_6_1","###;

    let wanted_prost_types = r###"    new_git_repository(
        name = "yep__prost_types__0_6_1",
        strip_prefix = "prost-types",
        build_file_content = """# buildifier: disable=load
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
    "notice",  # Apache-2.0 from expression "Apache-2.0"
])

# Generated targets

# buildifier: leave-alone
rust_library(
    name = "prost_types",
    deps = [
        "@yep__bytes__0_5_6//:bytes",
        "@yep__prost__0_6_1//:prost",
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2018",
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
    version = "0.6.1",
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
""",
        remote = "https://github.com/danburkert/prost.git",
        # TODO: tag?
        commit = "4ded4a98ef339da0b7babd4efee3fbe8adaf746b",
    )"###;

    let unwanted_prost_types = r###"http_archive(
        name = "yep__prost_types__0_6_1","###;

    let result = test(&config).success();
    result
        .stdout(predicates::str::contains(wanted_prost))
        .stdout(predicates::str::contains(wanted_prost_build))
        .stdout(predicates::str::contains(wanted_prost_derive))
        .stdout(predicates::str::contains(wanted_prost_types))
        .stdout(predicates::str::contains(unwanted_prost).not())
        .stdout(predicates::str::contains(unwanted_prost_build).not())
        .stdout(predicates::str::contains(unwanted_prost_derive).not())
        .stdout(predicates::str::contains(unwanted_prost_types).not());
}

#[test]
#[ignore] // TODO: Unignore when we fix workspace support - currently broken by the fact that we generate our Cargo.toml somewhere standalone but don't strip out the workspace information
fn workspace_root() {
    let dir = tempfile::tempdir().expect("Could not make tempdir");
    let subdir = dir.path().join("subcrate");
    create_dir_all(&subdir).expect("Could not make subcrate dir");
    let workspace_cargo_toml = dir.path().join("Cargo.toml");
    std::fs::write(
        &workspace_cargo_toml,
        r#"[workspace]
members = ["subcrate"]

[package]
name = "ws"
version = "0.1.0"
edition = "2018"

[dependencies]
lazy_static = "=1.4.0"

# TODO: do not depend on this section to be present rules_rust_external.
[lib]
path = "lib.rs"
"#
        .as_bytes(),
    )
    .expect("Failed to write Cargo.toml");

    std::fs::write(
        subdir.join("Cargo.toml"),
        r#"[package]
name = "subcrate"
version = "0.1.0"
edition = "2018"

[dependencies]
bitflags = "=1.2.1"

# TODO: do not depend on this section to be present rules_rust_external.
[lib]
path = "lib.rs"
"#
        .as_bytes(),
    )
    .expect("Failed to write Cargo.toml");

    let config = Config {
        repository_name: "another".to_owned(),
        cargo_toml_files: btreemap! { String::from("//some/other:Cargo.toml") => workspace_cargo_toml },
        overrides: Default::default(),
        repository_template: "https://crates-io.s3-us-west-1.amazonaws.com/crates/crates/{crate}/{crate}-{version}.crate".to_owned(),
        target_triples: vec!["x86_64-apple-darwin".to_owned()],
        packages: vec![],
        cargo: PathBuf::from(env!("CARGO")),
        rust_rules_workspace_name:crate_universe_resolver::config::default_rules_rust_workspace_name(),
        index_url:crate_universe_resolver::config::default_index_url(),
    };

    test(&config).success().stdout(eq(r#"load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

def pinned_rust_install():
    http_archive(
    name = "bitflags",
    # TODO: Allow configuring where rust_library comes from
    build_file_content = """load("@rules_rust//rust:defs.bzl", "rust_library")
load("@rules_rust//cargo:cargo_build_script.bzl", "cargo_build_script")

cargo_build_script(
    name = "bitflags_build_script",
    srcs = glob(["**/*.rs"]),
    crate_root = "build.rs",
    deps = [],
    proc_macro_deps = [],
    data = glob(["**"]),
    edition = "2015",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    crate_features = [
        "default"
    ],
    version = "1.2.1",
)


rust_library(
    name = "bitflags",
    srcs = glob(["**/*.rs"]),
    crate_features = [
        "default"
    ],
    crate_root = "src/lib.rs",
    edition = "2015",
    proc_macro_deps = [],
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "1.2.1",
    visibility = ["//visibility:public"],
    deps = [
        ":bitflags_build_script"
    ],
)
""",
    strip_prefix = "bitflags-1.2.1",
    type = "tar.gz",
    url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/crates/bitflags/bitflags-1.2.1.crate",
)
    http_archive(
    name = "lazy_static",
    # TODO: Allow configuring where rust_library comes from
    build_file_content = """load("@rules_rust//rust:defs.bzl", "rust_library")

rust_library(
    name = "lazy_static",
    srcs = glob(["**/*.rs"]),
    crate_features = [],
    crate_root = "src/lib.rs",
    edition = "2015",
    proc_macro_deps = [],
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "1.4.0",
    visibility = ["//visibility:public"],
    deps = [],
)
""",
    strip_prefix = "lazy_static-1.4.0",
    type = "tar.gz",
    url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/crates/lazy_static/lazy_static-1.4.0.crate",
)
"#
    ));
}

fn test(config: &Config) -> Assert {
    Command::cargo_bin(env!("CARGO_PKG_NAME"))
        .unwrap()
        .arg("--input_path")
        .arg("/dev/stdin")
        .arg("--output_path")
        .arg("/dev/stdout")
        .arg("--repo-name")
        .arg("whatever")
        .write_stdin(serde_json::to_string(&config).unwrap())
        .assert()
}

// Tests still to add:
// Transitive deps
// Lib and bin in the same crate
