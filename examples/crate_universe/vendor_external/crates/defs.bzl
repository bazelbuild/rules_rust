###############################################################################
# @generated
# DO NOT MODIFY: This file is auto-generated by a crate_universe tool. To
# regenerate this file, run the following:
#
#     bazel run @//vendor_external:crates_vendor
###############################################################################
"""
# `crates_repository` API

- [aliases](#aliases)
- [crate_deps](#crate_deps)
- [all_crate_deps](#all_crate_deps)
- [crate_repositories](#crate_repositories)

"""

load("@bazel_skylib//lib:selects.bzl", "selects")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

###############################################################################
# MACROS API
###############################################################################

# An identifier that represent common dependencies (unconditional).
_COMMON_CONDITION = ""

def _flatten_dependency_maps(all_dependency_maps):
    """Flatten a list of dependency maps into one dictionary.

    Dependency maps have the following structure:

    ```python
    DEPENDENCIES_MAP = {
        # The first key in the map is a Bazel package
        # name of the workspace this file is defined in.
        "workspace_member_package": {

            # Not all dependencies are supported for all platforms.
            # the condition key is the condition required to be true
            # on the host platform.
            "condition": {

                # An alias to a crate target.     # The label of the crate target the
                # Aliases are only crate names.   # package name refers to.
                "package_name":                   "@full//:label",
            }
        }
    }
    ```

    Args:
        all_dependency_maps (list): A list of dicts as described above

    Returns:
        dict: A dictionary as described above
    """
    dependencies = {}

    for workspace_deps_map in all_dependency_maps:
        for pkg_name, conditional_deps_map in workspace_deps_map.items():
            if pkg_name not in dependencies:
                non_frozen_map = dict()
                for key, values in conditional_deps_map.items():
                    non_frozen_map.update({key: dict(values.items())})
                dependencies.setdefault(pkg_name, non_frozen_map)
                continue

            for condition, deps_map in conditional_deps_map.items():
                # If the condition has not been recorded, do so and continue
                if condition not in dependencies[pkg_name]:
                    dependencies[pkg_name].setdefault(condition, dict(deps_map.items()))
                    continue

                # Alert on any miss-matched dependencies
                inconsistent_entries = []
                for crate_name, crate_label in deps_map.items():
                    existing = dependencies[pkg_name][condition].get(crate_name)
                    if existing and existing != crate_label:
                        inconsistent_entries.append((crate_name, existing, crate_label))
                    dependencies[pkg_name][condition].update({crate_name: crate_label})

    return dependencies

def crate_deps(deps, package_name = None):
    """Finds the fully qualified label of the requested crates for the package where this macro is called.

    Args:
        deps (list): The desired list of crate targets.
        package_name (str, optional): The package name of the set of dependencies to look up.
            Defaults to `native.package_name()`.

    Returns:
        list: A list of labels to generated rust targets (str)
    """

    if not deps:
        return []

    if package_name == None:
        package_name = native.package_name()

    # Join both sets of dependencies
    dependencies = _flatten_dependency_maps([
        _NORMAL_DEPENDENCIES,
        _NORMAL_DEV_DEPENDENCIES,
        _PROC_MACRO_DEPENDENCIES,
        _PROC_MACRO_DEV_DEPENDENCIES,
        _BUILD_DEPENDENCIES,
        _BUILD_PROC_MACRO_DEPENDENCIES,
    ]).pop(package_name, {})

    # Combine all conditional packages so we can easily index over a flat list
    # TODO: Perhaps this should actually return select statements and maintain
    # the conditionals of the dependencies
    flat_deps = {}
    for deps_set in dependencies.values():
        for crate_name, crate_label in deps_set.items():
            flat_deps.update({crate_name: crate_label})

    missing_crates = []
    crate_targets = []
    for crate_target in deps:
        if crate_target not in flat_deps:
            missing_crates.append(crate_target)
        else:
            crate_targets.append(flat_deps[crate_target])

    if missing_crates:
        fail("Could not find crates `{}` among dependencies of `{}`. Available dependencies were `{}`".format(
            missing_crates,
            package_name,
            dependencies,
        ))

    return crate_targets

