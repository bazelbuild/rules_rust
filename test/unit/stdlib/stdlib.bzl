"""Unittest to verify contents and ordering of rust stdlib in rust_library() CcInfo"""

load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load("@rules_testing//lib:analysis_test.bzl", "analysis_test", "test_suite")
load("@rules_testing//lib:util.bzl", "util")
load("//rust:defs.bzl", "rust_binary", "rust_common", "rust_library", "rust_test")
load("//rust:toolchain.bzl", "rust_stdlib_filegroup")

def _is_crate_basename(basename, crate_name):
    return basename.startswith(("lib" + crate_name + "-", "lib" + crate_name + "."))

def _categorize_library(name):
    """Given an rlib name, guess if it's test, getopts, unicode_width, std, core, or alloc."""
    if _is_crate_basename(name, "test"):
        return "test"
    if _is_crate_basename(name, "getopts"):
        return "getopts"
    if _is_crate_basename(name, "unicode_width"):
        return "unicode_width"
    if "std" in name:
        return "std"
    if "core" in name:
        return "core"
    if "alloc" in name:
        return "alloc"
    if "compiler_builtins" in name:
        return "compiler_builtins"
    return "other"

def _dedup_preserving_order(list):
    """Given a list, deduplicate its elements preserving order."""
    r = []
    seen = {}
    for e in list:
        if e in seen:
            continue
        seen[e] = 1
        r.append(e)
    return r

def _stdlibs(tut):
    """Given a target, return the list of its standard rust libraries."""
    libs = [
        lib.static_library or lib.pic_static_library
        for li in tut[CcInfo].linking_context.linker_inputs.to_list()
        for lib in li.libraries
    ]
    stdlibs = [lib for lib in libs if (lib and tut.label.name not in lib.basename)]
    return stdlibs

def _libstd_ordering_test_impl(env, target):
    stdlibs = _stdlibs(target)
    stdlib_categories = [_categorize_library(lib.basename) for lib in stdlibs]
    set_to_check = _dedup_preserving_order([lib for lib in stdlib_categories if lib != "other"])
    env.expect.that_collection(set_to_check).contains_exactly([
        "std",
        "core",
        "compiler_builtins",
        "alloc",
    ]).in_order()

    has_proc_macro = [lib for lib in stdlibs if _is_crate_basename(lib.basename, "proc_macro")]
    env.expect.that_bool(len(has_proc_macro) > 0).equals(True)

def _libstd_ordering_test(name):
    util.helper_target(
        rust_library,
        name = name + "_some_rlib",
        srcs = ["some_rlib.rs"],
        edition = "2018",
    )

    analysis_test(
        name = name,
        target = ":" + name + "_some_rlib",
        impl = _libstd_ordering_test_impl,
    )

def _libstd_panic_test_impl(env, target):
    # The libraries panic_unwind and panic_abort are alternatives.
    # Check that they don't occur together.
    stdlibs = _stdlibs(target)
    has_panic_unwind = [lib for lib in stdlibs if "panic_unwind" in lib.basename]
    if has_panic_unwind:
        has_panic_abort = [lib for lib in stdlibs if "panic_abort" in lib.basename]
        env.expect.that_collection(has_panic_abort).contains_exactly([])

def _libstd_panic_test(name):
    util.helper_target(
        rust_library,
        name = name + "_some_rlib",
        srcs = ["some_rlib.rs"],
        edition = "2018",
    )

    analysis_test(
        name = name,
        target = ":" + name + "_some_rlib",
        impl = _libstd_panic_test_impl,
    )

def _make_mock_rlibs(prefix, filenames):
    targets = []
    for i, filename in enumerate(filenames):
        target_name = "{}_rlib_{}".format(prefix, i)
        util.helper_target(
            write_file,
            name = target_name,
            out = "{}/{}".format(prefix, filename),
            content = [""],
        )
        targets.append(":" + target_name)
    return targets

