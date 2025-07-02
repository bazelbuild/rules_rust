"""A module defining Rust link time optimization (lto) rules"""

load("//rust/private:utils.bzl", "is_exec_configuration")

_LTO_MODES = [
    # Do nothing, let the user manually handle LTO.
    "manual",
    # Default. No mode has been explicitly set, rustc will do "thin local" LTO
    # between the codegen units of a single crate.
    "unspecified",
    # LTO has been explicitly turned "off".
    "off",
    # Perform "thin" LTO. This is similar to "fat" but takes significantly less
    # time to run, but provides similar performance improvements.
    #
    # See: <http://blog.llvm.org/2016/06/thinlto-scalable-and-incremental-lto.html>
    "thin",
    # Perform "fat"/full LTO.
    "fat",
]

RustLtoInfo = provider(
    doc = "A provider describing the link time optimization setting.",
    fields = {"mode": "string: The LTO mode specified via a build setting."},
)

def _rust_lto_flag_impl(ctx):
    value = ctx.build_setting_value

    if value not in _LTO_MODES:
        msg = "{NAME} build setting allowed to take values [{VALUES}], but was set to: {ACTUAL}".format(
            NAME = ctx.label,
            VALUES = ", ".join(["'{}'".format(m) for m in _LTO_MODES]),
            ACTUAL = value,
        )
        fail(msg)

    return RustLtoInfo(mode = value)

rust_lto_flag = rule(
    doc = "A build setting which specifies the link time optimization mode used when building Rust code. Allowed values are: ".format(_LTO_MODES),
    implementation = _rust_lto_flag_impl,
    build_setting = config.string(flag = True),
)

def _determine_lto_object_format(ctx, toolchain, crate_info):
    """Determines what bitcode should get included in a built artifact.

    Args:
        ctx (ctx): The calling rule's context object.
        toolchain (rust_toolchain): The current target's `rust_toolchain`.
        crate_info (CrateInfo): The CrateInfo provider of the target crate.

    Returns:
        string: Returns one of only_object, only_bitcode, object_and_bitcode.
    """

    # Even if LTO is enabled don't use it for actions being built in the exec
    # configuration, e.g. build scripts and proc-macros. This mimics Cargo.
    if is_exec_configuration(ctx):
        return "only_object"

    mode = toolchain.lto.mode

    if mode in ["off", "unspecified"]:
        return "only_object"

    perform_linking = crate_info.type in ["bin", "staticlib", "cdylib"]
    is_dynamic = crate_info.type in ["dylib", "cdylib", "proc-macro"]
    needs_object = perform_linking or is_dynamic

    # At this point we know LTO is enabled, otherwise we would have returned above.

    if not needs_object:
        # If we're building an 'rlib' and LTO is enabled, then we can skip
        # generating object files entirely.
        return "only_bitcode"
    elif crate_info.type in ["dylib", "proc-macro"]:
        # If we're a dylib or a proc-macro and we're running LTO, then only emit
        # object code because 'rustc' doesn't currently support LTO for these targets.
        return "only_object"
    else:
        return "object_and_bitcode"

def _determine_experimental_xlang_lto(ctx, toolchain, crate_info):
    """Determines if we should use Linker-plugin-based LTO, to enable cross language optimizations.

    'rustc' has a `linker-plugin-lto` codegen option which delays LTO to the actual linking step.
    If your C/C++ code is built with an LLVM toolchain (e.g. clang) and was built with LTO enabled,
    then the linker can perform optimizations across programming language boundaries.

    See <https://doc.rust-lang.org/rustc/linker-plugin-lto.html>

    Args:
        ctx (ctx): The calling rule's context object.
        toolchain (rust_toolchain): The current target's `rust_toolchain`.
        crate_info (CrateInfo): The CrateInfo provider of the target crate.

    Returns:
        bool: Whether or not to specify `-Clinker-plugin-lto` when building this crate.
    """

    feature_enabled = toolchain._experimental_cross_language_lto
    rust_lto_enabled = toolchain.lto.mode in ["thin", "fat"]
    correct_crate_type = crate_info.type in ["bin"]

    # TODO(parkmycar): We could try to detect if LTO is enabled for C code using
    # `ctx.fragments.cpp.copts` but I'm not sure how reliable that is.

    return feature_enabled and rust_lto_enabled and correct_crate_type and not is_exec_configuration(ctx)

def construct_lto_arguments(ctx, toolchain, crate_info):
    """Returns a list of 'rustc' flags to configure link time optimization.

    Args:
        ctx (ctx): The calling rule's context object.
        toolchain (rust_toolchain): The current target's `rust_toolchain`.
        crate_info (CrateInfo): The CrateInfo provider of the target crate.

    Returns:
        list: A list of strings that are valid flags for 'rustc'.
    """
    mode = toolchain.lto.mode

    # The user is handling LTO on their own, don't add any arguments.
    if mode == "manual":
        return []

    format = _determine_lto_object_format(ctx, toolchain, crate_info)
    xlang_enabled = _determine_experimental_xlang_lto(ctx, toolchain, crate_info)
    args = []

    # Only tell `rustc` to use LTO if it's enabled, the crate we're currently building has bitcode
    # embeded, and we're not building in the exec configuration.
    #
    # We skip running LTO when building for the exec configuration because the exec config is used
    # for local tools, like build scripts or proc-macros, and LTO isn't really needed in those
    # scenarios. Note, this also mimics Cargo's behavior.
    if mode in ["thin", "fat", "off"] and crate_info.type != "proc-macro" and not is_exec_configuration(ctx):
        args.append("lto={}".format(mode))

    if format == "object_and_bitcode":
        # Embedding LLVM bitcode in object files is `rustc's` default.
        args.extend([])
    elif format == "only_object":
        args.extend(["embed-bitcode=no"])
    elif format == "only_bitcode":
        args.extend(["linker-plugin-lto"])
    else:
        fail("unrecognized LTO object format {}".format(format))

    if xlang_enabled:
        args.append("linker-plugin-lto")

    return ["-C{}".format(arg) for arg in args]
