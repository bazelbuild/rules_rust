workspace(name = "examples")

local_repository(
    name = "rules_rust",
    path = "../../",
)

load("@rules_rust//rust:repositories.bzl", "rules_rust_dependencies", "rust_register_toolchains")

rules_rust_dependencies()

rust_register_toolchains(
    edition = "2018",
)

load("@rules_rust//crate_universe:repositories.bzl", "crate_universe_dependencies")

crate_universe_dependencies(bootstrap = True)

load("@rules_rust//crate_universe:defs.bzl", "crate", "crates_repository", "render_config", "splicing_config")

###############################################################################
# A L I A S   R U L E
###############################################################################

crates_repository(
    name = "alias_rule_global_alias_annotation_none",
    annotations = {
        "test_data_passing_crate": [crate.annotation(
            alias_rule = None,
        )],
    },
    cargo_lockfile = "//alias_rule:Cargo.Bazel.lock",
    # `generator` is not necessary in official releases.
    # See load satement for `cargo_bazel_bootstrap`.
    generator = "@cargo_bazel_bootstrap//:cargo-bazel",
    lockfile = "//alias_rule:cargo-bazel-lock_global_alias_annotation_none.json",
    packages = {
        "test_data_passing_crate": crate.spec(
            version = "0.1.0",
        ),
    },
    render_config = render_config(
        default_alias_rule = "alias",
    ),
)

load(
    "@alias_rule_global_alias_annotation_none//:defs.bzl",
    alias_rule_global_alias_annotation_none_crate_repositories = "crate_repositories",
)

alias_rule_global_alias_annotation_none_crate_repositories()

crates_repository(
    name = "alias_rule_global_alias_annotation_opt",
    annotations = {
        "test_data_passing_crate": [crate.annotation(
            alias_rule = "opt",
        )],
    },
    cargo_lockfile = "//alias_rule:Cargo.Bazel.lock",
    # `generator` is not necessary in official releases.
    # See load satement for `cargo_bazel_bootstrap`.
    generator = "@cargo_bazel_bootstrap//:cargo-bazel",
    lockfile = "//alias_rule:cargo-bazel-lock_global_alias_annotation_opt.json",
    packages = {
        "test_data_passing_crate": crate.spec(
            version = "0.1.0",
        ),
    },
    render_config = render_config(
        default_alias_rule = "alias",
    ),
)

load(
    "@alias_rule_global_alias_annotation_opt//:defs.bzl",
    alias_rule_global_alias_annotation_opt_crate_repositories = "crate_repositories",
)

alias_rule_global_alias_annotation_opt_crate_repositories()

crates_repository(
    name = "alias_rule_global_opt_annotation_none",
    annotations = {
        "test_data_passing_crate": [crate.annotation(
            alias_rule = None,
        )],
    },
    cargo_lockfile = "//alias_rule:Cargo.Bazel.lock",
    # `generator` is not necessary in official releases.
    # See load satement for `cargo_bazel_bootstrap`.
    generator = "@cargo_bazel_bootstrap//:cargo-bazel",
    lockfile = "//alias_rule:cargo-bazel-lock_global_opt_annotation_none.json",
    packages = {
        "test_data_passing_crate": crate.spec(
            version = "0.1.0",
        ),
    },
    render_config = render_config(
        default_alias_rule = "opt",
    ),
)

load(
    "@alias_rule_global_opt_annotation_none//:defs.bzl",
    alias_rule_global_opt_annotation_none_crate_repositories = "crate_repositories",
)

alias_rule_global_opt_annotation_none_crate_repositories()

crates_repository(
    name = "alias_rule_global_opt_annotation_alias",
    annotations = {
        "test_data_passing_crate": [crate.annotation(
            alias_rule = "alias",
        )],
    },
    cargo_lockfile = "//alias_rule:Cargo.Bazel.lock",
    # `generator` is not necessary in official releases.
    # See load satement for `cargo_bazel_bootstrap`.
    generator = "@cargo_bazel_bootstrap//:cargo-bazel",
    lockfile = "//alias_rule:cargo-bazel-lock_global_opt_annotation_alias.json",
    packages = {
        "test_data_passing_crate": crate.spec(
            version = "0.1.0",
        ),
    },
    render_config = render_config(
        default_alias_rule = "opt",
    ),
)

load(
    "@alias_rule_global_opt_annotation_alias//:defs.bzl",
    alias_rule_global_opt_annotation_alias_crate_repositories = "crate_repositories",
)

