"""A module defining Rust incremental compilation support"""

load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("//rust/private:utils.bzl", "is_exec_configuration")

def _is_incremental_enabled(ctx, crate_info):
    """Returns True if incremental compilation is enabled for this target.

    Args:
        ctx (ctx): The calling rule's context object.
        crate_info (CrateInfo): The CrateInfo provider of the target crate.

    Returns:
        bool: True if incremental compilation is enabled.
    """
    if not hasattr(ctx.attr, "_incremental"):
        return False
    if is_exec_configuration(ctx):
        return False
    if not ctx.attr._incremental[BuildSettingInfo].value:
        return False
    if crate_info.type == "proc-macro":
        return False

    # Don't enable incremental for external/third-party crates, mirroring cargo's
    # behavior. External crates rarely change, so incremental saves little; more
    # importantly, the disk cache hardlinks their outputs as read-only, and running
    # without sandboxing (which worker/no-sandbox requires) would cause rustc to
    # fail trying to overwrite those read-only hardlinks.
    if ctx.label.workspace_name:
        return False
    return True

def construct_incremental_arguments(ctx, crate_info, is_metadata = False):
    """Returns a list of 'rustc' flags to configure incremental compilation.

    Args:
        ctx (ctx): The calling rule's context object.
        crate_info (CrateInfo): The CrateInfo provider of the target crate.
        is_metadata (bool): True when building a RustcMetadata (--emit=metadata only) action.

    Returns:
        list: A list of strings that are valid flags for 'rustc'.
    """
    if not _is_incremental_enabled(ctx, crate_info):
        return []

    # Use a separate cache directory for metadata-only (RustcMetadata) actions.
    # Both RustcMetadata(A) and Rustc(A) compile the same crate, so they produce
    # the same SVH — but sharing the same incremental path causes a rustc ICE
    # ("no entry found for key") because the metadata-only session state is
    # incompatible with a full-compilation session.  Using distinct paths lets
    # both actions benefit from incremental caching without interfering.
    suffix = "-meta" if is_metadata else ""
    cache_path = "/tmp/rules_rust_incremental/{}{}".format(crate_info.name, suffix)

    # Explicitly set codegen-units=16 to match Cargo's dev profile default
    # (since Cargo 1.73). Without this, rustc silently bumps CGUs from 16 to
    # 256 when -Cincremental is present, adding ~37% of the cold-build overhead
    # for no rebuild benefit at opt-level=0.
    return ["-Cincremental={}".format(cache_path), "-Ccodegen-units=16"]

def is_incremental_enabled(ctx, crate_info):
    """Returns True if incremental compilation is enabled for this target.

    This is the public API used by rustc_compile_action to determine whether
    to set execution_requirements = {"no-sandbox": "1"}.

    Args:
        ctx (ctx): The calling rule's context object.
        crate_info (CrateInfo): The CrateInfo provider of the target crate.

    Returns:
        bool: True if incremental compilation is enabled.
    """
    return _is_incremental_enabled(ctx, crate_info)
