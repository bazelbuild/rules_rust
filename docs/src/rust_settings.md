<!-- Generated with Stardoc: http://skydoc.bazel.build -->

# Rust settings

Definitions for all `@rules_rust//rust` settings

<a id="capture_clippy_output"></a>

## capture_clippy_output

<pre>
--@rules_rust//rust/settings:capture_clippy_output
</pre>

Control whether to print clippy output or store it to a file, using the configured error_format.



<a id="clippy_flag"></a>

## clippy_flag

<pre>
--@rules_rust//rust/settings:clippy_flag
</pre>

Add a custom clippy flag from the command line with `--@rules_rust//rust/settings:clippy_flag`.

Multiple uses are accumulated and appended after the `extra_rustc_flags`.



<a id="clippy_flags"></a>

## clippy_flags

<pre>
--@rules_rust//rust/settings:clippy_flags
</pre>

This setting may be used to pass extra options to clippy from the command line.

It applies across all targets.



<a id="clippy_toml"></a>

## clippy_toml

<pre>
--@rules_rust//rust/settings:clippy_toml
</pre>

This setting is used by the clippy rules. See https://bazelbuild.github.io/rules_rust/rust_clippy.html

Note that this setting is actually called `clippy.toml`.



<a id="codegen_units"></a>

## codegen_units

<pre>
--@rules_rust//rust/settings:codegen_units
</pre>

The default value for `--codegen-units` which also affects resource allocation for rustc actions.

Note that any value 0 or less will prevent this flag from being passed by Bazel and allow rustc to
perform it's default behavior.

https://doc.rust-lang.org/rustc/codegen-options/index.html#codegen-units



<a id="error_format"></a>

## error_format

<pre>
--@rules_rust//rust/settings:error_format
</pre>

This setting may be changed from the command line to generate machine readable errors.



<a id="experimental_link_std_dylib"></a>

## experimental_link_std_dylib

<pre>
--@rules_rust//rust/settings:experimental_link_std_dylib
</pre>

A flag to control whether to link libstd dynamically.



<a id="experimental_per_crate_rustc_flag"></a>

## experimental_per_crate_rustc_flag

<pre>
--@rules_rust//rust/settings:experimental_per_crate_rustc_flag
</pre>

Add additional rustc_flag to matching crates from the command line with `--@rules_rust//rust/settings:experimental_per_crate_rustc_flag`.

The expected flag format is prefix_filter@flag, where any crate with a label or execution path starting
with the prefix filter will be built with the given flag. The label matching uses the canonical form of
the label (i.e `//package:label_name`). The execution path is the relative path to your workspace directory
including the base name (including extension) of the crate root. This flag is only applied to the exec
configuration (proc-macros, cargo_build_script, etc). Multiple uses are accumulated.



<a id="experimental_use_cc_common_link"></a>

## experimental_use_cc_common_link

<pre>
--@rules_rust//rust/settings:experimental_use_cc_common_link
</pre>

A flag to control whether to link rust_binary and rust_test targets using     cc_common.link instead of rustc.



<a id="experimental_use_coverage_metadata_files"></a>

## experimental_use_coverage_metadata_files

<pre>
--@rules_rust//rust/settings:experimental_use_coverage_metadata_files
</pre>

A flag to have coverage tooling added as `coverage_common.instrumented_files_info.metadata_files` instead of     reporting tools like `llvm-cov` and `llvm-profdata` as runfiles to each test.



<a id="experimental_use_global_allocator"></a>

## experimental_use_global_allocator

<pre>
--@rules_rust//rust/settings:experimental_use_global_allocator
</pre>

A flag to indicate that a global allocator is in use when using `--@rules_rust//rust/settings:experimental_use_cc_common_link`

Users need to specify this flag because rustc generates different set of symbols at link time when a global allocator is in use.
When the linking is not done by rustc, the `rust_toolchain` itself provides the appropriate set of symbols.



<a id="experimental_use_sh_toolchain_for_bootstrap_process_wrapper"></a>

## experimental_use_sh_toolchain_for_bootstrap_process_wrapper

<pre>
--@rules_rust//rust/settings:experimental_use_sh_toolchain_for_bootstrap_process_wrapper
</pre>

A flag to control whether the shell path from a shell toolchain (`@bazel_tools//tools/sh:toolchain_type`)     is embedded into the bootstrap process wrapper for the `.sh` file.



<a id="extra_exec_rustc_flag"></a>

## extra_exec_rustc_flag

<pre>
--@rules_rust//rust/settings:extra_exec_rustc_flag
</pre>

