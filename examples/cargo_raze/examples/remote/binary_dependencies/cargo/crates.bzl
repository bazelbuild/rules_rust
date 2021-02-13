"""
@generated
cargo-raze generated Bazel file.

DO NOT EDIT! Replaced on runs of cargo-raze
"""

load("@bazel_tools//tools/build_defs/repo:git.bzl", "new_git_repository")  # buildifier: disable=load
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")  # buildifier: disable=load
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")  # buildifier: disable=load

# EXPERIMENTAL -- MAY CHANGE AT ANY TIME: A mapping of package names to a set of normal dependencies for the Rust targets of that package.
_DEPENDENCIES = {
    "remote/binary_dependencies": {
        "ferris-says": "@remote_binary_dependencies__ferris_says__0_2_0//:ferris_says",
    },
}

# EXPERIMENTAL -- MAY CHANGE AT ANY TIME: A mapping of package names to a set of proc_macro dependencies for the Rust targets of that package.
_PROC_MACRO_DEPENDENCIES = {
    "remote/binary_dependencies": {
    },
}

# EXPERIMENTAL -- MAY CHANGE AT ANY TIME: A mapping of package names to a set of normal dev dependencies for the Rust targets of that package.
_DEV_DEPENDENCIES = {
    "remote/binary_dependencies": {
    },
}

# EXPERIMENTAL -- MAY CHANGE AT ANY TIME: A mapping of package names to a set of proc_macro dev dependencies for the Rust targets of that package.
_DEV_PROC_MACRO_DEPENDENCIES = {
    "remote/binary_dependencies": {
    },
}

def crate_deps(deps, package_name = None):
    """EXPERIMENTAL -- MAY CHANGE AT ANY TIME: Finds the fully qualified label of the requested crates for the package where this macro is called.

    WARNING: This macro is part of an expeirmental API and is subject to change.

    Args:
        deps (list): The desired list of crate targets.
        package_name (str, optional): The package name of the set of dependencies to look up.
            Defaults to `native.package_name()`.
    Returns:
        list: A list of labels to cargo-raze generated targets (str)
    """

    if not package_name:
        package_name = native.package_name()

    # Join both sets of dependencies
    dependencies = _flatten_dependency_maps([
        _DEPENDENCIES,
        _PROC_MACRO_DEPENDENCIES,
        _DEV_DEPENDENCIES,
        _DEV_PROC_MACRO_DEPENDENCIES,
    ])

    if not deps:
        return []

    missing_crates = []
    crate_targets = []
    for crate_target in deps:
        if crate_target not in dependencies[package_name]:
            missing_crates.append(crate_target)
        else:
            crate_targets.append(dependencies[package_name][crate_target])

    if missing_crates:
        fail("Could not find crates `{}` among dependencies of `{}`. Available dependencies were `{}`".format(
            missing_crates,
            package_name,
            dependencies[package_name],
        ))

    return crate_targets

def all_crate_deps(normal = False, normal_dev = False, proc_macro = False, proc_macro_dev = False, package_name = None):
    """EXPERIMENTAL -- MAY CHANGE AT ANY TIME: Finds the fully qualified label of all requested direct crate dependencies \
    for the package where this macro is called.

    If no parameters are set, all normal dependencies are returned. Setting any one flag will
    otherwise impact the contents of the returned list.

    Args:
        normal (bool, optional): If True, normal dependencies are included in the
            output list. Defaults to False.
        normal_dev (bool, optional): If True, normla dev dependencies will be
            included in the output list. Defaults to False.
        proc_macro (bool, optional): If True, proc_macro dependencies are included
            in the output list. Defaults to False.
        proc_macro_dev (bool, optional): If True, dev proc_macro dependencies are
            included in the output list. Defaults to False.
        package_name (str, optional): The package name of the set of dependencies to look up.
            Defaults to `native.package_name()`.

    Returns:
        list: A list of labels to cargo-raze generated targets (str)
    """

    if not package_name:
        package_name = native.package_name()

    # Determine the relevant maps to use
    all_dependency_maps = []
    if normal:
        all_dependency_maps.append(_DEPENDENCIES)
    if normal_dev:
        all_dependency_maps.append(_DEV_DEPENDENCIES)
    if proc_macro:
        all_dependency_maps.append(_PROC_MACRO_DEPENDENCIES)
    if proc_macro_dev:
        all_dependency_maps.append(_DEV_PROC_MACRO_DEPENDENCIES)

    # Default to always using normal dependencies
    if not all_dependency_maps:
        all_dependency_maps.append(_DEPENDENCIES)

    dependencies = _flatten_dependency_maps(all_dependency_maps)

    if not dependencies:
        return []

    return dependencies[package_name].values()

