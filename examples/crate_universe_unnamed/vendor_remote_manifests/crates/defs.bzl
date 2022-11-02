###############################################################################
# @generated
# DO NOT MODIFY: This file is auto-generated by a crate_universe tool. To
# regenerate this file, run the following:
#
#     bazel run //vendor_remote_manifests:crates_vendor_manifests
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
    "vendor_remote_manifests": {
        _COMMON_CONDITION: {
            "tokio": "@crates_vendor_manifests__tokio-1.21.2//:tokio",
        },
    },
}

_NORMAL_ALIASES = {
    "vendor_remote_manifests": {
        _COMMON_CONDITION: {
        },
    },
}

_NORMAL_DEV_DEPENDENCIES = {
    "vendor_remote_manifests": {
        _COMMON_CONDITION: {
            "tempfile": "@crates_vendor_manifests__tempfile-3.3.0//:tempfile",
            "tokio-test": "@crates_vendor_manifests__tokio-test-0.4.2//:tokio_test",
        },
    },
}

_NORMAL_DEV_ALIASES = {
    "vendor_remote_manifests": {
        _COMMON_CONDITION: {
        },
    },
}

_PROC_MACRO_DEPENDENCIES = {
    "vendor_remote_manifests": {
    },
}

_PROC_MACRO_ALIASES = {
    "vendor_remote_manifests": {
    },
}

_PROC_MACRO_DEV_DEPENDENCIES = {
    "vendor_remote_manifests": {
    },
}

_PROC_MACRO_DEV_ALIASES = {
    "vendor_remote_manifests": {
        _COMMON_CONDITION: {
        },
    },
}

_BUILD_DEPENDENCIES = {
    "vendor_remote_manifests": {
    },
}

_BUILD_ALIASES = {
    "vendor_remote_manifests": {
    },
}

_BUILD_PROC_MACRO_DEPENDENCIES = {
    "vendor_remote_manifests": {
    },
}

_BUILD_PROC_MACRO_ALIASES = {
    "vendor_remote_manifests": {
    },
}

