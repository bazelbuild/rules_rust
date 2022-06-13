###############################################################################
# @generated
# This file is auto-generated by the cargo-bazel tool.
#
# DO NOT MODIFY: Local changes may be replaced in future executions.
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

            # Not all dependnecies are supported for all platforms.
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
        normal_dev (bool, optional): If True, normla dev dependencies will be
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
        crate_deps += selects.with_or({_CONDITIONS[condition]: deps.values()})

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
        normal_dev (bool, optional): If True, normla dev dependencies will be
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
    crate_aliases = {"//conditions:default": common_items}
    for condition, deps in aliases.items():
        condition_triples = _CONDITIONS[condition]
        if condition_triples in crate_aliases:
            crate_aliases[condition_triples].update(deps)
        else:
            crate_aliases.update({_CONDITIONS[condition]: dict(deps.items() + common_items)})

    return selects.with_or(crate_aliases)

###############################################################################
# WORKSPACE MEMBER DEPS AND ALIASES
###############################################################################

_NORMAL_DEPENDENCIES = {
    "": {
        _COMMON_CONDITION: {
            "clap": "@crates_vendor__clap-3.1.18//:clap",
            "rand": "@crates_vendor__rand-0.8.5//:rand",
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
            "version-sync": "@crates_vendor__version-sync-0.9.4//:version_sync",
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
    "cfg(target_os = \"hermit\")": [],
    "cfg(target_os = \"wasi\")": ["wasm32-wasi"],
    "cfg(unix)": ["aarch64-apple-darwin", "aarch64-apple-ios", "aarch64-apple-ios-sim", "aarch64-linux-android", "aarch64-unknown-linux-gnu", "arm-unknown-linux-gnueabi", "armv7-linux-androideabi", "armv7-unknown-linux-gnueabi", "i686-apple-darwin", "i686-linux-android", "i686-unknown-freebsd", "i686-unknown-linux-gnu", "powerpc-unknown-linux-gnu", "s390x-unknown-linux-gnu", "x86_64-apple-darwin", "x86_64-apple-ios", "x86_64-linux-android", "x86_64-unknown-freebsd", "x86_64-unknown-linux-gnu"],
    "cfg(windows)": ["i686-pc-windows-msvc", "x86_64-pc-windows-msvc"],
    "i686-pc-windows-gnu": [],
    "x86_64-pc-windows-gnu": [],
}

###############################################################################

def crate_repositories():
    """A macro for defining repositories for all generated crates"""
    maybe(
        http_archive,
        name = "crates_vendor__atty-0.2.14",
        sha256 = "d9b39be18770d11421cdb1b9947a45dd3f37e93092cbf377614828a319d5fee8",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/atty/0.2.14/download"],
        strip_prefix = "atty-0.2.14",
        build_file = Label("@examples//vendor_external/crates:BUILD.atty-0.2.14.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__autocfg-1.1.0",
        sha256 = "d468802bab17cbc0cc575e9b053f41e72aa36bfa6b7f55e3529ffa43161b97fa",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/autocfg/1.1.0/download"],
        strip_prefix = "autocfg-1.1.0",
        build_file = Label("@examples//vendor_external/crates:BUILD.autocfg-1.1.0.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__bitflags-1.3.2",
        sha256 = "bef38d45163c2f1dde094a7dfd33ccf595c92905c8f8f4fdc18d06fb1037718a",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/bitflags/1.3.2/download"],
        strip_prefix = "bitflags-1.3.2",
        build_file = Label("@examples//vendor_external/crates:BUILD.bitflags-1.3.2.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__cfg-if-1.0.0",
        sha256 = "baf1de4339761588bc0619e3cbc0120ee582ebb74b53b4efbf79117bd2da40fd",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/cfg-if/1.0.0/download"],
        strip_prefix = "cfg-if-1.0.0",
        build_file = Label("@examples//vendor_external/crates:BUILD.cfg-if-1.0.0.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__clap-3.1.18",
        sha256 = "d2dbdf4bdacb33466e854ce889eee8dfd5729abf7ccd7664d0a2d60cd384440b",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/clap/3.1.18/download"],
        strip_prefix = "clap-3.1.18",
        build_file = Label("@examples//vendor_external/crates:BUILD.clap-3.1.18.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__clap_derive-3.1.18",
        sha256 = "25320346e922cffe59c0bbc5410c8d8784509efb321488971081313cb1e1a33c",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/clap_derive/3.1.18/download"],
        strip_prefix = "clap_derive-3.1.18",
        build_file = Label("@examples//vendor_external/crates:BUILD.clap_derive-3.1.18.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__clap_lex-0.2.0",
        sha256 = "a37c35f1112dad5e6e0b1adaff798507497a18fceeb30cceb3bae7d1427b9213",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/clap_lex/0.2.0/download"],
        strip_prefix = "clap_lex-0.2.0",
        build_file = Label("@examples//vendor_external/crates:BUILD.clap_lex-0.2.0.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__form_urlencoded-1.0.1",
        sha256 = "5fc25a87fa4fd2094bffb06925852034d90a17f0d1e05197d4956d3555752191",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/form_urlencoded/1.0.1/download"],
        strip_prefix = "form_urlencoded-1.0.1",
        build_file = Label("@examples//vendor_external/crates:BUILD.form_urlencoded-1.0.1.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__getrandom-0.2.6",
        sha256 = "9be70c98951c83b8d2f8f60d7065fa6d5146873094452a1008da8c2f1e4205ad",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/getrandom/0.2.6/download"],
        strip_prefix = "getrandom-0.2.6",
        build_file = Label("@examples//vendor_external/crates:BUILD.getrandom-0.2.6.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__hashbrown-0.11.2",
        sha256 = "ab5ef0d4909ef3724cc8cce6ccc8572c5c817592e9285f5464f8e86f8bd3726e",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/hashbrown/0.11.2/download"],
        strip_prefix = "hashbrown-0.11.2",
        build_file = Label("@examples//vendor_external/crates:BUILD.hashbrown-0.11.2.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__heck-0.4.0",
        sha256 = "2540771e65fc8cb83cd6e8a237f70c319bd5c29f78ed1084ba5d50eeac86f7f9",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/heck/0.4.0/download"],
        strip_prefix = "heck-0.4.0",
        build_file = Label("@examples//vendor_external/crates:BUILD.heck-0.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__hermit-abi-0.1.19",
        sha256 = "62b467343b94ba476dcb2500d242dadbb39557df889310ac77c5d99100aaac33",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/hermit-abi/0.1.19/download"],
        strip_prefix = "hermit-abi-0.1.19",
        build_file = Label("@examples//vendor_external/crates:BUILD.hermit-abi-0.1.19.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__idna-0.2.3",
        sha256 = "418a0a6fab821475f634efe3ccc45c013f742efe03d853e8d3355d5cb850ecf8",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/idna/0.2.3/download"],
        strip_prefix = "idna-0.2.3",
        build_file = Label("@examples//vendor_external/crates:BUILD.idna-0.2.3.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__indexmap-1.8.2",
        sha256 = "e6012d540c5baa3589337a98ce73408de9b5a25ec9fc2c6fd6be8f0d39e0ca5a",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/indexmap/1.8.2/download"],
        strip_prefix = "indexmap-1.8.2",
        build_file = Label("@examples//vendor_external/crates:BUILD.indexmap-1.8.2.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__lazy_static-1.4.0",
        sha256 = "e2abad23fbc42b3700f2f279844dc832adb2b2eb069b2df918f455c4e18cc646",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/lazy_static/1.4.0/download"],
        strip_prefix = "lazy_static-1.4.0",
        build_file = Label("@examples//vendor_external/crates:BUILD.lazy_static-1.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__libc-0.2.126",
        sha256 = "349d5a591cd28b49e1d1037471617a32ddcda5731b99419008085f72d5a53836",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/libc/0.2.126/download"],
        strip_prefix = "libc-0.2.126",
        build_file = Label("@examples//vendor_external/crates:BUILD.libc-0.2.126.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__matches-0.1.9",
        sha256 = "a3e378b66a060d48947b590737b30a1be76706c8dd7b8ba0f2fe3989c68a853f",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/matches/0.1.9/download"],
        strip_prefix = "matches-0.1.9",
        build_file = Label("@examples//vendor_external/crates:BUILD.matches-0.1.9.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__memchr-2.5.0",
        sha256 = "2dffe52ecf27772e601905b7522cb4ef790d2cc203488bbd0e2fe85fcb74566d",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/memchr/2.5.0/download"],
        strip_prefix = "memchr-2.5.0",
        build_file = Label("@examples//vendor_external/crates:BUILD.memchr-2.5.0.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__os_str_bytes-6.1.0",
        sha256 = "21326818e99cfe6ce1e524c2a805c189a99b5ae555a35d19f9a284b427d86afa",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/os_str_bytes/6.1.0/download"],
        strip_prefix = "os_str_bytes-6.1.0",
        build_file = Label("@examples//vendor_external/crates:BUILD.os_str_bytes-6.1.0.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__percent-encoding-2.1.0",
        sha256 = "d4fd5641d01c8f18a23da7b6fe29298ff4b55afcccdf78973b24cf3175fee32e",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/percent-encoding/2.1.0/download"],
        strip_prefix = "percent-encoding-2.1.0",
        build_file = Label("@examples//vendor_external/crates:BUILD.percent-encoding-2.1.0.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__ppv-lite86-0.2.16",
        sha256 = "eb9f9e6e233e5c4a35559a617bf40a4ec447db2e84c20b55a6f83167b7e57872",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/ppv-lite86/0.2.16/download"],
        strip_prefix = "ppv-lite86-0.2.16",
        build_file = Label("@examples//vendor_external/crates:BUILD.ppv-lite86-0.2.16.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__proc-macro-error-1.0.4",
        sha256 = "da25490ff9892aab3fcf7c36f08cfb902dd3e71ca0f9f9517bea02a73a5ce38c",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/proc-macro-error/1.0.4/download"],
        strip_prefix = "proc-macro-error-1.0.4",
        build_file = Label("@examples//vendor_external/crates:BUILD.proc-macro-error-1.0.4.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__proc-macro-error-attr-1.0.4",
        sha256 = "a1be40180e52ecc98ad80b184934baf3d0d29f979574e439af5a55274b35f869",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/proc-macro-error-attr/1.0.4/download"],
        strip_prefix = "proc-macro-error-attr-1.0.4",
        build_file = Label("@examples//vendor_external/crates:BUILD.proc-macro-error-attr-1.0.4.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__proc-macro2-1.0.39",
        sha256 = "c54b25569025b7fc9651de43004ae593a75ad88543b17178aa5e1b9c4f15f56f",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/proc-macro2/1.0.39/download"],
        strip_prefix = "proc-macro2-1.0.39",
        build_file = Label("@examples//vendor_external/crates:BUILD.proc-macro2-1.0.39.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__pulldown-cmark-0.8.0",
        sha256 = "ffade02495f22453cd593159ea2f59827aae7f53fa8323f756799b670881dcf8",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/pulldown-cmark/0.8.0/download"],
        strip_prefix = "pulldown-cmark-0.8.0",
        build_file = Label("@examples//vendor_external/crates:BUILD.pulldown-cmark-0.8.0.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__quote-1.0.18",
        sha256 = "a1feb54ed693b93a84e14094943b84b7c4eae204c512b7ccb95ab0c66d278ad1",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/quote/1.0.18/download"],
        strip_prefix = "quote-1.0.18",
        build_file = Label("@examples//vendor_external/crates:BUILD.quote-1.0.18.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__rand-0.8.5",
        sha256 = "34af8d1a0e25924bc5b7c43c079c942339d8f0a8b57c39049bef581b46327404",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/rand/0.8.5/download"],
        strip_prefix = "rand-0.8.5",
        build_file = Label("@examples//vendor_external/crates:BUILD.rand-0.8.5.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__rand_chacha-0.3.1",
        sha256 = "e6c10a63a0fa32252be49d21e7709d4d4baf8d231c2dbce1eaa8141b9b127d88",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/rand_chacha/0.3.1/download"],
        strip_prefix = "rand_chacha-0.3.1",
        build_file = Label("@examples//vendor_external/crates:BUILD.rand_chacha-0.3.1.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__rand_core-0.6.3",
        sha256 = "d34f1408f55294453790c48b2f1ebbb1c5b4b7563eb1f418bcfcfdbb06ebb4e7",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/rand_core/0.6.3/download"],
        strip_prefix = "rand_core-0.6.3",
        build_file = Label("@examples//vendor_external/crates:BUILD.rand_core-0.6.3.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__regex-1.5.6",
        sha256 = "d83f127d94bdbcda4c8cc2e50f6f84f4b611f69c902699ca385a39c3a75f9ff1",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/regex/1.5.6/download"],
        strip_prefix = "regex-1.5.6",
        build_file = Label("@examples//vendor_external/crates:BUILD.regex-1.5.6.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__regex-syntax-0.6.26",
        sha256 = "49b3de9ec5dc0a3417da371aab17d729997c15010e7fd24ff707773a33bddb64",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/regex-syntax/0.6.26/download"],
        strip_prefix = "regex-syntax-0.6.26",
        build_file = Label("@examples//vendor_external/crates:BUILD.regex-syntax-0.6.26.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__semver-1.0.10",
        sha256 = "a41d061efea015927ac527063765e73601444cdc344ba855bc7bd44578b25e1c",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/semver/1.0.10/download"],
        strip_prefix = "semver-1.0.10",
        build_file = Label("@examples//vendor_external/crates:BUILD.semver-1.0.10.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__serde-1.0.137",
        sha256 = "61ea8d54c77f8315140a05f4c7237403bf38b72704d031543aa1d16abbf517d1",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/serde/1.0.137/download"],
        strip_prefix = "serde-1.0.137",
        build_file = Label("@examples//vendor_external/crates:BUILD.serde-1.0.137.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__strsim-0.10.0",
        sha256 = "73473c0e59e6d5812c5dfe2a064a6444949f089e20eec9a2e5506596494e4623",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/strsim/0.10.0/download"],
        strip_prefix = "strsim-0.10.0",
        build_file = Label("@examples//vendor_external/crates:BUILD.strsim-0.10.0.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__syn-1.0.96",
        sha256 = "0748dd251e24453cb8717f0354206b91557e4ec8703673a4b30208f2abaf1ebf",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/syn/1.0.96/download"],
        strip_prefix = "syn-1.0.96",
        build_file = Label("@examples//vendor_external/crates:BUILD.syn-1.0.96.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__termcolor-1.1.3",
        sha256 = "bab24d30b911b2376f3a13cc2cd443142f0c81dda04c118693e35b3835757755",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/termcolor/1.1.3/download"],
        strip_prefix = "termcolor-1.1.3",
        build_file = Label("@examples//vendor_external/crates:BUILD.termcolor-1.1.3.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__textwrap-0.15.0",
        sha256 = "b1141d4d61095b28419e22cb0bbf02755f5e54e0526f97f1e3d1d160e60885fb",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/textwrap/0.15.0/download"],
        strip_prefix = "textwrap-0.15.0",
        build_file = Label("@examples//vendor_external/crates:BUILD.textwrap-0.15.0.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__tinyvec-1.6.0",
        sha256 = "87cc5ceb3875bb20c2890005a4e226a4651264a5c75edb2421b52861a0a0cb50",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/tinyvec/1.6.0/download"],
        strip_prefix = "tinyvec-1.6.0",
        build_file = Label("@examples//vendor_external/crates:BUILD.tinyvec-1.6.0.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__tinyvec_macros-0.1.0",
        sha256 = "cda74da7e1a664f795bb1f8a87ec406fb89a02522cf6e50620d016add6dbbf5c",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/tinyvec_macros/0.1.0/download"],
        strip_prefix = "tinyvec_macros-0.1.0",
        build_file = Label("@examples//vendor_external/crates:BUILD.tinyvec_macros-0.1.0.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__toml-0.5.9",
        sha256 = "8d82e1a7758622a465f8cee077614c73484dac5b836c02ff6a40d5d1010324d7",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/toml/0.5.9/download"],
        strip_prefix = "toml-0.5.9",
        build_file = Label("@examples//vendor_external/crates:BUILD.toml-0.5.9.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__unicase-2.6.0",
        sha256 = "50f37be617794602aabbeee0be4f259dc1778fabe05e2d67ee8f79326d5cb4f6",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/unicase/2.6.0/download"],
        strip_prefix = "unicase-2.6.0",
        build_file = Label("@examples//vendor_external/crates:BUILD.unicase-2.6.0.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__unicode-bidi-0.3.8",
        sha256 = "099b7128301d285f79ddd55b9a83d5e6b9e97c92e0ea0daebee7263e932de992",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/unicode-bidi/0.3.8/download"],
        strip_prefix = "unicode-bidi-0.3.8",
        build_file = Label("@examples//vendor_external/crates:BUILD.unicode-bidi-0.3.8.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__unicode-ident-1.0.0",
        sha256 = "d22af068fba1eb5edcb4aea19d382b2a3deb4c8f9d475c589b6ada9e0fd493ee",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/unicode-ident/1.0.0/download"],
        strip_prefix = "unicode-ident-1.0.0",
        build_file = Label("@examples//vendor_external/crates:BUILD.unicode-ident-1.0.0.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__unicode-normalization-0.1.19",
        sha256 = "d54590932941a9e9266f0832deed84ebe1bf2e4c9e4a3554d393d18f5e854bf9",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/unicode-normalization/0.1.19/download"],
        strip_prefix = "unicode-normalization-0.1.19",
        build_file = Label("@examples//vendor_external/crates:BUILD.unicode-normalization-0.1.19.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__url-2.2.2",
        sha256 = "a507c383b2d33b5fc35d1861e77e6b383d158b2da5e14fe51b83dfedf6fd578c",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/url/2.2.2/download"],
        strip_prefix = "url-2.2.2",
        build_file = Label("@examples//vendor_external/crates:BUILD.url-2.2.2.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__version-sync-0.9.4",
        sha256 = "99d0801cec07737d88cb900e6419f6f68733867f90b3faaa837e84692e101bf0",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/version-sync/0.9.4/download"],
        strip_prefix = "version-sync-0.9.4",
        build_file = Label("@examples//vendor_external/crates:BUILD.version-sync-0.9.4.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__version_check-0.9.4",
        sha256 = "49874b5167b65d7193b8aba1567f5c7d93d001cafc34600cee003eda787e483f",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/version_check/0.9.4/download"],
        strip_prefix = "version_check-0.9.4",
        build_file = Label("@examples//vendor_external/crates:BUILD.version_check-0.9.4.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__wasi-0.10.2-wasi-snapshot-preview1",
        sha256 = "fd6fbd9a79829dd1ad0cc20627bf1ed606756a7f77edff7b66b7064f9cb327c6",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/wasi/0.10.2+wasi-snapshot-preview1/download"],
        strip_prefix = "wasi-0.10.2+wasi-snapshot-preview1",
        build_file = Label("@examples//vendor_external/crates:BUILD.wasi-0.10.2+wasi-snapshot-preview1.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__winapi-0.3.9",
        sha256 = "5c839a674fcd7a98952e593242ea400abe93992746761e38641405d28b00f419",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/winapi/0.3.9/download"],
        strip_prefix = "winapi-0.3.9",
        build_file = Label("@examples//vendor_external/crates:BUILD.winapi-0.3.9.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__winapi-i686-pc-windows-gnu-0.4.0",
        sha256 = "ac3b87c63620426dd9b991e5ce0329eff545bccbbb34f3be09ff6fb6ab51b7b6",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/winapi-i686-pc-windows-gnu/0.4.0/download"],
        strip_prefix = "winapi-i686-pc-windows-gnu-0.4.0",
        build_file = Label("@examples//vendor_external/crates:BUILD.winapi-i686-pc-windows-gnu-0.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__winapi-util-0.1.5",
        sha256 = "70ec6ce85bb158151cae5e5c87f95a8e97d2c0c4b001223f33a334e3ce5de178",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/winapi-util/0.1.5/download"],
        strip_prefix = "winapi-util-0.1.5",
        build_file = Label("@examples//vendor_external/crates:BUILD.winapi-util-0.1.5.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__winapi-x86_64-pc-windows-gnu-0.4.0",
        sha256 = "712e227841d057c1ee1cd2fb22fa7e5a5461ae8e48fa2ca79ec42cfc1931183f",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/winapi-x86_64-pc-windows-gnu/0.4.0/download"],
        strip_prefix = "winapi-x86_64-pc-windows-gnu-0.4.0",
        build_file = Label("@examples//vendor_external/crates:BUILD.winapi-x86_64-pc-windows-gnu-0.4.0.bazel"),
    )