alias_rule_global_opt_annotation_alias_crate_repositories()

crates_repository(
    name = "alias_rule_global_opt_annotation_dbg",
    annotations = {
        "test_data_passing_crate": [crate.annotation(
            alias_rule = "dbg",
        )],
    },
    cargo_lockfile = "//alias_rule:Cargo.Bazel.lock",
    # `generator` is not necessary in official releases.
    # See load satement for `cargo_bazel_bootstrap`.
    generator = "@cargo_bazel_bootstrap//:cargo-bazel",
    lockfile = "//alias_rule:cargo-bazel-lock_global_opt_annotation_dbg.json",
    packages = {
        "test_data_passing_crate": crate.spec(
            version = "0.1.0",
        ),
    },
    render_config = render_config(
        default_alias_rule = "opt",
    ),
)

load(
    "@alias_rule_global_opt_annotation_dbg//:defs.bzl",
    alias_rule_global_opt_annotation_dbg_crate_repositories = "crate_repositories",
)

alias_rule_global_opt_annotation_dbg_crate_repositories()

crates_repository(
    name = "alias_rule_global_dbg_annotation_fastbuild",
    annotations = {
        "test_data_passing_crate": [crate.annotation(
            alias_rule = "fastbuild",
        )],
    },
    cargo_lockfile = "//alias_rule:Cargo.Bazel.lock",
    # `generator` is not necessary in official releases.
    # See load satement for `cargo_bazel_bootstrap`.
    generator = "@cargo_bazel_bootstrap//:cargo-bazel",
    lockfile = "//alias_rule:cargo-bazel-lock_global_dbg_annotation_fastbuild.json",
    packages = {
        "test_data_passing_crate": crate.spec(
            version = "0.1.0",
        ),
    },
    render_config = render_config(
        default_alias_rule = "dbg",
    ),
)

load(
    "@alias_rule_global_dbg_annotation_fastbuild//:defs.bzl",
    alias_rule_global_dbg_annotation_fastbuild_crate_repositories = "crate_repositories",
)

alias_rule_global_dbg_annotation_fastbuild_crate_repositories()

crates_repository(
    name = "alias_rule_global_custom_annotation_none",
    annotations = {
        "test_data_passing_crate": [crate.annotation(
            alias_rule = None,
        )],
    },
    cargo_lockfile = "//alias_rule:Cargo.Bazel.lock",
    # `generator` is not necessary in official releases.
    # See load satement for `cargo_bazel_bootstrap`.
    generator = "@cargo_bazel_bootstrap//:cargo-bazel",
    lockfile = "//alias_rule:cargo-bazel-lock_global_custom_annotation_none.json",
    packages = {
        "test_data_passing_crate": crate.spec(
            version = "0.1.0",
        ),
    },
    render_config = render_config(
        default_alias_rule = "@//alias_rule:alias_rules.bzl:alias_rule",
    ),
)

load(
    "@alias_rule_global_custom_annotation_none//:defs.bzl",
    alias_rule_global_custom_annotation_none_crate_repositories = "crate_repositories",
)

alias_rule_global_custom_annotation_none_crate_repositories()

###############################################################################
# C A R G O   A L I A S E S
###############################################################################

crates_repository(
    name = "cargo_aliases",
    annotations = {
        "names": [crate.annotation(
            shallow_since = "1646516410 -0700",
            version = "0.12.1-dev",
        )],
    },
    cargo_lockfile = "//cargo_aliases:Cargo.Bazel.lock",
    # `generator` is not necessary in official releases.
    # See load satement for `cargo_bazel_bootstrap`.
    generator = "@cargo_bazel_bootstrap//:cargo-bazel",
    lockfile = "//cargo_aliases:cargo-bazel-lock.json",
    manifests = ["//cargo_aliases:Cargo.toml"],
)

load(
    "@cargo_aliases//:defs.bzl",
    cargo_aliases_crate_repositories = "crate_repositories",
)

cargo_aliases_crate_repositories()

###############################################################################
# C A R G O   B I N D E P S
###############################################################################

crates_repository(
    name = "crate_index_cargo_bindeps",
    cargo_lockfile = "//cargo_bindeps:Cargo.lock",
    generate_binaries = True,
    # `generator` is not necessary in official releases.
    # See load satement for `cargo_bazel_bootstrap`.
    generator = "@cargo_bazel_bootstrap//:cargo-bazel",
    manifests = ["//cargo_bindeps:Cargo.toml"],
    rust_version = "nightly",
)