_CONDITIONS = {
    "aarch64-pc-windows-gnullvm": [],
    "aarch64-pc-windows-msvc": [],
    "aarch64-uwp-windows-msvc": [],
    "cfg(all(any(target_arch = \"x86_64\", target_arch = \"aarch64\"), target_os = \"hermit\"))": [],
    "cfg(any(unix, target_os = \"wasi\"))": ["aarch64-apple-darwin", "aarch64-apple-ios", "aarch64-apple-ios-sim", "aarch64-linux-android", "aarch64-unknown-linux-gnu", "arm-unknown-linux-gnueabi", "armv7-linux-androideabi", "armv7-unknown-linux-gnueabi", "i686-apple-darwin", "i686-linux-android", "i686-unknown-freebsd", "i686-unknown-linux-gnu", "powerpc-unknown-linux-gnu", "s390x-unknown-linux-gnu", "wasm32-wasi", "x86_64-apple-darwin", "x86_64-apple-ios", "x86_64-linux-android", "x86_64-unknown-freebsd", "x86_64-unknown-linux-gnu"],
    "cfg(not(any(target_arch = \"wasm32\", target_arch = \"wasm64\")))": ["aarch64-apple-darwin", "aarch64-apple-ios", "aarch64-apple-ios-sim", "aarch64-linux-android", "aarch64-unknown-linux-gnu", "arm-unknown-linux-gnueabi", "armv7-linux-androideabi", "armv7-unknown-linux-gnueabi", "i686-apple-darwin", "i686-linux-android", "i686-pc-windows-msvc", "i686-unknown-freebsd", "i686-unknown-linux-gnu", "powerpc-unknown-linux-gnu", "riscv32imc-unknown-none-elf", "s390x-unknown-linux-gnu", "x86_64-apple-darwin", "x86_64-apple-ios", "x86_64-linux-android", "x86_64-pc-windows-msvc", "x86_64-unknown-freebsd", "x86_64-unknown-linux-gnu"],
    "cfg(not(windows))": ["aarch64-apple-darwin", "aarch64-apple-ios", "aarch64-apple-ios-sim", "aarch64-linux-android", "aarch64-unknown-linux-gnu", "arm-unknown-linux-gnueabi", "armv7-linux-androideabi", "armv7-unknown-linux-gnueabi", "i686-apple-darwin", "i686-linux-android", "i686-unknown-freebsd", "i686-unknown-linux-gnu", "powerpc-unknown-linux-gnu", "riscv32imc-unknown-none-elf", "s390x-unknown-linux-gnu", "wasm32-unknown-unknown", "wasm32-wasi", "x86_64-apple-darwin", "x86_64-apple-ios", "x86_64-linux-android", "x86_64-unknown-freebsd", "x86_64-unknown-linux-gnu"],
    "cfg(target_arch = \"wasm32\")": ["wasm32-unknown-unknown", "wasm32-wasi"],
    "cfg(target_os = \"redox\")": [],
    "cfg(target_os = \"wasi\")": ["wasm32-wasi"],
    "cfg(unix)": ["aarch64-apple-darwin", "aarch64-apple-ios", "aarch64-apple-ios-sim", "aarch64-linux-android", "aarch64-unknown-linux-gnu", "arm-unknown-linux-gnueabi", "armv7-linux-androideabi", "armv7-unknown-linux-gnueabi", "i686-apple-darwin", "i686-linux-android", "i686-unknown-freebsd", "i686-unknown-linux-gnu", "powerpc-unknown-linux-gnu", "s390x-unknown-linux-gnu", "x86_64-apple-darwin", "x86_64-apple-ios", "x86_64-linux-android", "x86_64-unknown-freebsd", "x86_64-unknown-linux-gnu"],
    "cfg(windows)": ["i686-pc-windows-msvc", "x86_64-pc-windows-msvc"],
    "i686-pc-windows-gnu": [],
    "i686-pc-windows-msvc": ["i686-pc-windows-msvc"],
    "i686-uwp-windows-gnu": [],
    "i686-uwp-windows-msvc": [],
    "x86_64-pc-windows-gnu": [],
    "x86_64-pc-windows-gnullvm": [],
    "x86_64-pc-windows-msvc": ["x86_64-pc-windows-msvc"],
    "x86_64-uwp-windows-gnu": [],
    "x86_64-uwp-windows-msvc": [],
}

###############################################################################

