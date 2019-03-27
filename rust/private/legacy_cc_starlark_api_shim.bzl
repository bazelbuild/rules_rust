"""
Utility functions that replace old C++ Starlark API using the new API.
See migration instructions in https://github.com/bazelbuild/bazel/issues/7036

Pasted from https://gist.github.com/oquenchil/7e2c2bd761aa1341b458cc25608da50c
"""

def get_libs_for_static_executable(dep):
    """
    Finds the libraries used for linking an executable statically.
    This replaces the old API dep.cc.libs
    Args:
      dep: Target
    Returns:
      A list of File instances, these are the libraries used for linking.
    """
    libraries_to_link = dep[CcInfo].linking_context.libraries_to_link
    libs = []
    for library_to_link in libraries_to_link:
        if library_to_link.static_library != None:
            libs.append(library_to_link.static_library)
        elif library_to_link.pic_static_library != None:
            libs.append(library_to_link.pic_static_library)
        elif library_to_link.interface_library != None:
            libs.append(library_to_link.interface_library)
        elif library_to_link.dynamic_library != None:
            libs.append(library_to_link.dynamic_library)
    return depset(libs)