def _flatten_dependency_maps(all_dependency_maps):
    """Flatten a list of dependency maps into one dictionary.

    Dependency maps have the following structure:

    ```python
    DEPENDENCIES_MAP = {
        # The first key in the map is a Bazel package
        # name of the workspace this file is defined in.
        "package_name": {

            # An alias to a crate target.     # The label of the crate target the
            # Aliases are only crate names.   # alias refers to.
            "alias":                          "@full//:label",
        }
    }
    ```

    Args:
        all_dependency_maps (list): A list of dicts as described above

    Returns:
        dict: A dictionary as described above
    """
    dependencies = {}

    for dep_map in all_dependency_maps:
        for pkg_name in dep_map:
            if pkg_name not in dependencies:
                # Add a non-frozen dict to the collection of dependencies
                dependencies.setdefault(pkg_name, dict(dep_map[pkg_name].items()))
                continue

            duplicate_crate_aliases = [key for key in dependencies[pkg_name] if key in dep_map[pkg_name]]
            if duplicate_crate_aliases:
                fail("There should be no duplicate crate aliases: {}".format(duplicate_crate_aliases))

            dependencies[pkg_name].update(dep_map[pkg_name])

    return dependencies

def remote_binary_dependencies_fetch_remote_crates():
    """This function defines a collection of repos and should be called in a WORKSPACE file"""
    maybe(
        http_archive,
        name = "remote_binary_dependencies__addr2line__0_14_0",
        url = "https://crates.io/api/v1/crates/addr2line/0.14.0/download",
        type = "tar.gz",
        sha256 = "7c0929d69e78dd9bf5408269919fcbcaeb2e35e5d43e5815517cdc6a8e11a423",
        strip_prefix = "addr2line-0.14.0",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.addr2line-0.14.0.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__adler__0_2_3",
        url = "https://crates.io/api/v1/crates/adler/0.2.3/download",
        type = "tar.gz",
        sha256 = "ee2a4ec343196209d6594e19543ae87a39f96d5534d7174822a3ad825dd6ed7e",
        strip_prefix = "adler-0.2.3",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.adler-0.2.3.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__adler32__1_2_0",
        url = "https://crates.io/api/v1/crates/adler32/1.2.0/download",
        type = "tar.gz",
        sha256 = "aae1277d39aeec15cb388266ecc24b11c80469deae6067e17a1a7aa9e5c1f234",
        strip_prefix = "adler32-1.2.0",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.adler32-1.2.0.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__ansi_term__0_11_0",
        url = "https://crates.io/api/v1/crates/ansi_term/0.11.0/download",
        type = "tar.gz",
        sha256 = "ee49baf6cb617b853aa8d93bf420db2383fab46d314482ca2803b40d5fde979b",
        strip_prefix = "ansi_term-0.11.0",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.ansi_term-0.11.0.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__atty__0_2_14",
        url = "https://crates.io/api/v1/crates/atty/0.2.14/download",
        type = "tar.gz",
        sha256 = "d9b39be18770d11421cdb1b9947a45dd3f37e93092cbf377614828a319d5fee8",
        strip_prefix = "atty-0.2.14",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.atty-0.2.14.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__autocfg__1_0_1",
        url = "https://crates.io/api/v1/crates/autocfg/1.0.1/download",
        type = "tar.gz",
        sha256 = "cdb031dd78e28731d87d56cc8ffef4a8f36ca26c38fe2de700543e627f8a464a",
        strip_prefix = "autocfg-1.0.1",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.autocfg-1.0.1.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__backtrace__0_3_54",
        url = "https://crates.io/api/v1/crates/backtrace/0.3.54/download",
        type = "tar.gz",
        sha256 = "2baad346b2d4e94a24347adeee9c7a93f412ee94b9cc26e5b59dea23848e9f28",
        strip_prefix = "backtrace-0.3.54",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.backtrace-0.3.54.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__bitflags__1_2_1",
        url = "https://crates.io/api/v1/crates/bitflags/1.2.1/download",
        type = "tar.gz",
        sha256 = "cf1de2fe8c75bc145a2f577add951f8134889b4795d47466a54a5c846d691693",
        strip_prefix = "bitflags-1.2.1",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.bitflags-1.2.1.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__bytemuck__1_4_1",
        url = "https://crates.io/api/v1/crates/bytemuck/1.4.1/download",
        type = "tar.gz",
        sha256 = "41aa2ec95ca3b5c54cf73c91acf06d24f4495d5f1b1c12506ae3483d646177ac",
        strip_prefix = "bytemuck-1.4.1",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.bytemuck-1.4.1.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__byteorder__1_3_4",
        url = "https://crates.io/api/v1/crates/byteorder/1.3.4/download",
        type = "tar.gz",
        sha256 = "08c48aae112d48ed9f069b33538ea9e3e90aa263cfa3d1c24309612b1f7472de",
        strip_prefix = "byteorder-1.3.4",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.byteorder-1.3.4.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__cfg_if__0_1_10",
        url = "https://crates.io/api/v1/crates/cfg-if/0.1.10/download",
        type = "tar.gz",
        sha256 = "4785bdd1c96b2a846b2bd7cc02e86b6b3dbf14e7e53446c4f54c92a361040822",
        strip_prefix = "cfg-if-0.1.10",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.cfg-if-0.1.10.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__cfg_if__1_0_0",
        url = "https://crates.io/api/v1/crates/cfg-if/1.0.0/download",
        type = "tar.gz",
        sha256 = "baf1de4339761588bc0619e3cbc0120ee582ebb74b53b4efbf79117bd2da40fd",
        strip_prefix = "cfg-if-1.0.0",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.cfg-if-1.0.0.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__clap__2_33_3",
        url = "https://crates.io/api/v1/crates/clap/2.33.3/download",
        type = "tar.gz",
        sha256 = "37e58ac78573c40708d45522f0d80fa2f01cc4f9b4e2bf749807255454312002",
        strip_prefix = "clap-2.33.3",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.clap-2.33.3.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__console__0_13_0",
        url = "https://crates.io/api/v1/crates/console/0.13.0/download",
        type = "tar.gz",
        sha256 = "a50aab2529019abfabfa93f1e6c41ef392f91fbf179b347a7e96abb524884a08",
        strip_prefix = "console-0.13.0",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.console-0.13.0.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__crc32fast__1_2_1",
        url = "https://crates.io/api/v1/crates/crc32fast/1.2.1/download",
        type = "tar.gz",
        sha256 = "81156fece84ab6a9f2afdb109ce3ae577e42b1228441eded99bd77f627953b1a",
        strip_prefix = "crc32fast-1.2.1",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.crc32fast-1.2.1.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__crossbeam_utils__0_7_2",
        url = "https://crates.io/api/v1/crates/crossbeam-utils/0.7.2/download",
        type = "tar.gz",
        sha256 = "c3c7c73a2d1e9fc0886a08b93e98eb643461230d5f1925e4036204d5f2e261a8",
        strip_prefix = "crossbeam-utils-0.7.2",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.crossbeam-utils-0.7.2.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__deflate__0_8_6",
        url = "https://crates.io/api/v1/crates/deflate/0.8.6/download",
        type = "tar.gz",
        sha256 = "73770f8e1fe7d64df17ca66ad28994a0a623ea497fa69486e14984e715c5d174",
        strip_prefix = "deflate-0.8.6",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.deflate-0.8.6.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__encode_unicode__0_3_6",
        url = "https://crates.io/api/v1/crates/encode_unicode/0.3.6/download",
        type = "tar.gz",
        sha256 = "a357d28ed41a50f9c765dbfe56cbc04a64e53e5fc58ba79fbc34c10ef3df831f",
        strip_prefix = "encode_unicode-0.3.6",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.encode_unicode-0.3.6.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__error_chain__0_10_0",
        url = "https://crates.io/api/v1/crates/error-chain/0.10.0/download",
        type = "tar.gz",
        sha256 = "d9435d864e017c3c6afeac1654189b06cdb491cf2ff73dbf0d73b0f292f42ff8",
        strip_prefix = "error-chain-0.10.0",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.error-chain-0.10.0.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__ferris_says__0_2_0",
        url = "https://crates.io/api/v1/crates/ferris-says/0.2.0/download",
        type = "tar.gz",
        sha256 = "7f34f82e9a8b1533c027d018abd90b8687bf923be287b2617dfce4bea4ea3687",
        strip_prefix = "ferris-says-0.2.0",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.ferris-says-0.2.0.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__gimli__0_23_0",
        url = "https://crates.io/api/v1/crates/gimli/0.23.0/download",
        type = "tar.gz",
        sha256 = "f6503fe142514ca4799d4c26297c4248239fe8838d827db6bd6065c6ed29a6ce",
        strip_prefix = "gimli-0.23.0",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.gimli-0.23.0.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__heck__0_3_1",
        url = "https://crates.io/api/v1/crates/heck/0.3.1/download",
        type = "tar.gz",
        sha256 = "20564e78d53d2bb135c343b3f47714a56af2061f1c928fdb541dc7b9fdd94205",
        strip_prefix = "heck-0.3.1",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.heck-0.3.1.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__hermit_abi__0_1_17",
        url = "https://crates.io/api/v1/crates/hermit-abi/0.1.17/download",
        type = "tar.gz",
        sha256 = "5aca5565f760fb5b220e499d72710ed156fdb74e631659e99377d9ebfbd13ae8",
        strip_prefix = "hermit-abi-0.1.17",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.hermit-abi-0.1.17.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__image__0_23_10",
        url = "https://crates.io/api/v1/crates/image/0.23.10/download",
        type = "tar.gz",
        sha256 = "985fc06b1304d19c28d5c562ed78ef5316183f2b0053b46763a0b94862373c34",
        strip_prefix = "image-0.23.10",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.image-0.23.10.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__indicatif__0_14_0",
        url = "https://crates.io/api/v1/crates/indicatif/0.14.0/download",
        type = "tar.gz",
        sha256 = "49a68371cf417889c9d7f98235b7102ea7c54fc59bcbd22f3dea785be9d27e40",
        strip_prefix = "indicatif-0.14.0",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.indicatif-0.14.0.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__jpeg_decoder__0_1_20",
        url = "https://crates.io/api/v1/crates/jpeg-decoder/0.1.20/download",
        type = "tar.gz",
        sha256 = "cc797adac5f083b8ff0ca6f6294a999393d76e197c36488e2ef732c4715f6fa3",
        strip_prefix = "jpeg-decoder-0.1.20",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.jpeg-decoder-0.1.20.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__lazy_static__1_4_0",
        url = "https://crates.io/api/v1/crates/lazy_static/1.4.0/download",
        type = "tar.gz",
        sha256 = "e2abad23fbc42b3700f2f279844dc832adb2b2eb069b2df918f455c4e18cc646",
        strip_prefix = "lazy_static-1.4.0",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.lazy_static-1.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__libc__0_2_80",
        url = "https://crates.io/api/v1/crates/libc/0.2.80/download",
        type = "tar.gz",
        sha256 = "4d58d1b70b004888f764dfbf6a26a3b0342a1632d33968e4a179d8011c760614",
        strip_prefix = "libc-0.2.80",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.libc-0.2.80.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__miniz_oxide__0_3_7",
        url = "https://crates.io/api/v1/crates/miniz_oxide/0.3.7/download",
        type = "tar.gz",
        sha256 = "791daaae1ed6889560f8c4359194f56648355540573244a5448a83ba1ecc7435",
        strip_prefix = "miniz_oxide-0.3.7",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.miniz_oxide-0.3.7.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__miniz_oxide__0_4_3",
        url = "https://crates.io/api/v1/crates/miniz_oxide/0.4.3/download",
        type = "tar.gz",
        sha256 = "0f2d26ec3309788e423cfbf68ad1800f061638098d76a83681af979dc4eda19d",
        strip_prefix = "miniz_oxide-0.4.3",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.miniz_oxide-0.4.3.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__num_integer__0_1_44",
        url = "https://crates.io/api/v1/crates/num-integer/0.1.44/download",
        type = "tar.gz",
        sha256 = "d2cc698a63b549a70bc047073d2949cce27cd1c7b0a4a862d08a8031bc2801db",
        strip_prefix = "num-integer-0.1.44",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.num-integer-0.1.44.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__num_iter__0_1_42",
        url = "https://crates.io/api/v1/crates/num-iter/0.1.42/download",
        type = "tar.gz",
        sha256 = "b2021c8337a54d21aca0d59a92577a029af9431cb59b909b03252b9c164fad59",
        strip_prefix = "num-iter-0.1.42",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.num-iter-0.1.42.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__num_rational__0_3_1",
        url = "https://crates.io/api/v1/crates/num-rational/0.3.1/download",
        type = "tar.gz",
        sha256 = "e5fa6d5f418879385b213d905f7cf5bf4aa553d4c380f0152d1d4f2749186fa9",
        strip_prefix = "num-rational-0.3.1",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.num-rational-0.3.1.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__num_traits__0_2_14",
        url = "https://crates.io/api/v1/crates/num-traits/0.2.14/download",
        type = "tar.gz",
        sha256 = "9a64b1ec5cda2586e284722486d802acf1f7dbdc623e2bfc57e65ca1cd099290",
        strip_prefix = "num-traits-0.2.14",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.num-traits-0.2.14.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__num_cpus__1_13_0",
        url = "https://crates.io/api/v1/crates/num_cpus/1.13.0/download",
        type = "tar.gz",
        sha256 = "05499f3756671c15885fee9034446956fff3f243d6077b91e5767df161f766b3",
        strip_prefix = "num_cpus-1.13.0",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.num_cpus-1.13.0.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__number_prefix__0_3_0",
        url = "https://crates.io/api/v1/crates/number_prefix/0.3.0/download",
        type = "tar.gz",
        sha256 = "17b02fc0ff9a9e4b35b3342880f48e896ebf69f2967921fe8646bf5b7125956a",
        strip_prefix = "number_prefix-0.3.0",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.number_prefix-0.3.0.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__object__0_22_0",
        url = "https://crates.io/api/v1/crates/object/0.22.0/download",
        type = "tar.gz",
        sha256 = "8d3b63360ec3cb337817c2dbd47ab4a0f170d285d8e5a2064600f3def1402397",
        strip_prefix = "object-0.22.0",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.object-0.22.0.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__pdqselect__0_1_0",
        url = "https://crates.io/api/v1/crates/pdqselect/0.1.0/download",
        type = "tar.gz",
        sha256 = "4ec91767ecc0a0bbe558ce8c9da33c068066c57ecc8bb8477ef8c1ad3ef77c27",
        strip_prefix = "pdqselect-0.1.0",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.pdqselect-0.1.0.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__png__0_16_7",
        url = "https://crates.io/api/v1/crates/png/0.16.7/download",
        type = "tar.gz",
        sha256 = "dfe7f9f1c730833200b134370e1d5098964231af8450bce9b78ee3ab5278b970",
        strip_prefix = "png-0.16.7",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.png-0.16.7.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__ppv_lite86__0_2_9",
        url = "https://crates.io/api/v1/crates/ppv-lite86/0.2.9/download",
        type = "tar.gz",
        sha256 = "c36fa947111f5c62a733b652544dd0016a43ce89619538a8ef92724a6f501a20",
        strip_prefix = "ppv-lite86-0.2.9",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.ppv-lite86-0.2.9.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__proc_macro_error__1_0_4",
        url = "https://crates.io/api/v1/crates/proc-macro-error/1.0.4/download",
        type = "tar.gz",
        sha256 = "da25490ff9892aab3fcf7c36f08cfb902dd3e71ca0f9f9517bea02a73a5ce38c",
        strip_prefix = "proc-macro-error-1.0.4",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.proc-macro-error-1.0.4.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__proc_macro_error_attr__1_0_4",
        url = "https://crates.io/api/v1/crates/proc-macro-error-attr/1.0.4/download",
        type = "tar.gz",
        sha256 = "a1be40180e52ecc98ad80b184934baf3d0d29f979574e439af5a55274b35f869",
        strip_prefix = "proc-macro-error-attr-1.0.4",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.proc-macro-error-attr-1.0.4.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__proc_macro2__1_0_24",
        url = "https://crates.io/api/v1/crates/proc-macro2/1.0.24/download",
        type = "tar.gz",
        sha256 = "1e0704ee1a7e00d7bb417d0770ea303c1bccbabf0ef1667dae92b5967f5f8a71",
        strip_prefix = "proc-macro2-1.0.24",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.proc-macro2-1.0.24.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__quote__1_0_7",
        url = "https://crates.io/api/v1/crates/quote/1.0.7/download",
        type = "tar.gz",
        sha256 = "aa563d17ecb180e500da1cfd2b028310ac758de548efdd203e18f283af693f37",
        strip_prefix = "quote-1.0.7",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.quote-1.0.7.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__rand__0_7_3",
        url = "https://crates.io/api/v1/crates/rand/0.7.3/download",
        type = "tar.gz",
        sha256 = "6a6b1679d49b24bbfe0c803429aa1874472f50d9b363131f0e89fc356b544d03",
        strip_prefix = "rand-0.7.3",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.rand-0.7.3.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__rand_chacha__0_2_2",
        url = "https://crates.io/api/v1/crates/rand_chacha/0.2.2/download",
        type = "tar.gz",
        sha256 = "f4c8ed856279c9737206bf725bf36935d8666ead7aa69b52be55af369d193402",
        strip_prefix = "rand_chacha-0.2.2",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.rand_chacha-0.2.2.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__rand_core__0_5_1",
        url = "https://crates.io/api/v1/crates/rand_core/0.5.1/download",
        type = "tar.gz",
        sha256 = "90bde5296fc891b0cef12a6d03ddccc162ce7b2aff54160af9338f8d40df6d19",
        strip_prefix = "rand_core-0.5.1",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.rand_core-0.5.1.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__rand_hc__0_2_0",
        url = "https://crates.io/api/v1/crates/rand_hc/0.2.0/download",
        type = "tar.gz",
        sha256 = "ca3129af7b92a17112d59ad498c6f81eaf463253766b90396d39ea7a39d6613c",
        strip_prefix = "rand_hc-0.2.0",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.rand_hc-0.2.0.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__rand_pcg__0_2_1",
        url = "https://crates.io/api/v1/crates/rand_pcg/0.2.1/download",
        type = "tar.gz",
        sha256 = "16abd0c1b639e9eb4d7c50c0b8100b0d0f849be2349829c740fe8e6eb4816429",
        strip_prefix = "rand_pcg-0.2.1",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.rand_pcg-0.2.1.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__regex__1_4_1",
        url = "https://crates.io/api/v1/crates/regex/1.4.1/download",
        type = "tar.gz",
        sha256 = "8963b85b8ce3074fecffde43b4b0dded83ce2f367dc8d363afc56679f3ee820b",
        strip_prefix = "regex-1.4.1",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.regex-1.4.1.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__regex_syntax__0_6_20",
        url = "https://crates.io/api/v1/crates/regex-syntax/0.6.20/download",
        type = "tar.gz",
        sha256 = "8cab7a364d15cde1e505267766a2d3c4e22a843e1a601f0fa7564c0f82ced11c",
        strip_prefix = "regex-syntax-0.6.20",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.regex-syntax-0.6.20.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__rstar__0_7_1",
        url = "https://crates.io/api/v1/crates/rstar/0.7.1/download",
        type = "tar.gz",
        sha256 = "0650eaaa56cbd1726fd671150fce8ac6ed9d9a25d1624430d7ee9d196052f6b6",
        strip_prefix = "rstar-0.7.1",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.rstar-0.7.1.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__rustc_demangle__0_1_18",
        url = "https://crates.io/api/v1/crates/rustc-demangle/0.1.18/download",
        type = "tar.gz",
        sha256 = "6e3bad0ee36814ca07d7968269dd4b7ec89ec2da10c4bb613928d3077083c232",
        strip_prefix = "rustc-demangle-0.1.18",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.rustc-demangle-0.1.18.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__smallvec__0_4_5",
        url = "https://crates.io/api/v1/crates/smallvec/0.4.5/download",
        type = "tar.gz",
        sha256 = "f90c5e5fe535e48807ab94fc611d323935f39d4660c52b26b96446a7b33aef10",
        strip_prefix = "smallvec-0.4.5",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.smallvec-0.4.5.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__strsim__0_8_0",
        url = "https://crates.io/api/v1/crates/strsim/0.8.0/download",
        type = "tar.gz",
        sha256 = "8ea5119cdb4c55b55d432abb513a0429384878c15dde60cc77b1c99de1a95a6a",
        strip_prefix = "strsim-0.8.0",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.strsim-0.8.0.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__structopt__0_3_20",
        url = "https://crates.io/api/v1/crates/structopt/0.3.20/download",
        type = "tar.gz",
        sha256 = "126d630294ec449fae0b16f964e35bf3c74f940da9dca17ee9b905f7b3112eb8",
        strip_prefix = "structopt-0.3.20",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.structopt-0.3.20.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__structopt_derive__0_4_13",
        url = "https://crates.io/api/v1/crates/structopt-derive/0.4.13/download",
        type = "tar.gz",
        sha256 = "65e51c492f9e23a220534971ff5afc14037289de430e3c83f9daf6a1b6ae91e8",
        strip_prefix = "structopt-derive-0.4.13",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.structopt-derive-0.4.13.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__syn__1_0_48",
        url = "https://crates.io/api/v1/crates/syn/1.0.48/download",
        type = "tar.gz",
        sha256 = "cc371affeffc477f42a221a1e4297aedcea33d47d19b61455588bd9d8f6b19ac",
        strip_prefix = "syn-1.0.48",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.syn-1.0.48.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__terminal_size__0_1_13",
        url = "https://crates.io/api/v1/crates/terminal_size/0.1.13/download",
        type = "tar.gz",
        sha256 = "9a14cd9f8c72704232f0bfc8455c0e861f0ad4eb60cc9ec8a170e231414c1e13",
        strip_prefix = "terminal_size-0.1.13",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.terminal_size-0.1.13.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__texture_synthesis__0_8_0",
        url = "https://crates.io/api/v1/crates/texture-synthesis/0.8.0/download",
        type = "tar.gz",
        sha256 = "2ff7e9b61c0c11d66b78f7474d69217a4e0fc5b758ff33b67c6dc0b87b126191",
        strip_prefix = "texture-synthesis-0.8.0",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.texture-synthesis-0.8.0.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__texture_synthesis_cli__0_8_0",
        url = "https://crates.io/api/v1/crates/texture-synthesis-cli/0.8.0/download",
        type = "tar.gz",
        sha256 = "4d0a65298b735ba486081633e90469182d7c0ca59018fec1e81383bde852be2e",
        strip_prefix = "texture-synthesis-cli-0.8.0",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.texture-synthesis-cli-0.8.0.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__textwrap__0_11_0",
        url = "https://crates.io/api/v1/crates/textwrap/0.11.0/download",
        type = "tar.gz",
        sha256 = "d326610f408c7a4eb6f51c37c330e496b08506c9457c9d34287ecc38809fb060",
        strip_prefix = "textwrap-0.11.0",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.textwrap-0.11.0.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__unicode_segmentation__1_6_0",
        url = "https://crates.io/api/v1/crates/unicode-segmentation/1.6.0/download",
        type = "tar.gz",
        sha256 = "e83e153d1053cbb5a118eeff7fd5be06ed99153f00dbcd8ae310c5fb2b22edc0",
        strip_prefix = "unicode-segmentation-1.6.0",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.unicode-segmentation-1.6.0.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__unicode_width__0_1_8",
        url = "https://crates.io/api/v1/crates/unicode-width/0.1.8/download",
        type = "tar.gz",
        sha256 = "9337591893a19b88d8d87f2cec1e73fad5cdfd10e5a6f349f498ad6ea2ffb1e3",
        strip_prefix = "unicode-width-0.1.8",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.unicode-width-0.1.8.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__unicode_xid__0_2_1",
        url = "https://crates.io/api/v1/crates/unicode-xid/0.2.1/download",
        type = "tar.gz",
        sha256 = "f7fe0bb3479651439c9112f72b6c505038574c9fbb575ed1bf3b797fa39dd564",
        strip_prefix = "unicode-xid-0.2.1",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.unicode-xid-0.2.1.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__vec_map__0_8_2",
        url = "https://crates.io/api/v1/crates/vec_map/0.8.2/download",
        type = "tar.gz",
        sha256 = "f1bddf1187be692e79c5ffeab891132dfb0f236ed36a43c7ed39f1165ee20191",
        strip_prefix = "vec_map-0.8.2",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.vec_map-0.8.2.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__version_check__0_9_2",
        url = "https://crates.io/api/v1/crates/version_check/0.9.2/download",
        type = "tar.gz",
        sha256 = "b5a972e5669d67ba988ce3dc826706fb0a8b01471c088cb0b6110b805cc36aed",
        strip_prefix = "version_check-0.9.2",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.version_check-0.9.2.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__winapi__0_3_9",
        url = "https://crates.io/api/v1/crates/winapi/0.3.9/download",
        type = "tar.gz",
        sha256 = "5c839a674fcd7a98952e593242ea400abe93992746761e38641405d28b00f419",
        strip_prefix = "winapi-0.3.9",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.winapi-0.3.9.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__winapi_i686_pc_windows_gnu__0_4_0",
        url = "https://crates.io/api/v1/crates/winapi-i686-pc-windows-gnu/0.4.0/download",
        type = "tar.gz",
        sha256 = "ac3b87c63620426dd9b991e5ce0329eff545bccbbb34f3be09ff6fb6ab51b7b6",
        strip_prefix = "winapi-i686-pc-windows-gnu-0.4.0",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.winapi-i686-pc-windows-gnu-0.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__winapi_util__0_1_5",
        url = "https://crates.io/api/v1/crates/winapi-util/0.1.5/download",
        type = "tar.gz",
        sha256 = "70ec6ce85bb158151cae5e5c87f95a8e97d2c0c4b001223f33a334e3ce5de178",
        strip_prefix = "winapi-util-0.1.5",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.winapi-util-0.1.5.bazel"),
    )

    maybe(
        http_archive,
        name = "remote_binary_dependencies__winapi_x86_64_pc_windows_gnu__0_4_0",
        url = "https://crates.io/api/v1/crates/winapi-x86_64-pc-windows-gnu/0.4.0/download",
        type = "tar.gz",
        sha256 = "712e227841d057c1ee1cd2fb22fa7e5a5461ae8e48fa2ca79ec42cfc1931183f",
        strip_prefix = "winapi-x86_64-pc-windows-gnu-0.4.0",
        build_file = Label("//remote/binary_dependencies/cargo/remote:BUILD.winapi-x86_64-pc-windows-gnu-0.4.0.bazel"),
    )
