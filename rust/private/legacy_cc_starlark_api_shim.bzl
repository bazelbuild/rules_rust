"""
Part of --incompatible_disable_legacy_cc_provider migration (https://github.com/bazelbuild/bazel/issues/7036)
"""

def get_libs_for_static_executable(dep):
    """
    This replaces dep.cc.libs, which found the libraries
    used for linking a static executable.

    Args:
      dep: A cc_library target.
    Returns:
      A depset[File]
    """
    libraries_to_link = dep[CcInfo].linking_context.libraries_to_link
    return depset([_get_preferred_artifact(lib) for lib in libraries_to_link.to_list()])

def _get_preferred_artifact(library_to_link):
    return (
        library_to_link.static_library or
        library_to_link.pic_static_library or
        library_to_link.interface_library or
        library_to_link.dynamic_library
    )