def crate_repositories():
    """A macro for defining repositories for all generated crates"""
    maybe(
        http_archive,
        name = "crates_vendor_manifests__async-stream-0.3.3",
        sha256 = "dad5c83079eae9969be7fadefe640a1c566901f05ff91ab221de4b6f68d9507e",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/async-stream/0.3.3/download"],
        strip_prefix = "async-stream-0.3.3",
        build_file = Label("@//vendor_remote_manifests/crates:BUILD.async-stream-0.3.3.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor_manifests__async-stream-impl-0.3.3",
        sha256 = "10f203db73a71dfa2fb6dd22763990fa26f3d2625a6da2da900d23b87d26be27",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/async-stream-impl/0.3.3/download"],
        strip_prefix = "async-stream-impl-0.3.3",
        build_file = Label("@//vendor_remote_manifests/crates:BUILD.async-stream-impl-0.3.3.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor_manifests__autocfg-1.1.0",
        sha256 = "d468802bab17cbc0cc575e9b053f41e72aa36bfa6b7f55e3529ffa43161b97fa",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/autocfg/1.1.0/download"],
        strip_prefix = "autocfg-1.1.0",
        build_file = Label("@//vendor_remote_manifests/crates:BUILD.autocfg-1.1.0.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor_manifests__bitflags-1.3.2",
        sha256 = "bef38d45163c2f1dde094a7dfd33ccf595c92905c8f8f4fdc18d06fb1037718a",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/bitflags/1.3.2/download"],
        strip_prefix = "bitflags-1.3.2",
        build_file = Label("@//vendor_remote_manifests/crates:BUILD.bitflags-1.3.2.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor_manifests__bytes-1.2.1",
        sha256 = "ec8a7b6a70fde80372154c65702f00a0f56f3e1c36abbc6c440484be248856db",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/bytes/1.2.1/download"],
        strip_prefix = "bytes-1.2.1",
        build_file = Label("@//vendor_remote_manifests/crates:BUILD.bytes-1.2.1.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor_manifests__cfg-if-1.0.0",
        sha256 = "baf1de4339761588bc0619e3cbc0120ee582ebb74b53b4efbf79117bd2da40fd",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/cfg-if/1.0.0/download"],
        strip_prefix = "cfg-if-1.0.0",
        build_file = Label("@//vendor_remote_manifests/crates:BUILD.cfg-if-1.0.0.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor_manifests__fastrand-1.8.0",
        sha256 = "a7a407cfaa3385c4ae6b23e84623d48c2798d06e3e6a1878f7f59f17b3f86499",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/fastrand/1.8.0/download"],
        strip_prefix = "fastrand-1.8.0",
        build_file = Label("@//vendor_remote_manifests/crates:BUILD.fastrand-1.8.0.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor_manifests__futures-core-0.3.25",
        sha256 = "04909a7a7e4633ae6c4a9ab280aeb86da1236243a77b694a49eacd659a4bd3ac",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/futures-core/0.3.25/download"],
        strip_prefix = "futures-core-0.3.25",
        build_file = Label("@//vendor_remote_manifests/crates:BUILD.futures-core-0.3.25.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor_manifests__hermit-abi-0.1.19",
        sha256 = "62b467343b94ba476dcb2500d242dadbb39557df889310ac77c5d99100aaac33",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/hermit-abi/0.1.19/download"],
        strip_prefix = "hermit-abi-0.1.19",
        build_file = Label("@//vendor_remote_manifests/crates:BUILD.hermit-abi-0.1.19.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor_manifests__instant-0.1.12",
        sha256 = "7a5bbe824c507c5da5956355e86a746d82e0e1464f65d862cc5e71da70e94b2c",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/instant/0.1.12/download"],
        strip_prefix = "instant-0.1.12",
        build_file = Label("@//vendor_remote_manifests/crates:BUILD.instant-0.1.12.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor_manifests__libc-0.2.137",
        sha256 = "fc7fcc620a3bff7cdd7a365be3376c97191aeaccc2a603e600951e452615bf89",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/libc/0.2.137/download"],
        strip_prefix = "libc-0.2.137",
        build_file = Label("@//vendor_remote_manifests/crates:BUILD.libc-0.2.137.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor_manifests__lock_api-0.4.9",
        sha256 = "435011366fe56583b16cf956f9df0095b405b82d76425bc8981c0e22e60ec4df",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/lock_api/0.4.9/download"],
        strip_prefix = "lock_api-0.4.9",
        build_file = Label("@//vendor_remote_manifests/crates:BUILD.lock_api-0.4.9.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor_manifests__log-0.4.17",
        sha256 = "abb12e687cfb44aa40f41fc3978ef76448f9b6038cad6aef4259d3c095a2382e",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/log/0.4.17/download"],
        strip_prefix = "log-0.4.17",
        build_file = Label("@//vendor_remote_manifests/crates:BUILD.log-0.4.17.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor_manifests__memchr-2.5.0",
        sha256 = "2dffe52ecf27772e601905b7522cb4ef790d2cc203488bbd0e2fe85fcb74566d",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/memchr/2.5.0/download"],
        strip_prefix = "memchr-2.5.0",
        build_file = Label("@//vendor_remote_manifests/crates:BUILD.memchr-2.5.0.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor_manifests__mio-0.8.5",
        sha256 = "e5d732bc30207a6423068df043e3d02e0735b155ad7ce1a6f76fe2baa5b158de",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/mio/0.8.5/download"],
        strip_prefix = "mio-0.8.5",
        build_file = Label("@//vendor_remote_manifests/crates:BUILD.mio-0.8.5.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor_manifests__num_cpus-1.13.1",
        sha256 = "19e64526ebdee182341572e50e9ad03965aa510cd94427a4549448f285e957a1",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/num_cpus/1.13.1/download"],
        strip_prefix = "num_cpus-1.13.1",
        build_file = Label("@//vendor_remote_manifests/crates:BUILD.num_cpus-1.13.1.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor_manifests__parking_lot-0.12.1",
        sha256 = "3742b2c103b9f06bc9fff0a37ff4912935851bee6d36f3c02bcc755bcfec228f",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/parking_lot/0.12.1/download"],
        strip_prefix = "parking_lot-0.12.1",
        build_file = Label("@//vendor_remote_manifests/crates:BUILD.parking_lot-0.12.1.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor_manifests__parking_lot_core-0.9.4",
        sha256 = "4dc9e0dc2adc1c69d09143aff38d3d30c5c3f0df0dad82e6d25547af174ebec0",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/parking_lot_core/0.9.4/download"],
        strip_prefix = "parking_lot_core-0.9.4",
        build_file = Label("@//vendor_remote_manifests/crates:BUILD.parking_lot_core-0.9.4.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor_manifests__pin-project-lite-0.2.9",
        sha256 = "e0a7ae3ac2f1173085d398531c705756c94a4c56843785df85a60c1a0afac116",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/pin-project-lite/0.2.9/download"],
        strip_prefix = "pin-project-lite-0.2.9",
        build_file = Label("@//vendor_remote_manifests/crates:BUILD.pin-project-lite-0.2.9.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor_manifests__proc-macro2-1.0.47",
        sha256 = "5ea3d908b0e36316caf9e9e2c4625cdde190a7e6f440d794667ed17a1855e725",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/proc-macro2/1.0.47/download"],
        strip_prefix = "proc-macro2-1.0.47",
        build_file = Label("@//vendor_remote_manifests/crates:BUILD.proc-macro2-1.0.47.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor_manifests__quote-1.0.21",
        sha256 = "bbe448f377a7d6961e30f5955f9b8d106c3f5e449d493ee1b125c1d43c2b5179",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/quote/1.0.21/download"],
        strip_prefix = "quote-1.0.21",
        build_file = Label("@//vendor_remote_manifests/crates:BUILD.quote-1.0.21.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor_manifests__redox_syscall-0.2.16",
        sha256 = "fb5a58c1855b4b6819d59012155603f0b22ad30cad752600aadfcb695265519a",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/redox_syscall/0.2.16/download"],
        strip_prefix = "redox_syscall-0.2.16",
        build_file = Label("@//vendor_remote_manifests/crates:BUILD.redox_syscall-0.2.16.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor_manifests__remove_dir_all-0.5.3",
        sha256 = "3acd125665422973a33ac9d3dd2df85edad0f4ae9b00dafb1a05e43a9f5ef8e7",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/remove_dir_all/0.5.3/download"],
        strip_prefix = "remove_dir_all-0.5.3",
        build_file = Label("@//vendor_remote_manifests/crates:BUILD.remove_dir_all-0.5.3.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor_manifests__scopeguard-1.1.0",
        sha256 = "d29ab0c6d3fc0ee92fe66e2d99f700eab17a8d57d1c1d3b748380fb20baa78cd",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/scopeguard/1.1.0/download"],
        strip_prefix = "scopeguard-1.1.0",
        build_file = Label("@//vendor_remote_manifests/crates:BUILD.scopeguard-1.1.0.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor_manifests__signal-hook-registry-1.4.0",
        sha256 = "e51e73328dc4ac0c7ccbda3a494dfa03df1de2f46018127f60c693f2648455b0",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/signal-hook-registry/1.4.0/download"],
        strip_prefix = "signal-hook-registry-1.4.0",
        build_file = Label("@//vendor_remote_manifests/crates:BUILD.signal-hook-registry-1.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor_manifests__smallvec-1.10.0",
        sha256 = "a507befe795404456341dfab10cef66ead4c041f62b8b11bbb92bffe5d0953e0",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/smallvec/1.10.0/download"],
        strip_prefix = "smallvec-1.10.0",
        build_file = Label("@//vendor_remote_manifests/crates:BUILD.smallvec-1.10.0.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor_manifests__socket2-0.4.7",
        sha256 = "02e2d2db9033d13a1567121ddd7a095ee144db4e1ca1b1bda3419bc0da294ebd",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/socket2/0.4.7/download"],
        strip_prefix = "socket2-0.4.7",
        build_file = Label("@//vendor_remote_manifests/crates:BUILD.socket2-0.4.7.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor_manifests__syn-1.0.103",
        sha256 = "a864042229133ada95abf3b54fdc62ef5ccabe9515b64717bcb9a1919e59445d",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/syn/1.0.103/download"],
        strip_prefix = "syn-1.0.103",
        build_file = Label("@//vendor_remote_manifests/crates:BUILD.syn-1.0.103.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor_manifests__tempfile-3.3.0",
        sha256 = "5cdb1ef4eaeeaddc8fbd371e5017057064af0911902ef36b39801f67cc6d79e4",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/tempfile/3.3.0/download"],
        strip_prefix = "tempfile-3.3.0",
        build_file = Label("@//vendor_remote_manifests/crates:BUILD.tempfile-3.3.0.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor_manifests__tokio-1.21.2",
        sha256 = "a9e03c497dc955702ba729190dc4aac6f2a0ce97f913e5b1b5912fc5039d9099",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/tokio/1.21.2/download"],
        strip_prefix = "tokio-1.21.2",
        build_file = Label("@//vendor_remote_manifests/crates:BUILD.tokio-1.21.2.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor_manifests__tokio-macros-1.8.0",
        sha256 = "9724f9a975fb987ef7a3cd9be0350edcbe130698af5b8f7a631e23d42d052484",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/tokio-macros/1.8.0/download"],
        strip_prefix = "tokio-macros-1.8.0",
        build_file = Label("@//vendor_remote_manifests/crates:BUILD.tokio-macros-1.8.0.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor_manifests__tokio-stream-0.1.11",
        sha256 = "d660770404473ccd7bc9f8b28494a811bc18542b915c0855c51e8f419d5223ce",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/tokio-stream/0.1.11/download"],
        strip_prefix = "tokio-stream-0.1.11",
        build_file = Label("@//vendor_remote_manifests/crates:BUILD.tokio-stream-0.1.11.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor_manifests__tokio-test-0.4.2",
        sha256 = "53474327ae5e166530d17f2d956afcb4f8a004de581b3cae10f12006bc8163e3",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/tokio-test/0.4.2/download"],
        strip_prefix = "tokio-test-0.4.2",
        build_file = Label("@//vendor_remote_manifests/crates:BUILD.tokio-test-0.4.2.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor_manifests__unicode-ident-1.0.5",
        sha256 = "6ceab39d59e4c9499d4e5a8ee0e2735b891bb7308ac83dfb4e80cad195c9f6f3",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/unicode-ident/1.0.5/download"],
        strip_prefix = "unicode-ident-1.0.5",
        build_file = Label("@//vendor_remote_manifests/crates:BUILD.unicode-ident-1.0.5.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor_manifests__wasi-0.11.0-wasi-snapshot-preview1",
        sha256 = "9c8d87e72b64a3b4db28d11ce29237c246188f4f51057d65a7eab63b7987e423",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/wasi/0.11.0+wasi-snapshot-preview1/download"],
        strip_prefix = "wasi-0.11.0+wasi-snapshot-preview1",
        build_file = Label("@//vendor_remote_manifests/crates:BUILD.wasi-0.11.0+wasi-snapshot-preview1.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor_manifests__winapi-0.3.9",
        sha256 = "5c839a674fcd7a98952e593242ea400abe93992746761e38641405d28b00f419",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/winapi/0.3.9/download"],
        strip_prefix = "winapi-0.3.9",
        build_file = Label("@//vendor_remote_manifests/crates:BUILD.winapi-0.3.9.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor_manifests__winapi-i686-pc-windows-gnu-0.4.0",
        sha256 = "ac3b87c63620426dd9b991e5ce0329eff545bccbbb34f3be09ff6fb6ab51b7b6",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/winapi-i686-pc-windows-gnu/0.4.0/download"],
        strip_prefix = "winapi-i686-pc-windows-gnu-0.4.0",
        build_file = Label("@//vendor_remote_manifests/crates:BUILD.winapi-i686-pc-windows-gnu-0.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor_manifests__winapi-x86_64-pc-windows-gnu-0.4.0",
        sha256 = "712e227841d057c1ee1cd2fb22fa7e5a5461ae8e48fa2ca79ec42cfc1931183f",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/winapi-x86_64-pc-windows-gnu/0.4.0/download"],
        strip_prefix = "winapi-x86_64-pc-windows-gnu-0.4.0",
        build_file = Label("@//vendor_remote_manifests/crates:BUILD.winapi-x86_64-pc-windows-gnu-0.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor_manifests__windows-sys-0.42.0",
        sha256 = "5a3e1820f08b8513f676f7ab6c1f99ff312fb97b553d30ff4dd86f9f15728aa7",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/windows-sys/0.42.0/download"],
        strip_prefix = "windows-sys-0.42.0",
        build_file = Label("@//vendor_remote_manifests/crates:BUILD.windows-sys-0.42.0.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor_manifests__windows_aarch64_gnullvm-0.42.0",
        sha256 = "41d2aa71f6f0cbe00ae5167d90ef3cfe66527d6f613ca78ac8024c3ccab9a19e",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/windows_aarch64_gnullvm/0.42.0/download"],
        strip_prefix = "windows_aarch64_gnullvm-0.42.0",
        build_file = Label("@//vendor_remote_manifests/crates:BUILD.windows_aarch64_gnullvm-0.42.0.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor_manifests__windows_aarch64_msvc-0.42.0",
        sha256 = "dd0f252f5a35cac83d6311b2e795981f5ee6e67eb1f9a7f64eb4500fbc4dcdb4",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/windows_aarch64_msvc/0.42.0/download"],
        strip_prefix = "windows_aarch64_msvc-0.42.0",
        build_file = Label("@//vendor_remote_manifests/crates:BUILD.windows_aarch64_msvc-0.42.0.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor_manifests__windows_i686_gnu-0.42.0",
        sha256 = "fbeae19f6716841636c28d695375df17562ca208b2b7d0dc47635a50ae6c5de7",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/windows_i686_gnu/0.42.0/download"],
        strip_prefix = "windows_i686_gnu-0.42.0",
        build_file = Label("@//vendor_remote_manifests/crates:BUILD.windows_i686_gnu-0.42.0.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor_manifests__windows_i686_msvc-0.42.0",
        sha256 = "84c12f65daa39dd2babe6e442988fc329d6243fdce47d7d2d155b8d874862246",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/windows_i686_msvc/0.42.0/download"],
        strip_prefix = "windows_i686_msvc-0.42.0",
        build_file = Label("@//vendor_remote_manifests/crates:BUILD.windows_i686_msvc-0.42.0.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor_manifests__windows_x86_64_gnu-0.42.0",
        sha256 = "bf7b1b21b5362cbc318f686150e5bcea75ecedc74dd157d874d754a2ca44b0ed",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/windows_x86_64_gnu/0.42.0/download"],
        strip_prefix = "windows_x86_64_gnu-0.42.0",
        build_file = Label("@//vendor_remote_manifests/crates:BUILD.windows_x86_64_gnu-0.42.0.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor_manifests__windows_x86_64_gnullvm-0.42.0",
        sha256 = "09d525d2ba30eeb3297665bd434a54297e4170c7f1a44cad4ef58095b4cd2028",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/windows_x86_64_gnullvm/0.42.0/download"],
        strip_prefix = "windows_x86_64_gnullvm-0.42.0",
        build_file = Label("@//vendor_remote_manifests/crates:BUILD.windows_x86_64_gnullvm-0.42.0.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor_manifests__windows_x86_64_msvc-0.42.0",
        sha256 = "f40009d85759725a34da6d89a94e63d7bdc50a862acf0dbc7c8e488f1edcb6f5",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/windows_x86_64_msvc/0.42.0/download"],
        strip_prefix = "windows_x86_64_msvc-0.42.0",
        build_file = Label("@//vendor_remote_manifests/crates:BUILD.windows_x86_64_msvc-0.42.0.bazel"),
    )