load(
    "@crate_index_cargo_bindeps//:defs.bzl",
    cargo_bindeps_crate_repositories = "crate_repositories",
)

cargo_bindeps_crate_repositories()

###############################################################################
# C A R G O   L O C A L
###############################################################################

crates_repository(
    name = "crate_index_cargo_local",
    cargo_lockfile = "//cargo_local:Cargo.lock",
    # `generator` is not necessary in official releases.
    # See load satement for `cargo_bazel_bootstrap`.
    generator = "@cargo_bazel_bootstrap//:cargo-bazel",
    manifests = ["//cargo_local:Cargo.toml"],
)

load(
    "@crate_index_cargo_local//:defs.bzl",
    cargo_local_crate_repositories = "crate_repositories",
)

cargo_local_crate_repositories()

###############################################################################
# C A R G O   R E M O T E
###############################################################################

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "names",
    build_file = "//cargo_remote:BUILD.names.bazel",
    sha256 = "eab40caca5805624ba31d028913931c3d054b22daafff6f43e3435cfa9fb761e",
    strip_prefix = "names-0.13.0",
    urls = ["https://github.com/fnichol/names/archive/refs/tags/v0.13.0.zip"],
)

crates_repository(
    name = "crate_index_cargo_remote",
    cargo_lockfile = "@names//:Cargo.lock",
    # `generator` is not necessary in official releases.
    # See load satement for `cargo_bazel_bootstrap`.
    generator = "@cargo_bazel_bootstrap//:cargo-bazel",
    manifests = ["@names//:Cargo.toml"],
)

load(
    "@crate_index_cargo_remote//:defs.bzl",
    cargo_remote_crate_repositories = "crate_repositories",
)

cargo_remote_crate_repositories()

###############################################################################
# C A R G O   W O R K S P A C E
###############################################################################

crates_repository(
    name = "crate_index_cargo_workspace",
    cargo_config = "//cargo_workspace:.cargo/config.toml",
    cargo_lockfile = "//cargo_workspace:Cargo.Bazel.lock",
    # `generator` is not necessary in official releases.
    # See load satement for `cargo_bazel_bootstrap`.
    generator = "@cargo_bazel_bootstrap//:cargo-bazel",
    lockfile = "//cargo_workspace:cargo-bazel-lock.json",
    manifests = [
        "//cargo_workspace:Cargo.toml",
        "//cargo_workspace/num_printer:Cargo.toml",
        "//cargo_workspace/printer:Cargo.toml",
        "//cargo_workspace/rng:Cargo.toml",
    ],
)

load(
    "@crate_index_cargo_workspace//:defs.bzl",
    cargo_workspace_crate_repositories = "crate_repositories",
)

cargo_workspace_crate_repositories()

###############################################################################
# C A R G O   C O N D I T I O N A L   D E P S
###############################################################################

crates_repository(
    name = "crate_index_cargo_conditional_deps",
    cargo_lockfile = "//cargo_conditional_deps:Cargo.Bazel.lock",
    # `generator` is not necessary in official releases.
    # See load satement for `cargo_bazel_bootstrap`.
    generator = "@cargo_bazel_bootstrap//:cargo-bazel",
    lockfile = "//cargo_conditional_deps:cargo-bazel-lock.json",
    manifests = [
        "//cargo_conditional_deps:Cargo.toml",
    ],
)

load(
    "@crate_index_cargo_conditional_deps//:defs.bzl",
    cargo_conditional_deps_crate_repositories = "crate_repositories",
)

cargo_conditional_deps_crate_repositories()

###############################################################################
# M U L T I   P A C K A G E
###############################################################################

# The name here needs to be short to avoid long path issues on windows
# when running the `libnghttp2-sys` build script.
multi_pkg_example_name = "m_pkgs"

