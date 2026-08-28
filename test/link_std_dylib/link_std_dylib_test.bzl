"""Analysis tests for experimental_link_std_dylib flag"""

load("@rules_cc//cc:defs.bzl", "CcInfo")
load("@rules_rust//rust:defs.bzl", "rust_binary", "rust_dylib_library", "rust_library", "rust_test")
load("@rules_testing//lib:analysis_test.bzl", "analysis_test", "test_suite")

# buildifier: disable=bzl-visibility
load("//rust/private:utils.bzl", "is_std_dylib")

def _test_prefer_dynamic_impl(env, targets):
    env.expect.that_action(targets.default_target.actions[0]) \
        .contains_none_of_flag_values([
        ("--codegen", "prefer-dynamic"),
    ])

    # Make sure the target with std dylib linkage has the correct codegen flag
    env.expect.that_action(targets.target_with_std_dylib.actions[0]) \
        .contains_flag_values([
        ("--codegen", "prefer-dynamic"),
    ])

def _test_rust_binary(name):
    rust_binary(
        name = name + "_rust_binary",
        srcs = ["main.rs"],
        edition = "2021",
        tags = ["manual"],
    )

    analysis_test(
        name = name,
        impl = _test_prefer_dynamic_impl,
        targets = {
            "default_target": name + "_rust_binary",
            "target_with_std_dylib": name + "_rust_binary",
        },
        attrs = {
            "target_with_std_dylib": {
                "@config_settings": {
                    str(Label("@rules_rust//rust/settings:experimental_link_std_dylib")): True,
                },
            },
        },
    )

def _test_rust_binary_with_attr_dylib(name):
    rust_binary(
        name = name + "_rust_binary",
        srcs = ["main.rs"],
        edition = "2021",
        tags = ["manual"],
    )

    rust_binary(
        name = name + "_dylib_rust_binary",
        srcs = ["main.rs"],
        edition = "2021",
        tags = ["manual"],
        link_std_dylib = True,
    )

    analysis_test(
        name = name,
        impl = _test_prefer_dynamic_impl,
        targets = {
            "default_target": name + "_rust_binary",
            "target_with_std_dylib": name + "_dylib_rust_binary",
        },
    )

def _test_rust_dylib_with_attr(name):
    rust_dylib_library(
        name = name + "_rust_dylib_no_std_dylib",
        srcs = ["lib.rs"],
        edition = "2021",
        tags = ["manual"],
        link_std_dylib = False,
    )

    rust_dylib_library(
        name = name + "_rust_dylib_link_std",
        srcs = ["lib.rs"],
        edition = "2021",
        tags = ["manual"],
        link_std_dylib = True,
    )

    analysis_test(
        name = name,
        impl = _test_prefer_dynamic_impl,
        targets = {
            "default_target": name + "_rust_dylib_no_std_dylib",
            "target_with_std_dylib": name + "_rust_dylib_link_std",
        },
    )

def _export_static_stdlibs_in_cc_info(target):
    linker_inputs = target[CcInfo].linking_context.linker_inputs
    for linker_input in linker_inputs.to_list():
        for library in linker_input.libraries:
            if hasattr(library, "pic_static_library") and library.pic_static_library != None:
                basename = library.pic_static_library.basename
                if basename.startswith("libstd") and basename.endswith(".a"):
                    return True
    return False

def _export_libstd_dylib_in_cc_info(target):
    linker_inputs = target[CcInfo].linking_context.linker_inputs
    for linker_input in linker_inputs.to_list():
        for library in linker_input.libraries:
            if hasattr(library, "dynamic_library") and library.dynamic_library != None:
                if is_std_dylib(library.dynamic_library):
                    return True
    return False

def _test_rust_library_impl(env, targets):
    # By default, rust_library exports static stdlibs to downstream shared
    # and binary targets to statically link
    env.expect \
        .that_bool(_export_static_stdlibs_in_cc_info(targets.default_rlib)) \
        .equals(True)
    env.expect \
        .that_bool(_export_libstd_dylib_in_cc_info(targets.default_rlib)) \
        .equals(False)

    # With @rules_rust//rust/settings:experimental_link_std_dylib
    # rust_library exports dylib std and does not export static stdlibs to
    # downstream shared and binary targets to dynamically link
    env.expect \
        .that_bool(_export_static_stdlibs_in_cc_info(targets.rlib_with_std_dylib)) \
        .equals(False)
    env.expect \
        .that_bool(_export_libstd_dylib_in_cc_info(targets.rlib_with_std_dylib)) \
        .equals(True)

def _test_rust_library(name):
    rust_library(
        name = name + "_rust_library",
        srcs = ["lib.rs"],
        edition = "2021",
        tags = ["manual"],
    )

    analysis_test(
        name = name,
        impl = _test_rust_library_impl,
        targets = {
            "default_rlib": name + "_rust_library",
            "rlib_with_std_dylib": name + "_rust_library",
        },
        attrs = {
            "rlib_with_std_dylib": {
                "@config_settings": {
                    str(Label("@rules_rust//rust/settings:experimental_link_std_dylib")): True,
                },
            },
        },
    )

