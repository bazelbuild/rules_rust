###############################################################################
# @generated
# DO NOT MODIFY: This file is auto-generated by a crate_universe tool. To
# regenerate this file, run the following:
#
#     bazel run //vendor_external:crates_vendor
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
            "clap": "@crates_vendor__clap-3.2.22//:clap",
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
        name = "crates_vendor__clap-3.2.22",
        sha256 = "86447ad904c7fb335a790c9d7fe3d0d971dc523b8ccd1561a520de9a85302750",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/clap/3.2.22/download"],
        strip_prefix = "clap-3.2.22",
        build_file = Label("@examples//vendor_external/crates:BUILD.clap-3.2.22.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__clap_derive-3.2.18",
        sha256 = "ea0c8bce528c4be4da13ea6fead8965e95b6073585a2f05204bd8f4119f82a65",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/clap_derive/3.2.18/download"],
        strip_prefix = "clap_derive-3.2.18",
        build_file = Label("@examples//vendor_external/crates:BUILD.clap_derive-3.2.18.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__clap_lex-0.2.4",
        sha256 = "2850f2f5a82cbf437dd5af4d49848fbdfc27c157c3d010345776f952765261c5",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/clap_lex/0.2.4/download"],
        strip_prefix = "clap_lex-0.2.4",
        build_file = Label("@examples//vendor_external/crates:BUILD.clap_lex-0.2.4.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__form_urlencoded-1.1.0",
        sha256 = "a9c384f161156f5260c24a097c56119f9be8c798586aecc13afbcbe7b7e26bf8",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/form_urlencoded/1.1.0/download"],
        strip_prefix = "form_urlencoded-1.1.0",
        build_file = Label("@examples//vendor_external/crates:BUILD.form_urlencoded-1.1.0.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__getrandom-0.2.7",
        sha256 = "4eb1a864a501629691edf6c15a593b7a51eebaa1e8468e9ddc623de7c9b58ec6",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/getrandom/0.2.7/download"],
        strip_prefix = "getrandom-0.2.7",
        build_file = Label("@examples//vendor_external/crates:BUILD.getrandom-0.2.7.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__hashbrown-0.12.3",
        sha256 = "8a9ee70c43aaf417c914396645a0fa852624801b24ebb7ae78fe8272889ac888",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/hashbrown/0.12.3/download"],
        strip_prefix = "hashbrown-0.12.3",
        build_file = Label("@examples//vendor_external/crates:BUILD.hashbrown-0.12.3.bazel"),
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
        name = "crates_vendor__idna-0.3.0",
        sha256 = "e14ddfc70884202db2244c223200c204c2bda1bc6e0998d11b5e024d657209e6",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/idna/0.3.0/download"],
        strip_prefix = "idna-0.3.0",
        build_file = Label("@examples//vendor_external/crates:BUILD.idna-0.3.0.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__indexmap-1.9.1",
        sha256 = "10a35a97730320ffe8e2d410b5d3b69279b98d2c14bdb8b70ea89ecf7888d41e",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/indexmap/1.9.1/download"],
        strip_prefix = "indexmap-1.9.1",
        build_file = Label("@examples//vendor_external/crates:BUILD.indexmap-1.9.1.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__libc-0.2.135",
        sha256 = "68783febc7782c6c5cb401fbda4de5a9898be1762314da0bb2c10ced61f18b0c",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/libc/0.2.135/download"],
        strip_prefix = "libc-0.2.135",
        build_file = Label("@examples//vendor_external/crates:BUILD.libc-0.2.135.bazel"),
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
        name = "crates_vendor__once_cell-1.15.0",
        sha256 = "e82dad04139b71a90c080c8463fe0dc7902db5192d939bd0950f074d014339e1",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/once_cell/1.15.0/download"],
        strip_prefix = "once_cell-1.15.0",
        build_file = Label("@examples//vendor_external/crates:BUILD.once_cell-1.15.0.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__os_str_bytes-6.3.0",
        sha256 = "9ff7415e9ae3fff1225851df9e0d9e4e5479f947619774677a63572e55e80eff",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/os_str_bytes/6.3.0/download"],
        strip_prefix = "os_str_bytes-6.3.0",
        build_file = Label("@examples//vendor_external/crates:BUILD.os_str_bytes-6.3.0.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__percent-encoding-2.2.0",
        sha256 = "478c572c3d73181ff3c2539045f6eb99e5491218eae919370993b890cdbdd98e",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/percent-encoding/2.2.0/download"],
        strip_prefix = "percent-encoding-2.2.0",
        build_file = Label("@examples//vendor_external/crates:BUILD.percent-encoding-2.2.0.bazel"),
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
        name = "crates_vendor__proc-macro2-1.0.47",
        sha256 = "5ea3d908b0e36316caf9e9e2c4625cdde190a7e6f440d794667ed17a1855e725",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/proc-macro2/1.0.47/download"],
        strip_prefix = "proc-macro2-1.0.47",
        build_file = Label("@examples//vendor_external/crates:BUILD.proc-macro2-1.0.47.bazel"),
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
        name = "crates_vendor__quote-1.0.21",
        sha256 = "bbe448f377a7d6961e30f5955f9b8d106c3f5e449d493ee1b125c1d43c2b5179",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/quote/1.0.21/download"],
        strip_prefix = "quote-1.0.21",
        build_file = Label("@examples//vendor_external/crates:BUILD.quote-1.0.21.bazel"),
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
        name = "crates_vendor__rand_core-0.6.4",
        sha256 = "ec0be4795e2f6a28069bec0b5ff3e2ac9bafc99e6a9a7dc3547996c5c816922c",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/rand_core/0.6.4/download"],
        strip_prefix = "rand_core-0.6.4",
        build_file = Label("@examples//vendor_external/crates:BUILD.rand_core-0.6.4.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__regex-1.6.0",
        sha256 = "4c4eb3267174b8c6c2f654116623910a0fef09c4753f8dd83db29c48a0df988b",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/regex/1.6.0/download"],
        strip_prefix = "regex-1.6.0",
        build_file = Label("@examples//vendor_external/crates:BUILD.regex-1.6.0.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__regex-syntax-0.6.27",
        sha256 = "a3f87b73ce11b1619a3c6332f45341e0047173771e8b8b73f87bfeefb7b56244",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/regex-syntax/0.6.27/download"],
        strip_prefix = "regex-syntax-0.6.27",
        build_file = Label("@examples//vendor_external/crates:BUILD.regex-syntax-0.6.27.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__semver-1.0.14",
        sha256 = "e25dfac463d778e353db5be2449d1cce89bd6fd23c9f1ea21310ce6e5a1b29c4",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/semver/1.0.14/download"],
        strip_prefix = "semver-1.0.14",
        build_file = Label("@examples//vendor_external/crates:BUILD.semver-1.0.14.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__serde-1.0.145",
        sha256 = "728eb6351430bccb993660dfffc5a72f91ccc1295abaa8ce19b27ebe4f75568b",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/serde/1.0.145/download"],
        strip_prefix = "serde-1.0.145",
        build_file = Label("@examples//vendor_external/crates:BUILD.serde-1.0.145.bazel"),
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
        name = "crates_vendor__syn-1.0.102",
        sha256 = "3fcd952facd492f9be3ef0d0b7032a6e442ee9b361d4acc2b1d0c4aaa5f613a1",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/syn/1.0.102/download"],
        strip_prefix = "syn-1.0.102",
        build_file = Label("@examples//vendor_external/crates:BUILD.syn-1.0.102.bazel"),
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
        name = "crates_vendor__textwrap-0.15.1",
        sha256 = "949517c0cf1bf4ee812e2e07e08ab448e3ae0d23472aee8a06c985f0c8815b16",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/textwrap/0.15.1/download"],
        strip_prefix = "textwrap-0.15.1",
        build_file = Label("@examples//vendor_external/crates:BUILD.textwrap-0.15.1.bazel"),
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
        name = "crates_vendor__unicode-ident-1.0.5",
        sha256 = "6ceab39d59e4c9499d4e5a8ee0e2735b891bb7308ac83dfb4e80cad195c9f6f3",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/unicode-ident/1.0.5/download"],
        strip_prefix = "unicode-ident-1.0.5",
        build_file = Label("@examples//vendor_external/crates:BUILD.unicode-ident-1.0.5.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__unicode-normalization-0.1.22",
        sha256 = "5c5713f0fc4b5db668a2ac63cdb7bb4469d8c9fed047b1d0292cc7b0ce2ba921",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/unicode-normalization/0.1.22/download"],
        strip_prefix = "unicode-normalization-0.1.22",
        build_file = Label("@examples//vendor_external/crates:BUILD.unicode-normalization-0.1.22.bazel"),
    )

    maybe(
        http_archive,
        name = "crates_vendor__url-2.3.1",
        sha256 = "0d68c799ae75762b8c3fe375feb6600ef5602c883c5d21eb51c09f22b83c4643",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/url/2.3.1/download"],
        strip_prefix = "url-2.3.1",
        build_file = Label("@examples//vendor_external/crates:BUILD.url-2.3.1.bazel"),
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
        name = "crates_vendor__wasi-0.11.0-wasi-snapshot-preview1",
        sha256 = "9c8d87e72b64a3b4db28d11ce29237c246188f4f51057d65a7eab63b7987e423",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/wasi/0.11.0+wasi-snapshot-preview1/download"],
        strip_prefix = "wasi-0.11.0+wasi-snapshot-preview1",
        build_file = Label("@examples//vendor_external/crates:BUILD.wasi-0.11.0+wasi-snapshot-preview1.bazel"),
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