crates_repository(
    name = multi_pkg_example_name,
    annotations = {
        "curl-sys": [crate.annotation(
            gen_build_script = False,
            deps = [
                "@m_pkgs__curl//:curl",
            ],
        )],
        "httpmock": [crate.annotation(
            shallow_since = "1673473097 +0100",
        )],
        "isahc": [crate.annotation(
            shallow_since = "1667787880 -0600",
        )],
        "libnghttp2-sys": [crate.annotation(
            build_script_data_glob = ["nghttp2/**"],
            data_glob = ["nghttp2/**"],
        )],
        "wepoll-ffi": [crate.annotation(
            build_script_data_glob = ["vendor/**"],
        )],
    },
    cargo_lockfile = "//multi_package:Cargo.Bazel.lock",
    # `generator` is not necessary in official releases.
    # See load satement for `cargo_bazel_bootstrap`.
    generator = "@cargo_bazel_bootstrap//:cargo-bazel",
    lockfile = "//multi_package:cargo-bazel-lock.json",
    manifests = [
        "//multi_package/pkg_a:Cargo.toml",
        "//multi_package/sub_pkgs/pkg_b:Cargo.toml",
        "//multi_package/sub_pkgs/pkg_c:Cargo.toml",
    ],
)

load("//multi_package/3rdparty:third_party_deps.bzl", "third_party_deps")

third_party_deps(
    prefix = multi_pkg_example_name,
)

load(
    "@m_pkgs//:defs.bzl",
    multi_pkg_crate_repositories = "crate_repositories",
)

multi_pkg_crate_repositories()

###############################################################################
# N O   C A R G O   M A N I F E S T S
###############################################################################

crates_repository(
    name = "no_cargo",
    annotations = {
        "axum": [crate.annotation(
            compile_data_glob = ["**/*.md"],
        )],
    },
    cargo_lockfile = "//no_cargo_manifests:Cargo.Bazel.lock",
    # `generator` is not necessary in official releases.
    # See load satement for `cargo_bazel_bootstrap`.
    generator = "@cargo_bazel_bootstrap//:cargo-bazel",
    lockfile = "//no_cargo_manifests:cargo-bazel-lock.json",
    packages = {
        "axum": crate.spec(
            version = "0.4.0",
        ),
        "hyper": crate.spec(
            features = ["full"],
            version = "0.14.22",
        ),
        "mime": crate.spec(
            version = "0.3",
        ),
        "serde_json": crate.spec(
            version = "1.0",
        ),
        # TODO: This dependency is added and pinned forward due to the
        # following issue: https://github.com/hyperium/hyper/issues/3038
        "socket2": crate.spec(
            features = ["all"],
            version = "0.4.7",
        ),
        "tokio": crate.spec(
            features = ["full"],
            version = "1.17.0",
        ),
        "tower": crate.spec(
            features = ["util"],
            version = "0.4",
        ),
        "tower-http": crate.spec(
            features = ["trace"],
            version = "0.2.1",
        ),
        "tracing": crate.spec(
            version = "0.1",
        ),
        "tracing-subscriber": crate.spec(
            version = "0.3",
        ),
    },
    splicing_config = splicing_config(
        resolver_version = "2",
    ),
)

load(
    "@no_cargo//:defs.bzl",
    no_cargo_crate_repositories = "crate_repositories",
)

no_cargo_crate_repositories()

###############################################################################
# U S I N G   C X X   C R A T E
###############################################################################

# CXX crate is a bit different since there are C++ headers provided.

crates_repository(
    name = "using_cxx",
    cargo_lockfile = "//using_cxx:Cargo.Bazel.lock",
    # `generator` is not necessary in official releases.
    # See load satement for `cargo_bazel_bootstrap`.
    generator = "@cargo_bazel_bootstrap//:cargo-bazel",
    lockfile = "//using_cxx:cargo-bazel-lock.json",
    packages = {
        "cxx": crate.spec(
            version = "1.0.109",
        ),
    },
    splicing_config = splicing_config(
        resolver_version = "2",
    ),
)

load(
    "@using_cxx//:defs.bzl",
    using_cxx_crate_repositories = "crate_repositories",
)

using_cxx_crate_repositories()

# The codegen tool needed by cxx.
http_archive(
    name = "cxxbridge-cmd",
    build_file_content = """
load("@rules_rust//rust:defs.bzl", "rust_binary")
load("@cxxbridge_cmd_deps//:defs.bzl", "aliases", "all_crate_deps")

rust_binary(
    name = "cxxbridge-cmd",
    srcs = glob(["src/**/*.rs"]),
    aliases = aliases(),
    data = [
        "src/gen/include/cxx.h",
    ],
    edition = "2021",
    visibility = ["//visibility:public"],
    deps = all_crate_deps(
        normal = True,
    ),
)
    """,
    sha256 = "d93600487d429c8bf013ee96719af4e62e809ac57fc4cac24f17cf58e4526009",
    strip_prefix = "cxxbridge-cmd-1.0.109",
    type = "tar.gz",
    urls = ["https://static.crates.io/crates/cxxbridge-cmd/cxxbridge-cmd-1.0.109.crate"],
)