def _stdlib_filegroup_partitioning_test_impl(env, targets):
    hashed_info = targets.hashed[rust_common.stdlib_info]
    env.expect.that_collection([f.basename for f in hashed_info.test_files]).contains_exactly([
        "libtest-33333333.a",
        "libgetopts-22222222.a",
        "libunicode_width-11111111.a",
    ]).in_order()
    env.expect.that_collection([f.basename for f in hashed_info.between_core_and_std_files]).contains_exactly([
        "libproc_macro-88888888.a",
        "librustc_literal_escaper-99999999.a",
        "libmy_test_helper-aaaaaaaa.a",
        "libtest_utils-bbbbbbbb.a",
    ])

    unhashed_info = targets.unhashed[rust_common.stdlib_info]
    env.expect.that_collection([f.basename for f in unhashed_info.test_files]).contains_exactly([
        "libtest.a",
        "libgetopts.a",
        "libunicode_width.a",
    ]).in_order()
    env.expect.that_collection([f.basename for f in unhashed_info.between_core_and_std_files]).contains_exactly([])

def _stdlib_filegroup_partitioning_test(name):
    # Deliberately provide test crates out of topological order and include
    # similarly-named crates to verify exact prefix matching.
    hashed_srcs = _make_mock_rlibs(
        name + "_hashed",
        [
            "libunicode_width-11111111.rlib",
            "libgetopts-22222222.rlib",
            "libtest-33333333.rlib",
            "libstd-44444444.rlib",
            "libcore-55555555.rlib",
            "liballoc-66666666.rlib",
            "libcompiler_builtins-77777777.rlib",
            "libproc_macro-88888888.rlib",
            "librustc_literal_escaper-99999999.rlib",
            "libmy_test_helper-aaaaaaaa.rlib",
            "libtest_utils-bbbbbbbb.rlib",
        ],
    )
    util.helper_target(
        rust_stdlib_filegroup,
        name = name + "_hashed",
        srcs = hashed_srcs,
    )

    unhashed_srcs = _make_mock_rlibs(
        name + "_unhashed",
        [
            "unicode_width.rlib",
            "getopts.rlib",
            "test.rlib",
            "std.rlib",
        ],
    )
    util.helper_target(
        rust_stdlib_filegroup,
        name = name + "_unhashed",
        srcs = unhashed_srcs,
    )

    analysis_test(
        name = name,
        targets = {
            "hashed": ":" + name + "_hashed",
            "unhashed": ":" + name + "_unhashed",
        },
        impl = _stdlib_filegroup_partitioning_test_impl,
    )

def _assert_cpp_link_test_crates(env, target, expect_test, dep_lib_name = None):
    link_actions = [a for a in target.actions if a.mnemonic == "CppLink"]
    if len(link_actions) != 1:
        fail("Expected exactly 1 CppLink action for {}, got {}".format(target.label, len(link_actions)))
    link_action = link_actions[0]

    basenames = [f.basename for f in link_action.inputs.to_list() if f.basename.endswith(".a")]
    has_std = [b for b in basenames if _is_crate_basename(b, "std")]
    env.expect.that_bool(len(has_std) > 0).equals(True)

    if not expect_test:
        for crate_name in ("test", "getopts", "unicode_width"):
            matches = [b for b in basenames if _is_crate_basename(b, crate_name)]
            env.expect.that_collection(matches).contains_exactly([])
        return

    for crate_name in ("test", "getopts"):
        matches = [b for b in basenames if _is_crate_basename(b, crate_name)]
        env.expect.that_bool(len(matches) > 0).equals(True)

    # Verify linker argv ordering when libraries are passed directly in argv.
    argv_categories = []
    for arg in link_action.argv:
        if not arg.endswith(".a"):
            continue
        basename = arg.replace("\\", "/").rpartition("/")[2]
        if dep_lib_name and _is_crate_basename(basename, dep_lib_name):
            argv_categories.append("dep")
        else:
            argv_categories.append(_categorize_library(basename))
    argv_categories = _dedup_preserving_order([c for c in argv_categories if c != "other"])
    if argv_categories:
        expected_order = (["dep"] if dep_lib_name else []) + ["test", "getopts"]
        if "unicode_width" in argv_categories:
            expected_order.append("unicode_width")
        expected_order.extend(["std", "core"])
        env.expect.that_collection(argv_categories).contains_at_least(expected_order).in_order()