def all_crate_deps(
        normal = False,
        normal_dev = False,
        proc_macro = False,
        proc_macro_dev = False,
        build = False,
        build_proc_macro = False,
        package_name = None):
    """Finds the fully qualified label of all requested direct crate dependencies \
    for the package where this macro is called.

    If no parameters are set, all normal dependencies are returned. Setting any one flag will
    otherwise impact the contents of the returned list.

    Args:
        normal (bool, optional): If True, normal dependencies are included in the
            output list.
        normal_dev (bool, optional): If True, normal dev dependencies will be
            included in the output list..
        proc_macro (bool, optional): If True, proc_macro dependencies are included
            in the output list.
        proc_macro_dev (bool, optional): If True, dev proc_macro dependencies are
            included in the output list.
        build (bool, optional): If True, build dependencies are included
            in the output list.
        build_proc_macro (bool, optional): If True, build proc_macro dependencies are
            included in the output list.
        package_name (str, optional): The package name of the set of dependencies to look up.
            Defaults to `native.package_name()` when unset.

    Returns:
        list: A list of labels to generated rust targets (str)
    """

    if package_name == None:
        package_name = native.package_name()

    # Determine the relevant maps to use
    all_dependency_maps = []
    if normal:
        all_dependency_maps.append(_NORMAL_DEPENDENCIES)
    if normal_dev:
        all_dependency_maps.append(_NORMAL_DEV_DEPENDENCIES)
    if proc_macro:
        all_dependency_maps.append(_PROC_MACRO_DEPENDENCIES)
    if proc_macro_dev:
        all_dependency_maps.append(_PROC_MACRO_DEV_DEPENDENCIES)
    if build:
        all_dependency_maps.append(_BUILD_DEPENDENCIES)
    if build_proc_macro:
        all_dependency_maps.append(_BUILD_PROC_MACRO_DEPENDENCIES)

    # Default to always using normal dependencies
    if not all_dependency_maps:
        all_dependency_maps.append(_NORMAL_DEPENDENCIES)

    dependencies = _flatten_dependency_maps(all_dependency_maps).pop(package_name, None)

    if not dependencies:
        if dependencies == None:
            fail("Tried to get all_crate_deps for package " + package_name + " but that package had no Cargo.toml file")
        else:
            return []

    crate_deps = list(dependencies.pop(_COMMON_CONDITION, {}).values())
    for condition, deps in dependencies.items():
        crate_deps += selects.with_or({
            tuple(_CONDITIONS[condition]): deps.values(),
            "//conditions:default": [],
        })

    return crate_deps

def aliases(
        normal = False,
        normal_dev = False,
        proc_macro = False,
        proc_macro_dev = False,
        build = False,
        build_proc_macro = False,
        package_name = None):
    """Produces a map of Crate alias names to their original label

    If no dependency kinds are specified, `normal` and `proc_macro` are used by default.
    Setting any one flag will otherwise determine the contents of the returned dict.

    Args:
        normal (bool, optional): If True, normal dependencies are included in the
            output list.
        normal_dev (bool, optional): If True, normal dev dependencies will be
            included in the output list..
        proc_macro (bool, optional): If True, proc_macro dependencies are included
            in the output list.
        proc_macro_dev (bool, optional): If True, dev proc_macro dependencies are
            included in the output list.
        build (bool, optional): If True, build dependencies are included
            in the output list.
        build_proc_macro (bool, optional): If True, build proc_macro dependencies are
            included in the output list.
        package_name (str, optional): The package name of the set of dependencies to look up.
            Defaults to `native.package_name()` when unset.

    Returns:
        dict: The aliases of all associated packages
    """
    if package_name == None:
        package_name = native.package_name()

    # Determine the relevant maps to use
    all_aliases_maps = []
    if normal:
        all_aliases_maps.append(_NORMAL_ALIASES)
    if normal_dev:
        all_aliases_maps.append(_NORMAL_DEV_ALIASES)
    if proc_macro:
        all_aliases_maps.append(_PROC_MACRO_ALIASES)
    if proc_macro_dev:
        all_aliases_maps.append(_PROC_MACRO_DEV_ALIASES)
    if build:
        all_aliases_maps.append(_BUILD_ALIASES)
    if build_proc_macro:
        all_aliases_maps.append(_BUILD_PROC_MACRO_ALIASES)

    # Default to always using normal aliases
    if not all_aliases_maps:
        all_aliases_maps.append(_NORMAL_ALIASES)
        all_aliases_maps.append(_PROC_MACRO_ALIASES)

    aliases = _flatten_dependency_maps(all_aliases_maps).pop(package_name, None)

    if not aliases:
        return dict()

    common_items = aliases.pop(_COMMON_CONDITION, {}).items()

    # If there are only common items in the dictionary, immediately return them
    if not len(aliases.keys()) == 1:
        return dict(common_items)

    # Build a single select statement where each conditional has accounted for the
    # common set of aliases.
    crate_aliases = {"//conditions:default": dict(common_items)}
    for condition, deps in aliases.items():
        condition_triples = _CONDITIONS[condition]
        for triple in condition_triples:
            if triple in crate_aliases:
                crate_aliases[triple].update(deps)
            else:
                crate_aliases.update({triple: dict(deps.items() + common_items)})

    return select(crate_aliases)

