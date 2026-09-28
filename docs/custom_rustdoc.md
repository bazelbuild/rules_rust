# Custom rustdoc actions

Load `rustdoc_compile_action` from `@rules_rust//rust:rust_doc.bzl` to prepare a
rustdoc invocation using the same dependency, native-linker, build-script, lint,
and toolchain handling as `rust_doc` and `rust_doc_test`. It returns action fields;
the caller registers the action and supplies its declared outputs.

The calling rule must declare:

- The `@rules_rust//rust:toolchain_type` toolchain and the `cpp` fragment.
- The optional `@bazel_tools//tools/cpp:toolchain_type` toolchain, using
  `config_common.toolchain_type(..., mandatory = False)`.
- An executable `_process_wrapper` label attribute, defaulting to
  `Label("@rules_rust//util/process_wrapper")`, with `cfg = "exec"`.
- An `_error_format` label attribute defaulting to
  `Label("@rules_rust//rust/settings:error_format")`.

Pass a configured `CrateInfo` and the resolved Rust toolchain. An optional
`LintsInfo` supplies rustdoc lint flags and files. `rustdoc_flags` is an Args object
that the helper may extend; omitting it creates a fresh Args object. For generated
HTML, pass a declared output directory as `output`. The output must also appear in
the caller's action outputs. For build-time doctest compilation, use
`force_depend_on_objects = True` and add the required rustdoc test flags yourself.
Nightly-only rustdoc options still require a nightly toolchain.

The returned struct contains:

| Field | Type and use |
| --- | --- |
| `executable` | Process-wrapper File for `ctx.actions.run` |
| `inputs` | depset of compiler, crate, dependency, build-script and customization files |
| `env` | Compiler environment, including process-wrapper substitutions |
| `arguments` | Ordered list of Args objects for the wrapper and rustdoc |
| `tools` | Additional executable tool inputs |
| `supports_path_mapping` | Whether the action may declare `supports-path-mapping` |
| `static_runtime_libs` | C++ runtime files for callers constructing test runfiles |

`is_test = True` selects the legacy runfiles-based invocation: rustdoc and sysroot
paths use runfiles-relative locations. Leave it false for an action that compiles
doctests during the build. The helper does not translate a build-time invocation
into a target-platform test runner or declare that runner's runfiles.

`LintsInfo` and `transform_deps` are exported from
`@rules_rust//rust:rust_common.bzl`. `LintsInfo` is the same provider emitted by
standard rules. `transform_deps` preserves the order and identity of providers
from configured targets, filling absent provider fields with None. It does not
apply transitions: declare procedural-macro dependencies with `cfg = "exec"`
and store their converted results separately from normal dependencies when
constructing `CrateInfo` with `rust_common.create_crate_info`.

A working example is `//test/unit/public_rustdoc:custom`. Its rule loads only
public entry points and registers a native build-time doctest action. The fixture
compiles a normal dependency and procedural macro, checks provider conversion,
and runs the documented example with the crate's lint configuration. Custom
cross-platform runners must compile without running in that action and execute
the resulting tests on their target platform.
