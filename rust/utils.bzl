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

"""
Utility functions not specific to the rust toolchain.
"""

def find_toolchain(ctx):
    """Finds the first rust toolchain that is configured."""
    return ctx.toolchains["@io_bazel_rules_rust//rust:toolchain"]

def relative_path(src_path, dest_path):
    """Returns the relative path from src_path to dest_path."""
    src_parts = _path_parts(src_path)
    dest_parts = _path_parts(dest_path)
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

    The main use case of this function is if one of the inputs to _relative()
    is a relative path, such as "./foo".

    Args:
      path_parts: A list containing parts of a path.

    Returns:
      Returns a list containing the path parts with all "." elements removed.
    """
    path_parts = path.split("/")
    return [part for part in path_parts if part != "."]
