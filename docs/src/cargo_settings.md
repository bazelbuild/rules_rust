<!-- Generated with Stardoc: http://skydoc.bazel.build -->

# Cargo settings

Definitions for all `@rules_rust//cargo` settings

<a id="cargo_manifest_dir_filename_suffixes_to_retain"></a>

## cargo_manifest_dir_filename_suffixes_to_retain

<pre>
--@rules_rust//cargo/settings:cargo_manifest_dir_filename_suffixes_to_retain
</pre>

A flag which determines what files are retained in `CARGO_MANIFEST_DIR` directories     that are created in `CargoBuildScriptRun` actions.



<a id="debug_std_streams_output_group"></a>

## debug_std_streams_output_group

<pre>
--@rules_rust//cargo/settings:debug_std_streams_output_group
</pre>

A flag which adds a `streams` output group to `cargo_build_script` targets that contain     the raw `stderr` and `stdout` streams from the build script.



<a id="experimental_symlink_execroot"></a>

## experimental_symlink_execroot

<pre>
--@rules_rust//cargo/settings:experimental_symlink_execroot
</pre>

A flag for which causes `cargo_build_script` to symlink the execroot of the action to     the `CARGO_MANIFEST_DIR` where the scripts are run.



<a id="incompatible_runfiles_cargo_manifest_dir"></a>

## incompatible_runfiles_cargo_manifest_dir

<pre>
--@rules_rust//cargo/settings:incompatible_runfiles_cargo_manifest_dir
</pre>

A flag which causes `cargo_build_script` to write an explicit `CARGO_MANFIEST_DIR`     directory from an action instead of using runfiles directories which cannot be     passed to downstream actions.

https://github.com/bazelbuild/bazel/issues/15486



<a id="use_default_shell_env"></a>

## use_default_shell_env

<pre>
--@rules_rust//cargo/settings:use_default_shell_env
</pre>

A flag which controls the global default of `ctx.actions.run.use_default_shell_env` for `cargo_build_script` targets.