###############################################################################
# WORKSPACE MEMBER DEPS AND ALIASES
###############################################################################

_NORMAL_DEPENDENCIES = {
    "": {
        _COMMON_CONDITION: {
            "clap": Label("@crates_vendor__clap-3.1.5//:clap"),
            "rand": Label("@crates_vendor__rand-0.8.5//:rand"),
        },
    },
}

_NORMAL_ALIASES = {
    "": {
        _COMMON_CONDITION: {
        },
    },
}

_NORMAL_DEV_DEPENDENCIES = {
    "": {
        _COMMON_CONDITION: {
            "version-sync": Label("@crates_vendor__version-sync-0.9.4//:version_sync"),
        },
    },
}

_NORMAL_DEV_ALIASES = {
    "": {
        _COMMON_CONDITION: {
        },
    },
}

_PROC_MACRO_DEPENDENCIES = {
    "": {
    },
}

_PROC_MACRO_ALIASES = {
    "": {
    },
}

_PROC_MACRO_DEV_DEPENDENCIES = {
    "": {
    },
}

_PROC_MACRO_DEV_ALIASES = {
    "": {
        _COMMON_CONDITION: {
        },
    },
}

_BUILD_DEPENDENCIES = {
    "": {
    },
}

_BUILD_ALIASES = {
    "": {
    },
}

_BUILD_PROC_MACRO_DEPENDENCIES = {
    "": {
    },
}

_BUILD_PROC_MACRO_ALIASES = {
    "": {
    },
}