crates_repository(
    name = "cxxbridge_cmd_deps",
    cargo_lockfile = "//using_cxx:cxxbridge-cmd.Cargo.lock",
    # `generator` is not necessary in official releases.
    # See load satement for `cargo_bazel_bootstrap`.
    generator = "@cargo_bazel_bootstrap//:cargo-bazel",
    lockfile = "//using_cxx:cxxbridge-cmd.Cargo.Bazel.lock",
    manifests = ["@cxxbridge-cmd//:Cargo.toml"],
    splicing_config = splicing_config(
        resolver_version = "2",
    ),
)

load("@cxxbridge_cmd_deps//:defs.bzl", cxxbridge_cmd_deps = "crate_repositories")

cxxbridge_cmd_deps()

###############################################################################
# V E N D O R   E X T E R N A L
###############################################################################

http_archive(
    name = "names_external",
    build_file = "//cargo_remote:BUILD.names.bazel",
    sha256 = "eab40caca5805624ba31d028913931c3d054b22daafff6f43e3435cfa9fb761e",
    strip_prefix = "names-0.13.0",
    urls = ["https://github.com/fnichol/names/archive/refs/tags/v0.13.0.zip"],
)

load(
    "//vendor_external/crates:crates.bzl",
    crates_vendor_external_repositories = "crate_repositories",
)

crates_vendor_external_repositories()

###############################################################################
# V E N D O R   R E M O T E   M A N I F E S T S
###############################################################################

load(
    "//vendor_remote_manifests/crates:crates.bzl",
    crates_vendor_manifests_repositories = "crate_repositories",
)

crates_vendor_manifests_repositories()

###############################################################################
# V E N D O R   R E M O T E   P A C K A G E S
###############################################################################

load(
    "//vendor_remote_pkgs/crates:crates.bzl",
    crates_vendor_packages_repositories = "crate_repositories",
)

crates_vendor_packages_repositories()

###############################################################################
# C O M P L I C A T E D   D E P E N D E N C I E S
###############################################################################

http_archive(
    name = "rules_foreign_cc",
    sha256 = "1eee5d216a3cec7a4c731f71ed731ac353290b1db61ab68b79440655bcb9acaa",
    strip_prefix = "rules_foreign_cc-7ce62009557d73da9aa0d2a1ca7eded49078b3cf",
    # Pulls in https://github.com/bazelbuild/rules_foreign_cc/pull/1163 and https://github.com/bazelbuild/rules_foreign_cc/pull/1199 which aren't currently in a release.
    url = "https://github.com/bazelbuild/rules_foreign_cc/archive/7ce62009557d73da9aa0d2a1ca7eded49078b3cf.tar.gz",
)

load("@rules_foreign_cc//foreign_cc:repositories.bzl", "rules_foreign_cc_dependencies")

rules_foreign_cc_dependencies()

http_archive(
    name = "aspect_bazel_lib",
    sha256 = "f5ea76682b209cc0bd90d0f5a3b26d2f7a6a2885f0c5f615e72913f4805dbb0d",
    strip_prefix = "bazel-lib-2.5.0",
    url = "https://github.com/aspect-build/bazel-lib/releases/download/v2.5.0/bazel-lib-v2.5.0.tar.gz",
)

load("@aspect_bazel_lib//lib:repositories.bzl", "aspect_bazel_lib_dependencies", "aspect_bazel_lib_register_toolchains")

aspect_bazel_lib_dependencies()

aspect_bazel_lib_register_toolchains()

load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")

git_repository(
    name = "boringssl",
    commit = "44b3df6f03d85c901767250329c571db405122d5",
    patch_args = ["-p1"],
    patches = [
        "//complicated_dependencies:boringssl-filegroup.patch",
        # On the macOS bazelci builders, there's a system-installed openssl, and that takes priority over -isystem flags, which is what cc_library.includes uses.
        # This forces our local system-includes to be chosen with higher priority, which avoids conflicts.
        "//complicated_dependencies:boringssl-system-includes.patch",
    ],
    remote = "https://github.com/google/boringssl.git",
)

