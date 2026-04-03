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

"""Reset target-specific Starlark settings in exec configuration.

Bazel's built-in exec transition resets native flags (like --compilation_mode)
but does NOT reset Starlark build settings. This means settings like
--@rules_rust//rust/settings:lto=thin leak into the exec configuration hash,
causing unnecessary tool rebuilds when switching between e.g. fastbuild and opt.

rules_rust already strips these settings at action construction time (via
is_exec_configuration() checks), so the actual rustc commands for tools are
identical. But the different config hash prevents cache reuse.

This module provides helpers so that rule-level transitions can reset
target-specific settings to their defaults when in exec configuration,
making the config hash stable across target configuration changes.

The mechanism uses a marker flag (_exec_settings_trimmed) that is set
unconditionally by rust_proc_macro's rule transition. Since proc macros
always run in exec configuration, this is safe. Other rules (rust_library,
rust_binary, etc.) check this marker and conditionally reset settings,
so the reset propagates transitively through the exec dependency subgraph.
"""

# Marker flag: set to True by rust_proc_macro's transition to signal that
# exec-config settings trimming should be applied.
_EXEC_TRIMMED_SETTING = "@rules_rust//rust/private:exec_settings_trimmed"

# Native Bazel flags that leak into exec configuration when a proc macro
# is reached via `deps` instead of `proc_macro_deps` (which would apply
# cfg = "exec" automatically). We reset these to their Bazel defaults
# so that proc macros always get a stable configuration hash.
_NATIVE_FLAGS_DEFAULTS = {
    # Matches Bazel's default --host_compilation_mode.
    "//command_line_option:compilation_mode": "opt",
    "//command_line_option:stamp": False,
    "//command_line_option:strip": "sometimes",
}

# Native flags that are write-only in transitions (not Starlark-readable).
# These are included in outputs but NOT inputs, and always reset to None.
_WRITE_ONLY_NATIVE_FLAGS = [
    "//command_line_option:run_under",
]

# Target-specific settings and their default values.
# These are settings that rules_rust ignores for exec-config targets
# (via is_exec_configuration() checks in rustc.bzl and lto.bzl).
_TARGET_SETTINGS_DEFAULTS = {
    "@rules_rust//rust/settings:codegen_units": -1,
    "@rules_rust//rust/settings:experimental_per_crate_rustc_flag": [],
    "@rules_rust//rust/settings:extra_rustc_env": [],
    "@rules_rust//rust/settings:extra_rustc_flag": [],
    "@rules_rust//rust/settings:extra_rustc_flags": [],
    "@rules_rust//rust/settings:incremental": False,
    "@rules_rust//rust/settings:lto": "unspecified",
    "@rules_rust//rust/settings:no_std": "off",
    "@rules_rust//rust/settings:pipelined_compilation": False,
}

_PER_CRATE_FLAG_SETTING = "@rules_rust//rust/settings:experimental_per_crate_rustc_flag"

_PLATFORMS_SETTING = "//command_line_option:platforms"

def _exec_trim_input_settings():
    """Returns settings that can be read in transitions (inputs).

    Excludes write-only flags (like run_under) that Bazel cannot expose
    to Starlark.
    """
    return [_EXEC_TRIMMED_SETTING] + list(_NATIVE_FLAGS_DEFAULTS.keys()) + list(_TARGET_SETTINGS_DEFAULTS.keys())

def _exec_trim_output_settings():
    """Returns settings that transitions can write (outputs).

    Includes write-only flags that are always reset to None.
    """
    return _exec_trim_input_settings() + _WRITE_ONLY_NATIVE_FLAGS

# Precomputed settings lists for rule transitions that also handle
# platform overrides and per-crate flag trimming (rust_binary,
# rust_test, rust_static_library, rust_shared_library).
RULE_TRANSITION_INPUT_SETTINGS = _exec_trim_input_settings() + [_PLATFORMS_SETTING]
RULE_TRANSITION_OUTPUT_SETTINGS = _exec_trim_output_settings() + [_PLATFORMS_SETTING]

def _apply_exec_settings_trim(settings, force = False, include_write_only = False):
    """Returns a dict resetting target-specific settings if the marker is set.

    Args:
        settings: The current build settings dict.
        force: If True, always reset (regardless of marker). Used by
               ``rust_proc_macro`` which unconditionally enters exec config.
        include_write_only: If True, also reset write-only flags (like
               ``run_under``) that can't be read in Starlark. Only set
               this when the transition's outputs list includes
               ``RULE_TRANSITION_OUTPUT_SETTINGS``.

    Returns:
        A dict with the marker and target settings reset to defaults,
        or a dict preserving current values if trimming is not needed.
    """
    marker = settings[_EXEC_TRIMMED_SETTING]
    should_trim = force or marker

    if should_trim:
        result = {_EXEC_TRIMMED_SETTING: True}
        result.update(_NATIVE_FLAGS_DEFAULTS)
        result.update(_TARGET_SETTINGS_DEFAULTS)
        if include_write_only:
            for flag in _WRITE_ONLY_NATIVE_FLAGS:
                result[flag] = None
        return result

    # Not in exec config -- preserve all current values.
    result = {_EXEC_TRIMMED_SETTING: False}
    for setting in _NATIVE_FLAGS_DEFAULTS:
        result[setting] = settings[setting]
    for setting in _TARGET_SETTINGS_DEFAULTS:
        result[setting] = settings[setting]
    return result

def rule_transition_impl(settings, attr, force = False):
    """Common transition logic for rules with platform and per-crate flag handling.

    Combines three concerns:
    1. Exec settings trimming (conditional on marker, or forced for proc macros).
    2. Platform override (from the rule's ``platform`` attribute, if present).
    3. Per-crate flag trimming (when ``skip_per_crate_rustc_flags`` is set).

    Note: ``skip_per_crate_rustc_flags`` only controls per-crate flag trimming,
    NOT exec settings trimming. All third-party crates set this flag (via
    crate_universe), and they must retain target-config settings like LTO.
    Exec settings trimming is only forced for true exec tools (proc macros
    via ``force=True``) or when the ``exec_settings_trimmed`` marker propagates
    from an upstream exec transition.

    Args:
        settings: The current build settings dict.
        attr: The attributes of the target being configured.
        force: If True, always apply exec settings trim AND include
               write-only flags (for proc macros).

    Returns:
        A dict with settings adjusted for exec trimming, platform override,
        and per-crate flag trimming.
    """
    result = _apply_exec_settings_trim(
        settings,
        force = force,
        include_write_only = force,
    )

    # Platform override: use the rule's platform attribute if set.
    platform = getattr(attr, "platform", None)
    result[_PLATFORMS_SETTING] = str(platform) if platform else settings[_PLATFORMS_SETTING]

    # Per-crate flag trimming: clear flags for targets marked to skip them.
    # When exec trim fires, per-crate flags are already reset to [] by
    # _TARGET_SETTINGS_DEFAULTS, so this is redundant but harmless.
    skip_per_crate = getattr(attr, "skip_per_crate_rustc_flags", False)
    if skip_per_crate:
        result[_PER_CRATE_FLAG_SETTING] = []

    return result