Add additional rustc_flags in the exec configuration from the command line with `--@rules_rust//rust/settings:extra_exec_rustc_flag`.

Multiple uses are accumulated and appended after the extra_exec_rustc_flags.



<a id="extra_exec_rustc_flags"></a>

## extra_exec_rustc_flags

<pre>
--@rules_rust//rust/settings:extra_exec_rustc_flags
</pre>

This setting may be used to pass extra options to rustc from the command line in exec configuration.

It applies across all targets whereas the rustc_flags option on targets applies only
to that target. This can be useful for passing build-wide options such as LTO.



<a id="extra_rustc_flag"></a>

## extra_rustc_flag

<pre>
--@rules_rust//rust/settings:extra_rustc_flag
</pre>

Add additional rustc_flag from the command line with `--@rules_rust//rust/settings:extra_rustc_flag`.

Multiple uses are accumulated and appended after the `extra_rustc_flags`.



<a id="extra_rustc_flags"></a>

## extra_rustc_flags

<pre>
--@rules_rust//rust/settings:extra_rustc_flags
</pre>

This setting may be used to pass extra options to rustc from the command line in non-exec configuration.

It applies across all targets whereas the rustc_flags option on targets applies only
to that target. This can be useful for passing build-wide options such as LTO.



<a id="incompatible_change_rust_test_compilation_output_directory"></a>

## incompatible_change_rust_test_compilation_output_directory

<pre>
--@rules_rust//rust/settings:incompatible_change_rust_test_compilation_output_directory
</pre>

A flag to put rust_test compilation outputs in the same directory as the rust_library compilation outputs.



<a id="incompatible_do_not_include_data_in_compile_data"></a>

## incompatible_do_not_include_data_in_compile_data

<pre>
--@rules_rust//rust/settings:incompatible_do_not_include_data_in_compile_data
</pre>

A flag to control whether to include data files in compile_data.



<a id="lto"></a>

## lto

<pre>
--@rules_rust//rust/settings:lto
</pre>

A build setting which specifies the link time optimization mode used when building Rust code.



<a id="no_std"></a>

## no_std

<pre>
--@rules_rust//rust/settings:no_std
</pre>

This setting may be used to enable builds without the standard library.

Currently only no_std + alloc is supported, which can be enabled with setting the value to "alloc".
In the future we could add support for additional modes, e.g "core", "alloc,collections".



<a id="pipelined_compilation"></a>

## pipelined_compilation

<pre>
--@rules_rust//rust/settings:pipelined_compilation
</pre>

When set, this flag causes rustc to emit `*.rmeta` files and use them for `rlib -> rlib` dependencies.

While this involves one extra (short) rustc invocation to build the rmeta file,
it allows library dependencies to be unlocked much sooner, increasing parallelism during compilation.



<a id="rename_first_party_crates"></a>

## rename_first_party_crates

<pre>
--@rules_rust//rust/settings:rename_first_party_crates
</pre>

A flag controlling whether to rename first-party crates such that their names     encode the Bazel package and target name, instead of just the target name.

First-party vs. third-party crates are identified using the value of
`@rules_rust//settings:third_party_dir`.



<a id="rustc_output_diagnostics"></a>

## rustc_output_diagnostics

<pre>
--@rules_rust//rust/settings:rustc_output_diagnostics
</pre>

This setting may be changed from the command line to generate rustc diagnostics.



<a id="rustfmt_toml"></a>

## rustfmt_toml

<pre>
--@rules_rust//rust/settings:rustfmt_toml
</pre>

This setting is used by the rustfmt rules. See https://bazelbuild.github.io/rules_rust/rust_fmt.html

Note that this setting is actually called `rustfmt.toml`.



<a id="third_party_dir"></a>

## third_party_dir

<pre>
--@rules_rust//rust/settings:third_party_dir
</pre>

A flag specifying the location of vendored third-party rust crates within this     repository that must not be renamed when `rename_first_party_crates` is enabled.

Must be specified as a Bazel package, e.g. "//some/location/in/repo".



<a id="toolchain_generated_sysroot"></a>

## toolchain_generated_sysroot

<pre>
--@rules_rust//rust/settings:toolchain_generated_sysroot
</pre>

A flag to set rustc --sysroot flag to the sysroot generated by rust_toolchain.



<a id="unpretty"></a>

## unpretty

<pre>
--@rules_rust//rust/settings:unpretty
</pre>





<a id="use_real_import_macro"></a>

## use_real_import_macro

<pre>
--@rules_rust//rust/settings:use_real_import_macro
</pre>

A flag to control whether rust_library and rust_binary targets should     implicitly depend on the *real* import macro, or on a no-op target.



