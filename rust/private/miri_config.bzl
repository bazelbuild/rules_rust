# Copyright 2026 The Bazel Authors. All rights reserved.
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

"""Shared Miri configuration helpers."""

def _miri_transition_impl(settings, attr):
    # Re-analyze the wrapped Rust target in a Miri-specific configuration while
    # preserving the existing target platform unless the caller overrides it.
    return {
        "//command_line_option:platforms": str(attr.platform) if attr.platform else settings["//command_line_option:platforms"],
        "//rust/private:miri_enabled": True,
    }

miri_transition = transition(
    implementation = _miri_transition_impl,
    inputs = [
        "//command_line_option:platforms",
    ],
    outputs = [
        "//command_line_option:platforms",
        "//rust/private:miri_enabled",
    ],
)

def rlocationpath(file, workspace_name):
    # Generated launchers run from Bazel runfiles, so they need a stable
    # rlocation path even when the file comes from an external repository.
    if file.short_path.startswith("../"):
        return file.short_path[len("../"):]

    return "{}/{}".format(workspace_name, file.short_path)
