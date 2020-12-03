# Copyright 2015 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Utility functions not specific to the rust toolchain."""

def find_toolchain(ctx):
    """Finds the first rust toolchain that is configured.

    Args:
        ctx (ctx): The ctx object for the current target.

    Returns:
        rust_toolchain: A Rust toolchain context.
    """
    return ctx.toolchains["@io_bazel_rules_rust//rust:toolchain"]

# TODO: Replace with bazel-skylib's `path.dirname`. This requires addressing some
# dependency issues or generating docs will break.
def relativize(path, start):
    """Returns the relative path from start to path.

    Args:
        path (str): The path to relativize.
        start (str): The ancestor path against which to relativize.

    Returns:
        str: The portion of `path` that is relative to `start`.
    """
    src_parts = _path_parts(start)
    dest_parts = _path_parts(path)
    n = 0
    done = False
    for src_part, dest_part in zip(src_parts, dest_parts):
        if src_part != dest_part:
            break
        n += 1

    relative_path = ""
    for i in range(n, len(src_parts)):
        relative_path += "../"
    relative_path += "/".join(dest_parts[n:])

    return relative_path

def _path_parts(path):
    """Takes a path and returns a list of its parts with all "." elements removed.

    The main use case of this function is if one of the inputs to relativize()
    is a relative path, such as "./foo".

    Args:
      path (str): A string representing a unix path

    Returns:
      list: A list containing the path parts with all "." elements removed.
    """
    path_parts = path.split("/")
    return [part for part in path_parts if part != "."]

def get_lib_name(lib):
    """Returns the name of a library artifact, eg. libabc.a -> abc

    Args:
        lib (File): A library file

    Returns:
        str: The name of the library
    """
    # NB: The suffix may contain a version number like 'so.1.2.3'
    libname = lib.basename.split(".", 1)[0]

    if libname.startswith("lib"):
        return libname[3:]
    else:
        return libname

def determine_output_hash(crate_root):
    """Generates a hash of the crate root file's path.

    Args:
        crate_root (File): The crate's root file (typically `lib.rs`).

    Returns:
        str: A string representation of the hash.
    """
    return repr(hash(crate_root.path))

def get_libs_for_static_executable(dep):
    """find the libraries used for linking a static executable.

    Args:
        dep (Target): A cc_library target.

    Returns:
        depset: A depset[File]
    """
    linker_inputs = dep[CcInfo].linking_context.linker_inputs.to_list()
    return depset([_get_preferred_artifact(lib) for li in linker_inputs for lib in li.libraries])

def _get_preferred_artifact(library_to_link):
    """Get the first available library to link from a LibraryToLink object.

    Args:
        library_to_link (LibraryToLink): See the followg links for additional details:
            https://docs.bazel.build/versions/master/skylark/lib/LibraryToLink.html

    Returns:
        File: Returns the first valid library type (only one is expected)
    """
    return (
        library_to_link.static_library or
        library_to_link.pic_static_library or
        library_to_link.interface_library or
        library_to_link.dynamic_library
    )

def rule_attrs(ctx, aspect):
    """Gets a rule's attributes.

    As per https://docs.bazel.build/versions/master/skylark/aspects.html when we're executing from an
    aspect we need to get attributes of a rule differently to if we're not in an aspect.

    Args:
        ctx (ctx): A rule's context object
        aspect (bool): Whether we're running in an aspect

    Returns:
        struct: A struct to access the values of the attributes for a
            [rule_attributes](https://docs.bazel.build/versions/master/skylark/lib/rule_attributes.html#modules.rule_attributes)
            object.
    """
    return ctx.rule.attr if aspect else ctx.attr