_CONDITIONS = {
    "aarch64-apple-darwin": ["@rules_rust//rust/platform:aarch64-apple-darwin"],
    "aarch64-apple-ios": ["@rules_rust//rust/platform:aarch64-apple-ios"],
    "aarch64-apple-ios-sim": ["@rules_rust//rust/platform:aarch64-apple-ios-sim"],
    "aarch64-apple-visionos": ["@rules_rust//rust/platform:aarch64-apple-visionos"],
    "aarch64-apple-visionos-sim": ["@rules_rust//rust/platform:aarch64-apple-visionos-sim"],
    "aarch64-fuchsia": ["@rules_rust//rust/platform:aarch64-fuchsia"],
    "aarch64-linux-android": ["@rules_rust//rust/platform:aarch64-linux-android"],
    "aarch64-pc-windows-msvc": ["@rules_rust//rust/platform:aarch64-pc-windows-msvc"],
    "aarch64-unknown-linux-gnu": ["@rules_rust//rust/platform:aarch64-unknown-linux-gnu", "@rules_rust//rust/platform:aarch64-unknown-nixos-gnu"],
    "aarch64-unknown-nixos-gnu": ["@rules_rust//rust/platform:aarch64-unknown-nixos-gnu"],
    "aarch64-unknown-nto-qnx710": ["@rules_rust//rust/platform:aarch64-unknown-nto-qnx710"],
    "arm-unknown-linux-gnueabi": ["@rules_rust//rust/platform:arm-unknown-linux-gnueabi"],
    "armv7-linux-androideabi": ["@rules_rust//rust/platform:armv7-linux-androideabi"],
    "armv7-unknown-linux-gnueabi": ["@rules_rust//rust/platform:armv7-unknown-linux-gnueabi"],
    "cfg(target_os = \"hermit\")": [],
    "cfg(target_os = \"wasi\")": ["@rules_rust//rust/platform:wasm32-wasi"],
    "cfg(unix)": ["@rules_rust//rust/platform:aarch64-apple-darwin", "@rules_rust//rust/platform:aarch64-apple-ios", "@rules_rust//rust/platform:aarch64-apple-ios-sim", "@rules_rust//rust/platform:aarch64-apple-visionos", "@rules_rust//rust/platform:aarch64-apple-visionos-sim", "@rules_rust//rust/platform:aarch64-fuchsia", "@rules_rust//rust/platform:aarch64-linux-android", "@rules_rust//rust/platform:aarch64-unknown-linux-gnu", "@rules_rust//rust/platform:aarch64-unknown-nixos-gnu", "@rules_rust//rust/platform:aarch64-unknown-nto-qnx710", "@rules_rust//rust/platform:arm-unknown-linux-gnueabi", "@rules_rust//rust/platform:armv7-linux-androideabi", "@rules_rust//rust/platform:armv7-unknown-linux-gnueabi", "@rules_rust//rust/platform:i686-apple-darwin", "@rules_rust//rust/platform:i686-linux-android", "@rules_rust//rust/platform:i686-unknown-freebsd", "@rules_rust//rust/platform:i686-unknown-linux-gnu", "@rules_rust//rust/platform:powerpc-unknown-linux-gnu", "@rules_rust//rust/platform:s390x-unknown-linux-gnu", "@rules_rust//rust/platform:x86_64-apple-darwin", "@rules_rust//rust/platform:x86_64-apple-ios", "@rules_rust//rust/platform:x86_64-fuchsia", "@rules_rust//rust/platform:x86_64-linux-android", "@rules_rust//rust/platform:x86_64-unknown-freebsd", "@rules_rust//rust/platform:x86_64-unknown-linux-gnu", "@rules_rust//rust/platform:x86_64-unknown-nixos-gnu"],
    "cfg(windows)": ["@rules_rust//rust/platform:aarch64-pc-windows-msvc", "@rules_rust//rust/platform:i686-pc-windows-msvc", "@rules_rust//rust/platform:x86_64-pc-windows-msvc"],
    "i686-apple-darwin": ["@rules_rust//rust/platform:i686-apple-darwin"],
    "i686-linux-android": ["@rules_rust//rust/platform:i686-linux-android"],
    "i686-pc-windows-gnu": [],
    "i686-pc-windows-msvc": ["@rules_rust//rust/platform:i686-pc-windows-msvc"],
    "i686-unknown-freebsd": ["@rules_rust//rust/platform:i686-unknown-freebsd"],
    "i686-unknown-linux-gnu": ["@rules_rust//rust/platform:i686-unknown-linux-gnu"],
    "powerpc-unknown-linux-gnu": ["@rules_rust//rust/platform:powerpc-unknown-linux-gnu"],
    "riscv32imc-unknown-none-elf": ["@rules_rust//rust/platform:riscv32imc-unknown-none-elf"],
    "riscv64gc-unknown-none-elf": ["@rules_rust//rust/platform:riscv64gc-unknown-none-elf"],
    "s390x-unknown-linux-gnu": ["@rules_rust//rust/platform:s390x-unknown-linux-gnu"],
    "thumbv7em-none-eabi": ["@rules_rust//rust/platform:thumbv7em-none-eabi"],
    "thumbv8m.main-none-eabi": ["@rules_rust//rust/platform:thumbv8m.main-none-eabi"],
    "wasm32-unknown-unknown": ["@rules_rust//rust/platform:wasm32-unknown-unknown"],
    "wasm32-wasi": ["@rules_rust//rust/platform:wasm32-wasi"],
    "x86_64-apple-darwin": ["@rules_rust//rust/platform:x86_64-apple-darwin"],
    "x86_64-apple-ios": ["@rules_rust//rust/platform:x86_64-apple-ios"],
    "x86_64-fuchsia": ["@rules_rust//rust/platform:x86_64-fuchsia"],
    "x86_64-linux-android": ["@rules_rust//rust/platform:x86_64-linux-android"],
    "x86_64-pc-windows-gnu": [],
    "x86_64-pc-windows-msvc": ["@rules_rust//rust/platform:x86_64-pc-windows-msvc"],
    "x86_64-unknown-freebsd": ["@rules_rust//rust/platform:x86_64-unknown-freebsd"],
    "x86_64-unknown-linux-gnu": ["@rules_rust//rust/platform:x86_64-unknown-linux-gnu", "@rules_rust//rust/platform:x86_64-unknown-nixos-gnu"],
    "x86_64-unknown-nixos-gnu": ["@rules_rust//rust/platform:x86_64-unknown-nixos-gnu"],
    "x86_64-unknown-none": ["@rules_rust//rust/platform:x86_64-unknown-none"],
}

###############################################################################

