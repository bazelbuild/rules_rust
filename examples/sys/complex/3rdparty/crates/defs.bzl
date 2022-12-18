###############################################################################
# @generated
# DO NOT MODIFY: This file is auto-generated by a crate_universe tool. To
# regenerate this file, run the following:
#
#     bazel run //sys/complex/3rdparty:crates_vendor
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
            "git2": "@complex_sys__git2-0.14.4//:git2",
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
    },
}

_NORMAL_DEV_ALIASES = {
    "": {
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
    "cfg(unix)": ["aarch64-apple-darwin", "aarch64-apple-ios", "aarch64-apple-ios-sim", "aarch64-linux-android", "aarch64-unknown-linux-gnu", "arm-unknown-linux-gnueabi", "armv7-linux-androideabi", "armv7-unknown-linux-gnueabi", "i686-apple-darwin", "i686-linux-android", "i686-unknown-freebsd", "i686-unknown-linux-gnu", "powerpc-unknown-linux-gnu", "s390x-unknown-linux-gnu", "x86_64-apple-darwin", "x86_64-apple-ios", "x86_64-linux-android", "x86_64-unknown-freebsd", "x86_64-unknown-linux-gnu"],
}

###############################################################################

def crate_repositories():
    """A macro for defining repositories for all generated crates"""
    maybe(
        http_archive,
        name = "complex_sys__bitflags-1.3.2",
        sha256 = "bef38d45163c2f1dde094a7dfd33ccf595c92905c8f8f4fdc18d06fb1037718a",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/bitflags/1.3.2/download"],
        strip_prefix = "bitflags-1.3.2",
        build_file = Label("@examples//sys/complex/3rdparty/crates:BUILD.bitflags-1.3.2.bazel"),
    )

    maybe(
        http_archive,
        name = "complex_sys__cc-1.0.77",
        sha256 = "e9f73505338f7d905b19d18738976aae232eb46b8efc15554ffc56deb5d9ebe4",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/cc/1.0.77/download"],
        strip_prefix = "cc-1.0.77",
        build_file = Label("@examples//sys/complex/3rdparty/crates:BUILD.cc-1.0.77.bazel"),
    )

    maybe(
        http_archive,
        name = "complex_sys__cfg-if-1.0.0",
        sha256 = "baf1de4339761588bc0619e3cbc0120ee582ebb74b53b4efbf79117bd2da40fd",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/cfg-if/1.0.0/download"],
        strip_prefix = "cfg-if-1.0.0",
        build_file = Label("@examples//sys/complex/3rdparty/crates:BUILD.cfg-if-1.0.0.bazel"),
    )

    maybe(
        http_archive,
        name = "complex_sys__form_urlencoded-1.1.0",
        sha256 = "a9c384f161156f5260c24a097c56119f9be8c798586aecc13afbcbe7b7e26bf8",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/form_urlencoded/1.1.0/download"],
        strip_prefix = "form_urlencoded-1.1.0",
        build_file = Label("@examples//sys/complex/3rdparty/crates:BUILD.form_urlencoded-1.1.0.bazel"),
    )

    maybe(
        http_archive,
        name = "complex_sys__git2-0.14.4",
        sha256 = "d0155506aab710a86160ddb504a480d2964d7ab5b9e62419be69e0032bc5931c",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/git2/0.14.4/download"],
        strip_prefix = "git2-0.14.4",
        build_file = Label("@examples//sys/complex/3rdparty/crates:BUILD.git2-0.14.4.bazel"),
    )

    maybe(
        http_archive,
        name = "complex_sys__idna-0.3.0",
        sha256 = "e14ddfc70884202db2244c223200c204c2bda1bc6e0998d11b5e024d657209e6",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/idna/0.3.0/download"],
        strip_prefix = "idna-0.3.0",
        build_file = Label("@examples//sys/complex/3rdparty/crates:BUILD.idna-0.3.0.bazel"),
    )

    maybe(
        http_archive,
        name = "complex_sys__jobserver-0.1.25",
        sha256 = "068b1ee6743e4d11fb9c6a1e6064b3693a1b600e7f5f5988047d98b3dc9fb90b",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/jobserver/0.1.25/download"],
        strip_prefix = "jobserver-0.1.25",
        build_file = Label("@examples//sys/complex/3rdparty/crates:BUILD.jobserver-0.1.25.bazel"),
    )

    maybe(
        http_archive,
        name = "complex_sys__libc-0.2.137",
        sha256 = "fc7fcc620a3bff7cdd7a365be3376c97191aeaccc2a603e600951e452615bf89",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/libc/0.2.137/download"],
        strip_prefix = "libc-0.2.137",
        build_file = Label("@examples//sys/complex/3rdparty/crates:BUILD.libc-0.2.137.bazel"),
    )

    maybe(
        http_archive,
        name = "complex_sys__libgit2-sys-0.13.4-1.4.2",
        sha256 = "d0fa6563431ede25f5cc7f6d803c6afbc1c5d3ad3d4925d12c882bf2b526f5d1",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/libgit2-sys/0.13.4+1.4.2/download"],
        strip_prefix = "libgit2-sys-0.13.4+1.4.2",
        build_file = Label("@examples//sys/complex/3rdparty/crates:BUILD.libgit2-sys-0.13.4+1.4.2.bazel"),
    )

    maybe(
        http_archive,
        name = "complex_sys__libz-sys-1.1.8",
        sha256 = "9702761c3935f8cc2f101793272e202c72b99da8f4224a19ddcf1279a6450bbf",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/libz-sys/1.1.8/download"],
        strip_prefix = "libz-sys-1.1.8",
        build_file = Label("@examples//sys/complex/3rdparty/crates:BUILD.libz-sys-1.1.8.bazel"),
    )

    maybe(
        http_archive,
        name = "complex_sys__log-0.4.17",
        sha256 = "abb12e687cfb44aa40f41fc3978ef76448f9b6038cad6aef4259d3c095a2382e",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/log/0.4.17/download"],
        strip_prefix = "log-0.4.17",
        build_file = Label("@examples//sys/complex/3rdparty/crates:BUILD.log-0.4.17.bazel"),
    )

    maybe(
        http_archive,
        name = "complex_sys__percent-encoding-2.2.0",
        sha256 = "478c572c3d73181ff3c2539045f6eb99e5491218eae919370993b890cdbdd98e",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/percent-encoding/2.2.0/download"],
        strip_prefix = "percent-encoding-2.2.0",
        build_file = Label("@examples//sys/complex/3rdparty/crates:BUILD.percent-encoding-2.2.0.bazel"),
    )

    maybe(
        http_archive,
        name = "complex_sys__pkg-config-0.3.26",
        sha256 = "6ac9a59f73473f1b8d852421e59e64809f025994837ef743615c6d0c5b305160",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/pkg-config/0.3.26/download"],
        strip_prefix = "pkg-config-0.3.26",
        build_file = Label("@examples//sys/complex/3rdparty/crates:BUILD.pkg-config-0.3.26.bazel"),
    )

    maybe(
        http_archive,
        name = "complex_sys__tinyvec-1.6.0",
        sha256 = "87cc5ceb3875bb20c2890005a4e226a4651264a5c75edb2421b52861a0a0cb50",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/tinyvec/1.6.0/download"],
        strip_prefix = "tinyvec-1.6.0",
        build_file = Label("@examples//sys/complex/3rdparty/crates:BUILD.tinyvec-1.6.0.bazel"),
    )

    maybe(
        http_archive,
        name = "complex_sys__tinyvec_macros-0.1.0",
        sha256 = "cda74da7e1a664f795bb1f8a87ec406fb89a02522cf6e50620d016add6dbbf5c",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/tinyvec_macros/0.1.0/download"],
        strip_prefix = "tinyvec_macros-0.1.0",
        build_file = Label("@examples//sys/complex/3rdparty/crates:BUILD.tinyvec_macros-0.1.0.bazel"),
    )

    maybe(
        http_archive,
        name = "complex_sys__unicode-bidi-0.3.8",
        sha256 = "099b7128301d285f79ddd55b9a83d5e6b9e97c92e0ea0daebee7263e932de992",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/unicode-bidi/0.3.8/download"],
        strip_prefix = "unicode-bidi-0.3.8",
        build_file = Label("@examples//sys/complex/3rdparty/crates:BUILD.unicode-bidi-0.3.8.bazel"),
    )

    maybe(
        http_archive,
        name = "complex_sys__unicode-normalization-0.1.22",
        sha256 = "5c5713f0fc4b5db668a2ac63cdb7bb4469d8c9fed047b1d0292cc7b0ce2ba921",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/unicode-normalization/0.1.22/download"],
        strip_prefix = "unicode-normalization-0.1.22",
        build_file = Label("@examples//sys/complex/3rdparty/crates:BUILD.unicode-normalization-0.1.22.bazel"),
    )

    maybe(
        http_archive,
        name = "complex_sys__url-2.3.1",
        sha256 = "0d68c799ae75762b8c3fe375feb6600ef5602c883c5d21eb51c09f22b83c4643",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/url/2.3.1/download"],
        strip_prefix = "url-2.3.1",
        build_file = Label("@examples//sys/complex/3rdparty/crates:BUILD.url-2.3.1.bazel"),
    )

    maybe(
        http_archive,
        name = "complex_sys__vcpkg-0.2.15",
        sha256 = "accd4ea62f7bb7a82fe23066fb0957d48ef677f6eeb8215f372f52e48bb32426",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/vcpkg/0.2.15/download"],
        strip_prefix = "vcpkg-0.2.15",
        build_file = Label("@examples//sys/complex/3rdparty/crates:BUILD.vcpkg-0.2.15.bazel"),
    )