def _cc_common_link_libtest_test_impl(env, targets):
    dep_lib_name = targets.lib[rust_common.crate_info].name
    _assert_cpp_link_test_crates(env, targets.plain_bin, expect_test = False)
    _assert_cpp_link_test_crates(env, targets.test_flag_bin, expect_test = True, dep_lib_name = dep_lib_name)
    _assert_cpp_link_test_crates(env, targets.test_with_deps, expect_test = True, dep_lib_name = dep_lib_name)
    _assert_cpp_link_test_crates(env, targets.test_with_crate, expect_test = True)
    _assert_cpp_link_test_crates(env, targets.test_no_harness, expect_test = True, dep_lib_name = dep_lib_name)

def _cc_common_link_libtest_test(name):
    util.helper_target(
        rust_library,
        name = name + "_lib",
        srcs = ["some_rlib.rs"],
        edition = "2021",
    )
    util.helper_target(
        rust_binary,
        name = name + "_plain_bin",
        srcs = ["some_rlib.rs"],
        edition = "2021",
        deps = [":" + name + "_lib"],
    )
    util.helper_target(
        rust_binary,
        name = name + "_test_flag_bin",
        srcs = ["some_rlib.rs"],
        edition = "2021",
        rustc_flags = ["--test"],
        deps = [":" + name + "_lib"],
    )
    util.helper_target(
        rust_test,
        name = name + "_test_with_deps",
        srcs = ["some_rlib.rs"],
        edition = "2021",
        deps = [":" + name + "_lib"],
    )
    util.helper_target(
        rust_test,
        name = name + "_test_with_crate",
        crate = ":" + name + "_lib",
        edition = "2021",
    )
    util.helper_target(
        rust_test,
        name = name + "_test_no_harness",
        srcs = ["some_rlib.rs"],
        edition = "2021",
        use_libtest_harness = False,
        deps = [":" + name + "_lib"],
    )

    analysis_test(
        name = name,
        targets = {
            "lib": ":" + name + "_lib",
            "plain_bin": ":" + name + "_plain_bin",
            "test_flag_bin": ":" + name + "_test_flag_bin",
            "test_no_harness": ":" + name + "_test_no_harness",
            "test_with_crate": ":" + name + "_test_with_crate",
            "test_with_deps": ":" + name + "_test_with_deps",
        },
        config_settings = {
            str(Label("//rust/settings:experimental_use_cc_common_link")): True,
        },
        impl = _cc_common_link_libtest_test_impl,
    )

def _cc_common_link_per_crate_test_flag_test_impl(env, target):
    _assert_cpp_link_test_crates(env, target, expect_test = True)

def _cc_common_link_per_crate_test_flag_test(name):
    bin_name = name + "_bin"
    util.helper_target(
        rust_binary,
        name = bin_name,
        srcs = ["some_rlib.rs"],
        edition = "2021",
    )

    analysis_test(
        name = name,
        target = ":" + bin_name,
        config_settings = {
            str(Label("//rust/settings:experimental_use_cc_common_link")): True,
            str(Label("//rust/settings:per_crate_rustc_flag")): [
                "//{}:{}@--test".format(native.package_name(), bin_name),
            ],
        },
        impl = _cc_common_link_per_crate_test_flag_test_impl,
    )

def stdlib_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name: Name of the macro.
    """
    test_suite(
        name = name,
        tests = [
            _libstd_ordering_test,
            _libstd_panic_test,
            _stdlib_filegroup_partitioning_test,
            _cc_common_link_libtest_test,
            _cc_common_link_per_crate_test_flag_test,
        ],
    )
