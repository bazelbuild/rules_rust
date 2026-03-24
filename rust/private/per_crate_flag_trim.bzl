# Copyright 2024 The Bazel Authors. All rights reserved.
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

"""Transition to trim per_crate_rustc_flag for non-matching targets.

This module provides a configuration trimming mechanism for the
`experimental_per_crate_rustc_flag` setting. When a target has
`skip_per_crate_rustc_flags = True`, this transition clears the setting,
putting the target back into a canonical configuration.

This is useful for third-party crates (e.g., from crate_universe) that will
never match any per-crate flag filter. Without trimming, these crates would
be rebuilt unnecessarily when any per-crate flag is set, even though the
filter doesn't match them.

Usage:
    Third-party crate generators (like crate_universe) should set
    `skip_per_crate_rustc_flags = True` on generated rust_library targets.
"""

_PER_CRATE_FLAG_SETTING = "@rules_rust//rust/settings:experimental_per_crate_rustc_flag"

def _per_crate_flag_trim_transition_impl(settings, attr):
    """Clear per_crate_rustc_flag for targets marked to skip it.

    Args:
        settings: A dict of current build settings.
        attr: The attributes of the target being configured.

    Returns:
        A dict with the per_crate_rustc_flag setting (cleared or preserved).
    """
    # If this target is marked to skip per-crate flags, clear the setting
    # to return it to a canonical configuration
    if getattr(attr, "skip_per_crate_rustc_flags", False):
        return {
            _PER_CRATE_FLAG_SETTING: [],
        }

    # Otherwise, keep the current value
    return {
        _PER_CRATE_FLAG_SETTING: settings[_PER_CRATE_FLAG_SETTING],
    }

per_crate_flag_trim_transition = transition(
    implementation = _per_crate_flag_trim_transition_impl,
    inputs = [_PER_CRATE_FLAG_SETTING],
    outputs = [_PER_CRATE_FLAG_SETTING],
)