def _test_rust_test_with_attr(name):
    rust_test(
        name = name + "_rust_test",
        srcs = ["main.rs"],
        edition = "2021",
        tags = ["manual"],
    )

    rust_test(
        name = name + "_rust_test_link_std",
        srcs = ["main.rs"],
        edition = "2021",
        tags = ["manual"],
        link_std_dylib = True,
    )

    analysis_test(
        name = name,
        impl = _test_prefer_dynamic_impl,
        targets = {
            "default_target": name + "_rust_test",
            "target_with_std_dylib": name + "_rust_test_link_std",
        },
    )

def _has_runfiles_rpath(argv, binary_basename):
    """Check that at least one link arg contains a path into the runfiles tree."""
    runfiles_marker = binary_basename + ".runfiles/"
    for arg in argv:
        if "link-arg=" in arg and runfiles_marker in arg:
            return True
    return False

def _has_short_path_rpath(argv):
    """Check that at least one link arg uses short-path-relative navigation (for inside-runfiles execution)."""
    for arg in argv:
        if "link-arg=" in arg and "../" in arg and ".runfiles" not in arg:
            return True
    return False

def _test_runfiles_rpath_impl(env, targets):
    action = targets.binary_with_dylib_dep.actions[0]
    binary_basename = targets.binary_with_dylib_dep.label.name

    # Verify runfiles-from-outside RPATHs are present.
    env.expect \
        .that_bool(_has_runfiles_rpath(action.argv, binary_basename)) \
        .equals(True)

def _not_windows():
    return select({
        "@platforms//os:linux": [],
        "@platforms//os:macos": [],
        "//conditions:default": ["@platforms//:incompatible"],
    })

def _test_runfiles_rpath(name):
    rust_dylib_library(
        name = name + "_rust_dylib",
        srcs = ["lib.rs"],
        edition = "2021",
        tags = ["manual"],
        target_compatible_with = _not_windows(),
    )

    rust_binary(
        name = name + "_rust_binary",
        srcs = ["main.rs"],
        deps = [name + "_rust_dylib"],
        edition = "2021",
        tags = ["manual"],
        target_compatible_with = _not_windows(),
    )

    analysis_test(
        name = name,
        impl = _test_runfiles_rpath_impl,
        targets = {
            "binary_with_dylib_dep": name + "_rust_binary",
        },
    )

def _test_std_dylib_runfiles_rpath_impl(env, targets):
    action = targets.binary_with_std_dylib.actions[0]
    binary_basename = targets.binary_with_std_dylib.label.name

    # Verify runfiles-from-outside RPATHs for stdlib are present.
    env.expect \
        .that_bool(_has_runfiles_rpath(action.argv, binary_basename)) \
        .equals(True)

    # Verify short-path RPATHs for stdlib are present.
    # The stdlib is from an external repo, so its short-path RPATH uses "../".
    env.expect \
        .that_bool(_has_short_path_rpath(action.argv)) \
        .equals(True)

def _test_std_dylib_runfiles_rpath(name):
    rust_binary(
        name = name + "_rust_binary",
        srcs = ["main.rs"],
        edition = "2021",
        link_std_dylib = True,
        tags = ["manual"],
        target_compatible_with = _not_windows(),
    )

    analysis_test(
        name = name,
        impl = _test_std_dylib_runfiles_rpath_impl,
        targets = {
            "binary_with_std_dylib": name + "_rust_binary",
        },
    )

def _has_dylib_symlink_next_to_binary(target, dylib_dep):
    """Check that a dylib output exists next to the binary in DefaultInfo.files."""
    dep_name = dylib_dep.label.name
    for f in target[DefaultInfo].files.to_list():
        if dep_name in f.basename and (f.basename.endswith(".dll") or f.basename.endswith(".so") or f.basename.endswith(".dylib")):
            return True
    return False

def _test_windows_dylib_symlink_impl(env, targets):
    env.expect \
        .that_bool(_has_dylib_symlink_next_to_binary(
        targets.binary_with_dylib_dep,
        targets.dylib_dep,
    )) \
        .equals(True)

def _test_windows_dylib_symlink(name):
    rust_binary(
        name = name + "_rust_binary",
        srcs = ["main.rs"],
        deps = ["//test/rust_dylib:rust_dylib_lib"],
        edition = "2021",
        tags = ["manual"],
        target_compatible_with = ["@platforms//os:windows"],
    )

    analysis_test(
        name = name,
        impl = _test_windows_dylib_symlink_impl,
        targets = {
            "binary_with_dylib_dep": name + "_rust_binary",
            "dylib_dep": "//test/rust_dylib:rust_dylib_lib",
        },
    )

def link_std_dylib_test_suite(name):
    test_suite(
        name = name,
        tests = [
            _test_rust_binary,
            _test_rust_library,
            _test_rust_binary_with_attr_dylib,
            _test_rust_dylib_with_attr,
            _test_rust_test_with_attr,
            _test_runfiles_rpath,
            _test_std_dylib_runfiles_rpath,
            _test_windows_dylib_symlink,
        ],
    )