crates_repository(
    name = "complicated_dependencies",
    annotations = {
        # boringssl natively builds with Bazel, but boring-sys tries to build it with cmake.
        # We could pass boring-sys a cmake binary it can invoke, but the boring-sys build script wouldn't get to exploit the caching and parallelism of full Bazel builds of boringssl.
        # Instead, we use the build script env var hooks to point the build script at the output of Bazel building boringssl.
        "boring-sys": [
            crate.annotation(
                build_script_data = [
                    "@//complicated_dependencies:boringssl_gen_dir",
                    "@boringssl//:headers",
                ],
                build_script_env = {
                    # Ideally this would use an execpath macro, but we need to point at a directory and that's fiddly. We could probably copy the directory somewhere and point at that... For now, this works.
                    "BORING_BSSL_INCLUDE_PATH": "$${pwd}/external/boringssl/src/include",
                    "BORING_BSSL_PATH": "$(execpath @//complicated_dependencies:boringssl_gen_dir)",
                },
                compile_data = [
                    "@//complicated_dependencies:boringssl_gen_dir",
                    "@boringssl//:headers",
                ],
            ),
        ],
        # zlib-ng-sys's build script invokes cmake, so we need to make cmake available.
        # Fortunately, rules_foreign_cc has a cmake toolchain we can use.
        "libz-ng-sys": [crate.annotation(
            # Setting build_script_data makes the files available on disk when the rule runs.
            build_script_data = ["@rules_foreign_cc//toolchains:current_cmake_toolchain"],
            build_script_env = {
                # The toolchain supplies a value of $(CMAKE) which is an execroot-relative path, so we need to prefix it with $${pwd}/ because build scripts don't typically run in the execroot unlike most bazel rules, for improved compatibility with Cargo.
                "CMAKE": "$${pwd}/$(CMAKE)",
            },
            # Setting build_script_toolchains makes makefile variable substitution work so that we can reference $(CNAME) in attributes.
            build_script_toolchains = ["@rules_foreign_cc//toolchains:current_cmake_toolchain"],
        )],
    },
    cargo_lockfile = "//complicated_dependencies:Cargo.Bazel.lock",
    # `generator` is not necessary in official releases.
    # See load satement for `cargo_bazel_bootstrap`.
    generator = "@cargo_bazel_bootstrap//:cargo-bazel",
    lockfile = "//complicated_dependencies:cargo-bazel-lock.json",
    packages = {
        "boring": crate.spec(
            version = "3.0.4",
        ),
        "libz-ng-sys": crate.spec(
            version = "=1.1.15",
        ),
    },
    splicing_config = splicing_config(
        resolver_version = "2",
    ),
)

load(
    "@complicated_dependencies//:defs.bzl",
    complicated_dependencies_crate_repositories = "crate_repositories",
)

complicated_dependencies_crate_repositories()

###############################################################################
# O V E R R I D E  T A R G E T
###############################################################################

crates_repository(
    name = "override_target",
    annotations = {
        "foo": [crate.annotation(
            override_targets = {"lib": "@//override_target:foo"},
        )],
    },
    cargo_lockfile = "//override_target:Cargo.Bazel.lock",
    # `generator` is not necessary in official releases.
    # See load satement for `cargo_bazel_bootstrap`.
    generator = "@cargo_bazel_bootstrap//:cargo-bazel",
    lockfile = "//override_target:cargo-bazel-lock.json",
    packages = {
        "foo": crate.spec(
            version = "0.0.0",
        ),
    },
    splicing_config = splicing_config(
        resolver_version = "2",
    ),
)

load(
    "@override_target//:defs.bzl",
    override_target_crate_repositories = "crate_repositories",
)

override_target_crate_repositories()

###############################################################################

# Used for Bazel CI
http_archive(
    name = "bazelci_rules",
    sha256 = "eca21884e6f66a88c358e580fd67a6b148d30ab57b1680f62a96c00f9bc6a07e",
    strip_prefix = "bazelci_rules-1.0.0",
    url = "https://github.com/bazelbuild/continuous-integration/releases/download/rules-1.0.0/bazelci_rules-1.0.0.tar.gz",
)

load("@bazelci_rules//:rbe_repo.bzl", "rbe_preconfig")

# Creates a default toolchain config for RBE.
# Use this as is if you are using the rbe_ubuntu16_04 container,
# otherwise refer to RBE docs.
rbe_preconfig(
    name = "buildkite_config",
    toolchain = "ubuntu1804-bazel-java11",
)