def crate_repositories():
    """A macro for defining repositories for all generated crates.

    Returns:
      A list of repos visible to the module through the module extension.
    """
    maybe(
        http_archive,
        name = "crates_vendor__atty-0.2.14",
        sha256 = "d9b39be18770d11421cdb1b9947a45dd3f37e93092cbf377614828a319d5fee8",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/atty/0.2.14/download"],
        strip_prefix = "atty-0.2.14",
        build_file = Label("@examples//vendor_external/crates:BUILD.atty-0.2.14.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__autocfg-1.1.0",
        sha256 = "d468802bab17cbc0cc575e9b053f41e72aa36bfa6b7f55e3529ffa43161b97fa",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/autocfg/1.1.0/download"],
        strip_prefix = "autocfg-1.1.0",
        build_file = Label("@examples//vendor_external/crates:BUILD.autocfg-1.1.0.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__bitflags-1.3.2",
        sha256 = "bef38d45163c2f1dde094a7dfd33ccf595c92905c8f8f4fdc18d06fb1037718a",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/bitflags/1.3.2/download"],
        strip_prefix = "bitflags-1.3.2",
        build_file = Label("@examples//vendor_external/crates:BUILD.bitflags-1.3.2.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__cfg-if-1.0.0",
        sha256 = "baf1de4339761588bc0619e3cbc0120ee582ebb74b53b4efbf79117bd2da40fd",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/cfg-if/1.0.0/download"],
        strip_prefix = "cfg-if-1.0.0",
        build_file = Label("@examples//vendor_external/crates:BUILD.cfg-if-1.0.0.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__clap-3.1.5",
        sha256 = "ced1892c55c910c1219e98d6fc8d71f6bddba7905866ce740066d8bfea859312",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/clap/3.1.5/download"],
        strip_prefix = "clap-3.1.5",
        build_file = Label("@examples//vendor_external/crates:BUILD.clap-3.1.5.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__clap_derive-3.1.4",
        sha256 = "da95d038ede1a964ce99f49cbe27a7fb538d1da595e4b4f70b8c8f338d17bf16",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/clap_derive/3.1.4/download"],
        strip_prefix = "clap_derive-3.1.4",
        build_file = Label("@examples//vendor_external/crates:BUILD.clap_derive-3.1.4.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__form_urlencoded-1.0.1",
        sha256 = "5fc25a87fa4fd2094bffb06925852034d90a17f0d1e05197d4956d3555752191",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/form_urlencoded/1.0.1/download"],
        strip_prefix = "form_urlencoded-1.0.1",
        build_file = Label("@examples//vendor_external/crates:BUILD.form_urlencoded-1.0.1.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__getrandom-0.2.5",
        sha256 = "d39cd93900197114fa1fcb7ae84ca742095eed9442088988ae74fa744e930e77",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/getrandom/0.2.5/download"],
        strip_prefix = "getrandom-0.2.5",
        build_file = Label("@examples//vendor_external/crates:BUILD.getrandom-0.2.5.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__hashbrown-0.11.2",
        sha256 = "ab5ef0d4909ef3724cc8cce6ccc8572c5c817592e9285f5464f8e86f8bd3726e",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/hashbrown/0.11.2/download"],
        strip_prefix = "hashbrown-0.11.2",
        build_file = Label("@examples//vendor_external/crates:BUILD.hashbrown-0.11.2.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__heck-0.4.0",
        sha256 = "2540771e65fc8cb83cd6e8a237f70c319bd5c29f78ed1084ba5d50eeac86f7f9",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/heck/0.4.0/download"],
        strip_prefix = "heck-0.4.0",
        build_file = Label("@examples//vendor_external/crates:BUILD.heck-0.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__hermit-abi-0.1.19",
        sha256 = "62b467343b94ba476dcb2500d242dadbb39557df889310ac77c5d99100aaac33",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/hermit-abi/0.1.19/download"],
        strip_prefix = "hermit-abi-0.1.19",
        build_file = Label("@examples//vendor_external/crates:BUILD.hermit-abi-0.1.19.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__idna-0.2.3",
        sha256 = "418a0a6fab821475f634efe3ccc45c013f742efe03d853e8d3355d5cb850ecf8",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/idna/0.2.3/download"],
        strip_prefix = "idna-0.2.3",
        build_file = Label("@examples//vendor_external/crates:BUILD.idna-0.2.3.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__indexmap-1.8.0",
        sha256 = "282a6247722caba404c065016bbfa522806e51714c34f5dfc3e4a3a46fcb4223",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/indexmap/1.8.0/download"],
        strip_prefix = "indexmap-1.8.0",
        build_file = Label("@examples//vendor_external/crates:BUILD.indexmap-1.8.0.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__lazy_static-1.4.0",
        sha256 = "e2abad23fbc42b3700f2f279844dc832adb2b2eb069b2df918f455c4e18cc646",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/lazy_static/1.4.0/download"],
        strip_prefix = "lazy_static-1.4.0",
        build_file = Label("@examples//vendor_external/crates:BUILD.lazy_static-1.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__libc-0.2.119",
        sha256 = "1bf2e165bb3457c8e098ea76f3e3bc9db55f87aa90d52d0e6be741470916aaa4",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/libc/0.2.119/download"],
        strip_prefix = "libc-0.2.119",
        build_file = Label("@examples//vendor_external/crates:BUILD.libc-0.2.119.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__matches-0.1.9",
        sha256 = "a3e378b66a060d48947b590737b30a1be76706c8dd7b8ba0f2fe3989c68a853f",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/matches/0.1.9/download"],
        strip_prefix = "matches-0.1.9",
        build_file = Label("@examples//vendor_external/crates:BUILD.matches-0.1.9.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__memchr-2.4.1",
        sha256 = "308cc39be01b73d0d18f82a0e7b2a3df85245f84af96fdddc5d202d27e47b86a",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/memchr/2.4.1/download"],
        strip_prefix = "memchr-2.4.1",
        build_file = Label("@examples//vendor_external/crates:BUILD.memchr-2.4.1.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__os_str_bytes-6.0.0",
        sha256 = "8e22443d1643a904602595ba1cd8f7d896afe56d26712531c5ff73a15b2fbf64",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/os_str_bytes/6.0.0/download"],
        strip_prefix = "os_str_bytes-6.0.0",
        build_file = Label("@examples//vendor_external/crates:BUILD.os_str_bytes-6.0.0.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__percent-encoding-2.1.0",
        sha256 = "d4fd5641d01c8f18a23da7b6fe29298ff4b55afcccdf78973b24cf3175fee32e",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/percent-encoding/2.1.0/download"],
        strip_prefix = "percent-encoding-2.1.0",
        build_file = Label("@examples//vendor_external/crates:BUILD.percent-encoding-2.1.0.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__ppv-lite86-0.2.16",
        sha256 = "eb9f9e6e233e5c4a35559a617bf40a4ec447db2e84c20b55a6f83167b7e57872",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/ppv-lite86/0.2.16/download"],
        strip_prefix = "ppv-lite86-0.2.16",
        build_file = Label("@examples//vendor_external/crates:BUILD.ppv-lite86-0.2.16.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__proc-macro-error-1.0.4",
        sha256 = "da25490ff9892aab3fcf7c36f08cfb902dd3e71ca0f9f9517bea02a73a5ce38c",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/proc-macro-error/1.0.4/download"],
        strip_prefix = "proc-macro-error-1.0.4",
        build_file = Label("@examples//vendor_external/crates:BUILD.proc-macro-error-1.0.4.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__proc-macro-error-attr-1.0.4",
        sha256 = "a1be40180e52ecc98ad80b184934baf3d0d29f979574e439af5a55274b35f869",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/proc-macro-error-attr/1.0.4/download"],
        strip_prefix = "proc-macro-error-attr-1.0.4",
        build_file = Label("@examples//vendor_external/crates:BUILD.proc-macro-error-attr-1.0.4.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__proc-macro2-1.0.36",
        sha256 = "c7342d5883fbccae1cc37a2353b09c87c9b0f3afd73f5fb9bba687a1f733b029",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/proc-macro2/1.0.36/download"],
        strip_prefix = "proc-macro2-1.0.36",
        build_file = Label("@examples//vendor_external/crates:BUILD.proc-macro2-1.0.36.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__pulldown-cmark-0.8.0",
        sha256 = "ffade02495f22453cd593159ea2f59827aae7f53fa8323f756799b670881dcf8",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/pulldown-cmark/0.8.0/download"],
        strip_prefix = "pulldown-cmark-0.8.0",
        build_file = Label("@examples//vendor_external/crates:BUILD.pulldown-cmark-0.8.0.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__quote-1.0.15",
        sha256 = "864d3e96a899863136fc6e99f3d7cae289dafe43bf2c5ac19b70df7210c0a145",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/quote/1.0.15/download"],
        strip_prefix = "quote-1.0.15",
        build_file = Label("@examples//vendor_external/crates:BUILD.quote-1.0.15.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__rand-0.8.5",
        sha256 = "34af8d1a0e25924bc5b7c43c079c942339d8f0a8b57c39049bef581b46327404",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/rand/0.8.5/download"],
        strip_prefix = "rand-0.8.5",
        build_file = Label("@examples//vendor_external/crates:BUILD.rand-0.8.5.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__rand_chacha-0.3.1",
        sha256 = "e6c10a63a0fa32252be49d21e7709d4d4baf8d231c2dbce1eaa8141b9b127d88",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/rand_chacha/0.3.1/download"],
        strip_prefix = "rand_chacha-0.3.1",
        build_file = Label("@examples//vendor_external/crates:BUILD.rand_chacha-0.3.1.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__rand_core-0.6.3",
        sha256 = "d34f1408f55294453790c48b2f1ebbb1c5b4b7563eb1f418bcfcfdbb06ebb4e7",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/rand_core/0.6.3/download"],
        strip_prefix = "rand_core-0.6.3",
        build_file = Label("@examples//vendor_external/crates:BUILD.rand_core-0.6.3.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__regex-1.5.4",
        sha256 = "d07a8629359eb56f1e2fb1652bb04212c072a87ba68546a04065d525673ac461",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/regex/1.5.4/download"],
        strip_prefix = "regex-1.5.4",
        build_file = Label("@examples//vendor_external/crates:BUILD.regex-1.5.4.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__regex-syntax-0.6.25",
        sha256 = "f497285884f3fcff424ffc933e56d7cbca511def0c9831a7f9b5f6153e3cc89b",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/regex-syntax/0.6.25/download"],
        strip_prefix = "regex-syntax-0.6.25",
        build_file = Label("@examples//vendor_external/crates:BUILD.regex-syntax-0.6.25.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__semver-1.0.6",
        sha256 = "a4a3381e03edd24287172047536f20cabde766e2cd3e65e6b00fb3af51c4f38d",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/semver/1.0.6/download"],
        strip_prefix = "semver-1.0.6",
        build_file = Label("@examples//vendor_external/crates:BUILD.semver-1.0.6.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__serde-1.0.136",
        sha256 = "ce31e24b01e1e524df96f1c2fdd054405f8d7376249a5110886fb4b658484789",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/serde/1.0.136/download"],
        strip_prefix = "serde-1.0.136",
        build_file = Label("@examples//vendor_external/crates:BUILD.serde-1.0.136.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__strsim-0.10.0",
        sha256 = "73473c0e59e6d5812c5dfe2a064a6444949f089e20eec9a2e5506596494e4623",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/strsim/0.10.0/download"],
        strip_prefix = "strsim-0.10.0",
        build_file = Label("@examples//vendor_external/crates:BUILD.strsim-0.10.0.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__syn-1.0.86",
        sha256 = "8a65b3f4ffa0092e9887669db0eae07941f023991ab58ea44da8fe8e2d511c6b",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/syn/1.0.86/download"],
        strip_prefix = "syn-1.0.86",
        build_file = Label("@examples//vendor_external/crates:BUILD.syn-1.0.86.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__termcolor-1.1.3",
        sha256 = "bab24d30b911b2376f3a13cc2cd443142f0c81dda04c118693e35b3835757755",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/termcolor/1.1.3/download"],
        strip_prefix = "termcolor-1.1.3",
        build_file = Label("@examples//vendor_external/crates:BUILD.termcolor-1.1.3.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__textwrap-0.15.0",
        sha256 = "b1141d4d61095b28419e22cb0bbf02755f5e54e0526f97f1e3d1d160e60885fb",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/textwrap/0.15.0/download"],
        strip_prefix = "textwrap-0.15.0",
        build_file = Label("@examples//vendor_external/crates:BUILD.textwrap-0.15.0.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__tinyvec-1.5.1",
        sha256 = "2c1c1d5a42b6245520c249549ec267180beaffcc0615401ac8e31853d4b6d8d2",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/tinyvec/1.5.1/download"],
        strip_prefix = "tinyvec-1.5.1",
        build_file = Label("@examples//vendor_external/crates:BUILD.tinyvec-1.5.1.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__tinyvec_macros-0.1.0",
        sha256 = "cda74da7e1a664f795bb1f8a87ec406fb89a02522cf6e50620d016add6dbbf5c",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/tinyvec_macros/0.1.0/download"],
        strip_prefix = "tinyvec_macros-0.1.0",
        build_file = Label("@examples//vendor_external/crates:BUILD.tinyvec_macros-0.1.0.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__toml-0.5.8",
        sha256 = "a31142970826733df8241ef35dc040ef98c679ab14d7c3e54d827099b3acecaa",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/toml/0.5.8/download"],
        strip_prefix = "toml-0.5.8",
        build_file = Label("@examples//vendor_external/crates:BUILD.toml-0.5.8.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__unicase-2.6.0",
        sha256 = "50f37be617794602aabbeee0be4f259dc1778fabe05e2d67ee8f79326d5cb4f6",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/unicase/2.6.0/download"],
        strip_prefix = "unicase-2.6.0",
        build_file = Label("@examples//vendor_external/crates:BUILD.unicase-2.6.0.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__unicode-bidi-0.3.7",
        sha256 = "1a01404663e3db436ed2746d9fefef640d868edae3cceb81c3b8d5732fda678f",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/unicode-bidi/0.3.7/download"],
        strip_prefix = "unicode-bidi-0.3.7",
        build_file = Label("@examples//vendor_external/crates:BUILD.unicode-bidi-0.3.7.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__unicode-normalization-0.1.19",
        sha256 = "d54590932941a9e9266f0832deed84ebe1bf2e4c9e4a3554d393d18f5e854bf9",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/unicode-normalization/0.1.19/download"],
        strip_prefix = "unicode-normalization-0.1.19",
        build_file = Label("@examples//vendor_external/crates:BUILD.unicode-normalization-0.1.19.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__unicode-xid-0.2.2",
        sha256 = "8ccb82d61f80a663efe1f787a51b16b5a51e3314d6ac365b08639f52387b33f3",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/unicode-xid/0.2.2/download"],
        strip_prefix = "unicode-xid-0.2.2",
        build_file = Label("@examples//vendor_external/crates:BUILD.unicode-xid-0.2.2.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__url-2.2.2",
        sha256 = "a507c383b2d33b5fc35d1861e77e6b383d158b2da5e14fe51b83dfedf6fd578c",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/url/2.2.2/download"],
        strip_prefix = "url-2.2.2",
        build_file = Label("@examples//vendor_external/crates:BUILD.url-2.2.2.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__version-sync-0.9.4",
        sha256 = "99d0801cec07737d88cb900e6419f6f68733867f90b3faaa837e84692e101bf0",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/version-sync/0.9.4/download"],
        strip_prefix = "version-sync-0.9.4",
        build_file = Label("@examples//vendor_external/crates:BUILD.version-sync-0.9.4.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__version_check-0.9.4",
        sha256 = "49874b5167b65d7193b8aba1567f5c7d93d001cafc34600cee003eda787e483f",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/version_check/0.9.4/download"],
        strip_prefix = "version_check-0.9.4",
        build_file = Label("@examples//vendor_external/crates:BUILD.version_check-0.9.4.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__wasi-0.10.2-wasi-snapshot-preview1",
        sha256 = "fd6fbd9a79829dd1ad0cc20627bf1ed606756a7f77edff7b66b7064f9cb327c6",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/wasi/0.10.2+wasi-snapshot-preview1/download"],
        strip_prefix = "wasi-0.10.2+wasi-snapshot-preview1",
        build_file = Label("@examples//vendor_external/crates:BUILD.wasi-0.10.2+wasi-snapshot-preview1.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__winapi-0.3.9",
        sha256 = "5c839a674fcd7a98952e593242ea400abe93992746761e38641405d28b00f419",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/winapi/0.3.9/download"],
        strip_prefix = "winapi-0.3.9",
        build_file = Label("@examples//vendor_external/crates:BUILD.winapi-0.3.9.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__winapi-i686-pc-windows-gnu-0.4.0",
        sha256 = "ac3b87c63620426dd9b991e5ce0329eff545bccbbb34f3be09ff6fb6ab51b7b6",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/winapi-i686-pc-windows-gnu/0.4.0/download"],
        strip_prefix = "winapi-i686-pc-windows-gnu-0.4.0",
        build_file = Label("@examples//vendor_external/crates:BUILD.winapi-i686-pc-windows-gnu-0.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__winapi-util-0.1.5",
        sha256 = "70ec6ce85bb158151cae5e5c87f95a8e97d2c0c4b001223f33a334e3ce5de178",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/winapi-util/0.1.5/download"],
        strip_prefix = "winapi-util-0.1.5",
        build_file = Label("@examples//vendor_external/crates:BUILD.winapi-util-0.1.5.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__winapi-x86_64-pc-windows-gnu-0.4.0",
        sha256 = "712e227841d057c1ee1cd2fb22fa7e5a5461ae8e48fa2ca79ec42cfc1931183f",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/winapi-x86_64-pc-windows-gnu/0.4.0/download"],
        strip_prefix = "winapi-x86_64-pc-windows-gnu-0.4.0",
        build_file = Label("@examples//vendor_external/crates:BUILD.winapi-x86_64-pc-windows-gnu-0.4.0.bazel"),
    )

    return [
        struct(repo = "crates_vendor__clap-3.1.5", is_dev_dep = False),
        struct(repo = "crates_vendor__rand-0.8.5", is_dev_dep = False),
        struct(repo = "crates_vendor__version-sync-0.9.4", is_dev_dep = True),
    ]
