"""Unittests for rust rules."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load(
    "@bazel_skylib//rules:common_settings.bzl",
    "BuildSettingInfo",
)
load("@rules_cc//cc:defs.bzl", "cc_import", "cc_library")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load("@rules_testing//lib:analysis_test.bzl", "analysis_test", "test_suite")
load("@rules_testing//lib:truth.bzl", "subjects")
load("//rust:defs.bzl", "rust_binary", "rust_common", "rust_library", "rust_proc_macro", "rust_shared_library", "rust_static_library")
load("//rust/private:rustc.bzl", "establish_cc_info")  # buildifier: disable=bzl-visibility

# Helper for fluent asserts involving File struct fields that might be None.
def _optional_file_subject(file, *, meta):
    def is_not_none():
        if file == None:
            meta.add_failure("expected: a File (non-None)", "actual: None")
            return None
        return subjects.file(file, meta = meta)

    return struct(
        is_none = lambda: subjects.file(file, meta = meta).equals(None),
        is_not_none = is_not_none,
    )

def _expect_that_library_to_link(env, library_to_link):
    return env.expect.that_struct(
        library_to_link,
        expr = "library_to_link",
        attrs = dict(
            alwayslink = subjects.bool,
            lto_bitcode_files = subjects.collection,
            pic_lto_bitcode_files = subjects.collection,
            objects = subjects.collection,
            pic_objects = subjects.collection,
            dynamic_library = _optional_file_subject,
            interface_library = _optional_file_subject,
            resolved_symlink_dynamic_library = _optional_file_subject,
            resolved_symlink_interface_library = _optional_file_subject,
            static_library = _optional_file_subject,
            pic_static_library = _optional_file_subject,
        ),
    )

def _is_windows(ctx):
    return ctx.target_platform_has_constraint(ctx.attr._windows[platform_common.ConstraintValueInfo])

def _assert_cc_info_has_library_to_link(env, target, type, ccinfo_count):
    env.expect.that_target(target).has_provider(CcInfo)
    cc_info = target[CcInfo]

    linker_inputs = cc_info.linking_context.linker_inputs.to_list()
    env.expect.that_collection(
        linker_inputs,
        expr = "cc_info.linking_context.linker_inputs.to_list()",
    ).has_size(ccinfo_count)

    library_to_link = linker_inputs[0].libraries[0]
    expect_that_library_to_link = _expect_that_library_to_link(env, library_to_link)
    expect_that_library_to_link.alwayslink().equals(False)

    # TODO: change `has_size(0)` to `is_empty` when the latter is released.
    expect_that_library_to_link.lto_bitcode_files().has_size(0)
    expect_that_library_to_link.pic_lto_bitcode_files().has_size(0)

    expect_that_library_to_link.objects().has_size(0)
    expect_that_library_to_link.pic_objects().has_size(0)

    if type == "cdylib":
        expect_that_library_to_link.dynamic_library().is_not_none()
        if _is_windows(env.ctx):
            expect_that_library_to_link.interface_library().is_not_none()
            expect_that_library_to_link.resolved_symlink_dynamic_library().is_none()
        else:
            expect_that_library_to_link.interface_library().is_none()
            expect_that_library_to_link.resolved_symlink_dynamic_library().is_not_none()
        expect_that_library_to_link.resolved_symlink_interface_library().is_none()
        expect_that_library_to_link.static_library().is_none()
        expect_that_library_to_link.pic_static_library().is_none()
    else:
        expect_that_library_to_link.dynamic_library().is_none()
        expect_that_library_to_link.interface_library().is_none()
        expect_that_library_to_link.resolved_symlink_dynamic_library().is_none()
        expect_that_library_to_link.resolved_symlink_interface_library().is_none()
        if library_to_link.static_library != None:
            if type in ("rlib", "lib"):
                # TODO: change to something like
                # expect_that_lib.static_library().is_not_none().basename().starts_with("lib" + target.label.name)
                # when `StrSubject.starts_with` is released.
                env.expect.that_bool(
                    library_to_link.static_library.basename.startswith("lib" + target.label.name),
                    expr = 'library_to_link.pic_static_library.basename.startswith("lib" + target.label.name)',
                ).equals(True)
            expect_that_library_to_link.pic_static_library().is_none()
        else:
            expect_that_library_to_link.pic_static_library().is_not_none()
            if type in ("rlib", "lib"):
                # TODO: change to something like
                # expect_that_lib.pic_static_library().is_not_none().basename().starts_with("lib" + target.label.name)
                # when `StrSubject.starts_with` is released.
                env.expect.that_bool(
                    library_to_link.pic_static_library.basename.startswith("lib" + target.label.name),
                    expr = 'library_to_link.pic_static_library.basename.startswith("lib" + target.label.name)',
                ).equals(True)

def _collect_user_link_flags(env, target):
    asserts.true(env, CcInfo in target, "rust_library should provide CcInfo")
    cc_info = target[CcInfo]
    linker_inputs = cc_info.linking_context.linker_inputs.to_list()
    return [f for i in linker_inputs for f in i.user_link_flags]

def _rust_cc_injection_impl(ctx):
    dep_variant_info = rust_common.dep_variant_info(
        cc_info = ctx.attr.cc_dep[CcInfo],
        crate_info = None,
        dep_info = None,
        build_info = None,
    )
    return [
        rust_common.crate_group_info(
            dep_variant_infos = depset([dep_variant_info]),
        ),
    ]

rust_cc_injection = rule(
    attrs = {
        "cc_dep": attr.label(
            providers = [CcInfo],
        ),
    },
    implementation = _rust_cc_injection_impl,
)

def _rust_output_extractor_impl(ctx):
    dep = ctx.attr.dep
    crate_info = dep[rust_common.test_crate_info].crate
    output = crate_info.output

    return [DefaultInfo(
        files = depset([output]),
    )]

rust_output_extractor = rule(
    implementation = _rust_output_extractor_impl,
    attrs = {
        "dep": attr.label(),
    },
)

def _cc_info_test():
    rust_library(
        name = "rlib",
        srcs = ["foo.rs"],
        edition = "2018",
    )

    rust_library(
        name = "rlib_with_dep",
        srcs = ["foo.rs"],
        edition = "2018",
        deps = [":rlib"],
    )

    rust_binary(
        name = "bin",
        srcs = ["foo.rs"],
        edition = "2018",
    )

    rust_static_library(
        name = "staticlib",
        srcs = ["foo.rs"],
        edition = "2018",
    )

    rust_shared_library(
        name = "cdylib",
        srcs = ["foo.rs"],
        edition = "2018",
    )

    rust_proc_macro(
        name = "proc_macro",
        srcs = ["proc_macro.rs"],
        edition = "2018",
        deps = ["//test/unit/native_deps:native_dep"],
    )

    cc_library(
        name = "cc_lib",
        srcs = ["foo.cc"],
    )

    rust_cc_injection(
        name = "cc_lib_injected",
        cc_dep = ":cc_lib",
    )

    rust_output_extractor(
        name = "rust_output_extractor",
        dep = select({
            "@platforms//os:windows": ":staticlib",
            "//conditions:default": ":cdylib",
        }),
    )

    cc_import(
        name = "cc_import",
        interface_library = ":rust_output_extractor",
        system_provided = True,
    )

    rust_library(
        name = "rust_lib_with_cc_lib_injected",
        srcs = ["foo.rs"],
        deps = [":cc_lib_injected"],
        edition = "2018",
    )

    rust_library(
        name = "rust_lib_with_interface_lib_dep",
        srcs = ["foo.rs"],
        deps = [":cc_import"],
        edition = "2018",
    )

    rust_shared_library(
        name = "rust_dylib_with_interface_lib_dep",
        srcs = ["foo.rs"],
        deps = [":cc_import"],
        edition = "2018",
    )

    mock_rust_library_with_custom_owner(
        name = "custom_owner_target",
        owner = ":rlib",
    )

    mock_rust_library_with_custom_owner(
        name = "none_owner_target",
        set_owner_to_none = True,
    )

    #linker_input_owner_test(
    #    name = "none_owner_test",
    #    target_under_test = ":none_owner_target",
    #)

    mock_rust_library_with_custom_owner(
        name = "absent_owner_target",
    )

    #linker_input_owner_test(
    #    name = "absent_owner_test",
    #    target_under_test = ":absent_owner_target",
    #)

def _mock_rust_library_with_custom_owner_impl(ctx):
    output = ctx.actions.declare_file(ctx.label.name + ".rlib")
    ctx.actions.write(output, "")

    owner = ctx.attr.owner

    crate_info_kwargs = dict(
        name = "mock_crate",
        type = "rlib",
        root = output,
        srcs = depset([output]),
        deps = depset(),
        proc_macro_deps = depset(),
        aliases = {},
        output = output,
        edition = "2021",
        is_test = False,
    )
    if ctx.attr.set_owner_to_none:
        crate_info_kwargs["owner"] = None
    elif owner:
        crate_info_kwargs["owner"] = owner.label

    crate_info = rust_common.create_crate_info(
        **crate_info_kwargs
    )

    mock_toolchain = struct(
        stdlib_linkflags = CcInfo(),
        libstd_and_allocator_ccinfo = CcInfo(),
        _experimental_use_global_allocator = False,
        _experimental_use_allocator_libraries_with_mangled_symbols = 0,
        _no_std = "off",
        _link_std_dylib = False,
    )

    providers = establish_cc_info(
        ctx = ctx,
        attr = ctx.attr,
        crate_info = crate_info,
        toolchain = mock_toolchain,
        cc_toolchain = None,
        feature_configuration = None,
        interface_library = None,
        use_pic = False,
    )

    return providers

mock_rust_library_with_custom_owner = rule(
    implementation = _mock_rust_library_with_custom_owner_impl,
    attrs = {
        "owner": attr.label(mandatory = False),
        "set_owner_to_none": attr.bool(default = False),
    },
)

def _rlib_provides_cc_info_test(name):
    rust_library(
        name = name + "_rlib",
        srcs = ["foo.rs"],
        edition = "2018",
        tags = ["manual"],
    )
    analysis_test(
        name = name,
        target = name + "_rlib",
        attrs = {
            "_experimental_use_allocator_libraries_with_mangled_symbols": attr.label(
                default = Label("//rust/settings:experimental_use_allocator_libraries_with_mangled_symbols"),
            ),
            "_windows": attr.label(default = Label("@platforms//os:windows")),
        },
        impl = _rlib_provides_cc_info_test_impl,
    )

def _rlib_provides_cc_info_test_impl(env, target):
    count = 4
    if _is_windows(env.ctx):
        count -= 1
    if env.ctx.attr._experimental_use_allocator_libraries_with_mangled_symbols[BuildSettingInfo].value:
        count -= 1

    _assert_cc_info_has_library_to_link(env, target, "rlib", count)

def _rlib_with_dep_only_has_stdlib_linkflags_once_test(name):
    rust_library(
        name = name + "_rlib",
        srcs = ["foo.rs"],
        edition = "2018",
        tags = ["manual"],
    )
    rust_library(
        name = name + "_rlib_with_dep",
        srcs = ["foo.rs"],
        edition = "2018",
        deps = [name + "_rlib"],
        tags = ["manual"],
    )
    analysis_test(
        name = name,
        target = name + "_rlib_with_dep",
        impl = _rlib_with_dep_only_has_stdlib_linkflags_once_test_impl,
    )

def _rlib_with_dep_only_has_stdlib_linkflags_once_test_impl(env, target):
    user_link_flags = _collect_user_link_flags(env, target)
    if user_link_flags != depset(user_link_flags).to_list():
        env.fail("user_link_flags should have no duplicates")

def _staticlib_provides_cc_info_test(name):
    rust_static_library(
        name = name + "_staticlib",
        srcs = ["foo.rs"],
        edition = "2018",
        tags = ["manual"],
    )
    analysis_test(
        name = name,
        target = name + "_staticlib",
        impl = _staticlib_provides_cc_info_test_impl,
    )

def _staticlib_provides_cc_info_test_impl(env, target):
    _assert_cc_info_has_library_to_link(env, target, "staticlib", 2)

def _cdylib_provides_cc_info_test(name):
    rust_shared_library(
        name = name + "_cdylib",
        srcs = ["foo.rs"],
        edition = "2018",
        tags = ["manual"],
    )
    analysis_test(
        name = name,
        target = name + "_cdylib",
        impl = _cdylib_provides_cc_info_test_impl,
        attrs = {
            "_windows": attr.label(default = Label("@platforms//os:windows")),
        },
    )

def _cdylib_provides_cc_info_test_impl(env, target):
    _assert_cc_info_has_library_to_link(env, target, "cdylib", 2)

def _proc_macro_does_not_provide_cc_info_test(name):
    rust_proc_macro(
        name = name + "_proc_macro",
        srcs = ["proc_macro.rs"],
        edition = "2018",
        deps = ["//test/unit/native_deps:native_dep"],
        tags = ["manual"],
    )
    analysis_test(
        name = name,
        target = name + "_proc_macro",
        impl = _proc_macro_does_not_provide_cc_info_test_impl,
    )

def _proc_macro_does_not_provide_cc_info_test_impl(env, target):
    if CcInfo in target:
        env.fail("rust_proc_macro should not provide CcInfo")

def _bin_does_not_provide_cc_info_test(name):
    rust_binary(
        name = name + "_bin",
        srcs = ["foo.rs"],
        edition = "2018",
        tags = ["manual"],
    )
    analysis_test(
        name = name,
        target = name + "_bin",
        impl = _bin_does_not_provide_cc_info_test_impl,
    )

def _bin_does_not_provide_cc_info_test_impl(env, target):
    if CcInfo in target:
        env.fail("rust_binary should not provide CcInfo")

def _crate_group_info_provides_cc_info_test(name):
    cc_library(
        name = name + "_cc_lib",
        srcs = ["foo.cc"],
        tags = ["manual"],
    )
    rust_cc_injection(
        name = name + "_cc_lib_injected",
        cc_dep = name + "_cc_lib",
        tags = ["manual"],
    )
    rust_library(
        name = name + "_rust_lib_with_cc_lib_injected",
        srcs = ["foo.rs"],
        deps = [name + "_cc_lib_injected"],
        edition = "2018",
        tags = ["manual"],
    )
    analysis_test(
        name = name,
        target = name + "_rust_lib_with_cc_lib_injected",
        impl = _crate_group_info_provides_cc_info_test_impl,
    )

def _crate_group_info_provides_cc_info_test_impl(env, target):
    if len(target[rust_common.dep_info].transitive_noncrates.to_list()) != 1:
        env.fail("crate_group_info should provide 1 non-crate transitive dependency")

def _is_cc_interface_library_test(name):
    rust_static_library(
        name = name + "_staticlib",
        srcs = ["foo.rs"],
        edition = "2018",
        tags = ["manual"],
    )
    rust_shared_library(
        name = name + "_cdylib",
        srcs = ["foo.rs"],
        edition = "2018",
        tags = ["manual"],
    )
    rust_output_extractor(
        name = name + "_rust_output_extractor",
        dep = select({
            "@platforms//os:windows": name + "_staticlib",
            "//conditions:default": name + "_cdylib",
        }),
    )
    cc_import(
        name = name + "_cc_import",
        interface_library = name + "_rust_output_extractor",
        system_provided = True,
        tags = ["manual"],
    )
    analysis_test(
        name = name,
        target = name + "_cc_import",
        impl = _is_cc_interface_library_test_impl,
    )

def _is_cc_interface_library_test_impl(env, target):
    cc_info = target[CcInfo]

    linker_inputs = cc_info.linking_context.linker_inputs.to_list()
    if len(linker_inputs) == 0:
        env.fail("No linker inputs provided by {}".format(target.label))

    for linker_input in linker_inputs:
        if len(linker_input.libraries) == 0:
            env.fail("No linker input libraries provided by {}".format(target.label))

        for library_to_link in linker_input.libraries:
            _expect_that_library_to_link(env, library_to_link).dynamic_library().is_none()
            _expect_that_library_to_link(env, library_to_link).static_library().is_none()
            _expect_that_library_to_link(env, library_to_link).pic_static_library().is_none()
            _expect_that_library_to_link(env, library_to_link).interface_library().is_not_none()

# Shared test impl that checks that `target` produces an output.
def _build_test_impl(env, target):
    if rust_common.crate_info in target:
        crate_info = target[rust_common.crate_info]
    else:
        crate_info = target[rust_common.test_crate_info].crate
    if not crate_info.output:
        env.fail("No output created by {}".format(target.label))

def _rust_lib_with_interface_lib_dep_test(name):
    rust_static_library(
        name = name + "_staticlib",
        srcs = ["foo.rs"],
        edition = "2018",
        tags = ["manual"],
    )
    rust_shared_library(
        name = name + "_cdylib",
        srcs = ["foo.rs"],
        edition = "2018",
        tags = ["manual"],
    )
    rust_output_extractor(
        name = name + "_rust_output_extractor",
        dep = select({
            "@platforms//os:windows": name + "_staticlib",
            "//conditions:default": name + "_cdylib",
        }),
    )
    cc_import(
        name = name + "_cc_import",
        interface_library = name + "_rust_output_extractor",
        system_provided = True,
        tags = ["manual"],
    )
    rust_library(
        name = name + "_rust_lib_with_interface_lib_dep",
        srcs = ["foo.rs"],
        link_deps = [name + "_cc_import"],
        edition = "2018",
        tags = ["manual"],
    )
    analysis_test(
        name = name,
        target = name + "_rust_lib_with_interface_lib_dep",
        impl = _build_test_impl,
    )

def _rust_dylib_with_interface_lib_dep_test(name):
    rust_static_library(
        name = name + "_staticlib",
        srcs = ["foo.rs"],
        edition = "2018",
        tags = ["manual"],
    )
    rust_shared_library(
        name = name + "_cdylib",
        srcs = ["foo.rs"],
        edition = "2018",
        tags = ["manual"],
    )
    rust_output_extractor(
        name = name + "_rust_output_extractor",
        dep = select({
            "@platforms//os:windows": name + "_staticlib",
            "//conditions:default": name + "_cdylib",
        }),
    )
    cc_import(
        name = name + "_cc_import",
        interface_library = name + "_rust_output_extractor",
        system_provided = True,
        tags = ["manual"],
    )
    rust_shared_library(
        name = name + "_rust_dylib_with_interface_lib_dep",
        srcs = ["foo.rs"],
        link_deps = [name + "_cc_import"],
        edition = "2018",
        tags = ["manual"],
    )
    analysis_test(
        name = name,
        target = name + "_rust_dylib_with_interface_lib_dep",
        impl = _build_test_impl,
    )

def _linker_input_owner_test_impl(env, target):
    env.expect.that_target(target).has_provider(CcInfo, provider_name = "CcInfo")
    cc_info = target[CcInfo]

    linker_inputs = cc_info.linking_context.linker_inputs.to_list()
    env.expect.that_collection(linker_inputs, expr = "cc_info.linking_context.linker_inputs.to_list()").has_size(1)
    linker_input = linker_inputs[0]

    expected_owner = env.ctx.attr.expected_owner
    if expected_owner:
        expected_owner_label = expected_owner.label
    else:
        expected_owner_label = target.label

    if expected_owner_label != linker_input.owner:
        env.fail("Unexpected owner for target {}. Expected = '{}', actual = '{}'".format(
            target.label,
            expected_owner_label,
            linker_input.owner,
        ))

def _linker_input_owner_test(name):
    rust_library(
        name = name + "_rlib",
        srcs = ["foo.rs"],
        edition = "2018",
        tags = ["manual"],
    )
    mock_rust_library_with_custom_owner(
        name = name + "_custom_owner_target",
        owner = name + "_rlib",
        tags = ["manual"],
    )
    analysis_test(
        name = name,
        target = name + "_custom_owner_target",
        impl = _linker_input_owner_test_impl,
        attrs = {
            "expected_owner": attr.label(mandatory = False),
        },
        attr_values = {
            "expected_owner": name + "_rlib",
        },
    )

def _none_owner_test(name):
    mock_rust_library_with_custom_owner(
        name = name + "_none_owner_target",
        set_owner_to_none = True,
    )
    analysis_test(
        name = name,
        target = name + "_none_owner_target",
        impl = _linker_input_owner_test_impl,
        attrs = {
            "expected_owner": attr.label(mandatory = False),
        },
    )

def _absent_owner_test(name):
    mock_rust_library_with_custom_owner(
        name = name + "_absent_owner_target",
    )
    analysis_test(
        name = name,
        target = name + "_absent_owner_target",
        impl = _linker_input_owner_test_impl,
        attrs = {
            "expected_owner": attr.label(mandatory = False),
        },
    )

def cc_info_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name: Name of the macro.
    """
    test_suite(
        name = name,
        tests = [
            _rlib_provides_cc_info_test,
            _rlib_with_dep_only_has_stdlib_linkflags_once_test,
            _staticlib_provides_cc_info_test,
            _cdylib_provides_cc_info_test,
            _proc_macro_does_not_provide_cc_info_test,
            _bin_does_not_provide_cc_info_test,
            _crate_group_info_provides_cc_info_test,
            _is_cc_interface_library_test,
            _rust_lib_with_interface_lib_dep_test,
            _rust_dylib_with_interface_lib_dep_test,
            _linker_input_owner_test,
            _none_owner_test,
            _absent_owner_test,
        ],
    )
