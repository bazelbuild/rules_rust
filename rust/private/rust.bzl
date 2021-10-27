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

# buildifier: disable=module-docstring
load("//rust/private:common.bzl", "rust_common")
load("//rust/private:rustc.bzl", "rustc_compile_action")
load(
    "//rust/private:utils.bzl",
    "crate_name_from_attr",
    "dedent",
    "determine_output_hash",
    "expand_dict_value_locations",
    "find_toolchain",
    "transform_deps",
)

# TODO(marco): Separate each rule into its own file.

def _assert_no_deprecated_attributes(ctx):
    """Forces a failure if any deprecated attributes were specified

    Args:
        ctx (ctx): The current rule's context object
    """
    pass

def _assert_correct_dep_mapping(ctx):
    """Forces a failure if proc_macro_deps and deps are mixed inappropriately

    Args:
        ctx (ctx): The current rule's context object
    """
    for dep in ctx.attr.deps:
        if rust_common.crate_info in dep:
            if dep[rust_common.crate_info].type == "proc-macro":
                fail(
                    "{} listed {} in its deps, but it is a proc-macro. It should instead be in the bazel property proc_macro_deps.".format(
                        ctx.label,
                        dep.label,
                    ),
                )
    for dep in ctx.attr.proc_macro_deps:
        type = dep[rust_common.crate_info].type
        if type != "proc-macro":
            fail(
                "{} listed {} in its proc_macro_deps, but it is not proc-macro, it is a {}. It should probably instead be listed in deps.".format(
                    ctx.label,
                    dep.label,
                    type,
                ),
            )

def _determine_lib_name(name, crate_type, toolchain, lib_hash = ""):
    """See https://github.com/bazelbuild/rules_rust/issues/405

    Args:
        name (str): The name of the current target
        crate_type (str): The `crate_type`
        toolchain (rust_toolchain): The current `rust_toolchain`
        lib_hash (str, optional): The hashed crate root path. Defaults to "".

    Returns:
        str: A unique library name
    """
    extension = None
    prefix = ""
    if crate_type in ("dylib", "cdylib", "proc-macro"):
        extension = toolchain.dylib_ext
    elif crate_type == "staticlib":
        extension = toolchain.staticlib_ext
    elif crate_type in ("lib", "rlib"):
        # All platforms produce 'rlib' here
        extension = ".rlib"
        prefix = "lib"
    elif crate_type == "bin":
        fail("crate_type of 'bin' was detected in a rust_library. Please compile " +
             "this crate as a rust_binary instead.")

    if not extension:
        fail(("Unknown crate_type: {}. If this is a cargo-supported crate type, " +
              "please file an issue!").format(crate_type))

    prefix = "lib"
    if (toolchain.target_triple.find("windows") != -1) and crate_type not in ("lib", "rlib"):
        prefix = ""
    if toolchain.target_arch == "wasm32" and crate_type == "cdylib":
        prefix = ""

    return "{prefix}{name}-{lib_hash}{extension}".format(
        prefix = prefix,
        name = name,
        lib_hash = lib_hash,
        extension = extension,
    )

def get_edition(attr, toolchain):
    """Returns the Rust edition from either the current rule's attirbutes or the current `rust_toolchain`

    Args:
        attr (struct): The current rule's attributes
        toolchain (rust_toolchain): The `rust_toolchain` for the current target

    Returns:
        str: The target Rust edition
    """
    if getattr(attr, "edition"):
        return attr.edition
    else:
        return toolchain.default_edition

def crate_root_src(attr, srcs, crate_type):
    """Finds the source file for the crate root.

    Args:
        attr (struct): The attributes of the current target
        srcs (list): A list of all sources for the target Crate.
        crate_type (str): The type of this crate ("bin", "lib", "rlib", "cdylib", etc).

    Returns:
        File: The root File object for a given crate. See the following links for more details:
            - https://doc.rust-lang.org/cargo/reference/cargo-targets.html#library
            - https://doc.rust-lang.org/cargo/reference/cargo-targets.html#binaries
    """
    default_crate_root_filename = "main.rs" if crate_type == "bin" else "lib.rs"

    crate_root = None
    if hasattr(attr, "crate_root"):
        if attr.crate_root:
            crate_root = attr.crate_root.files.to_list()[0]

    if not crate_root:
        crate_root = (
            (srcs[0] if len(srcs) == 1 else None) or
            _shortest_src_with_basename(srcs, default_crate_root_filename) or
            _shortest_src_with_basename(srcs, attr.name + ".rs")
        )
    if not crate_root:
        file_names = [default_crate_root_filename, attr.name + ".rs"]
        fail("No {} source file found.".format(" or ".join(file_names)), "srcs")
    return crate_root

def _shortest_src_with_basename(srcs, basename):
    """Finds the shortest among the paths in srcs that match the desired basename.

    Args:
        srcs (list): A list of File objects
        basename (str): The target basename to match against.

    Returns:
        File: The File object with the shortest path that matches `basename`
    """
    shortest = None
    for f in srcs:
        if f.basename == basename:
            if not shortest or len(f.dirname) < len(shortest.dirname):
                shortest = f
    return shortest

def _rust_binary_impl(ctx):
    """The implementation of the `rust_binary` rule

    Args:
        ctx (ctx): The rule's context object

    Returns:
        list: A list of providers. See `rustc_compile_action`
    """
    toolchain = find_toolchain(ctx)
    crate_name = crate_name_from_attr(ctx.attr)
    _assert_correct_dep_mapping(ctx)

    output = ctx.actions.declare_file(ctx.label.name + toolchain.binary_ext)

    make_rust_providers_target_independent = toolchain._incompatible_make_rust_providers_target_independent
    deps = transform_deps(ctx.attr.deps, make_rust_providers_target_independent)
    proc_macro_deps = transform_deps(ctx.attr.proc_macro_deps, make_rust_providers_target_independent)

    return rustc_compile_action(
        ctx = ctx,
        attr = ctx.attr,
        toolchain = toolchain,
        crate_info = rust_common.create_crate_info(
            name = crate_name,
            type = ctx.attr.crate_type,
            root = crate_root_src(ctx.attr, ctx.files.srcs, ctx.attr.crate_type),
            srcs = depset(ctx.files.srcs),
            deps = depset(deps),
            proc_macro_deps = depset(proc_macro_deps),
            aliases = ctx.attr.aliases,
            output = output,
            edition = get_edition(ctx.attr, toolchain),
            rustc_env = ctx.attr.rustc_env,
            is_test = False,
            compile_data = depset(ctx.files.compile_data),
            owner = ctx.label,
        ),
    )

def _create_test_launcher(ctx, toolchain, output, env, providers):
    """Create a process wrapper to ensure runtime environment variables are defined for the test binary

    Args:
        ctx (ctx): The rule's context object
        toolchain (rust_toolchain): The current rust toolchain
        output (File): The output File that will be produced, depends on crate type.
        env (dict): Dict of environment variables
        providers (list): Providers from a rust compile action. See `rustc_compile_action`

    Returns:
        list: A list of providers similar to `rustc_compile_action` but with modified default info
    """

    # TODO: It's unclear if the toolchain is in the same configuration as the `_launcher` attribute
    # This should be investigated but for now, we generally assume if the target environment is windows,
    # the execution environment is windows.
    if toolchain.os == "windows":
        launcher_filename = ctx.label.name + ".launcher.exe"
    else:
        launcher_filename = ctx.label.name + ".launcher"

    launcher = ctx.actions.declare_file(launcher_filename)

    # Because returned executables must be created from the same rule, the
    # launcher target is simply symlinked and exposed.
    ctx.actions.symlink(
        output = launcher,
        target_file = ctx.executable._launcher,
        is_executable = True,
    )

    # Expand the environment variables and write them to a file
    environ_file = ctx.actions.declare_file(launcher_filename + ".launchfiles/env")

    # Convert the environment variables into a list to be written into a file.
    environ_list = []
    for key, value in sorted(env.items()):
        environ_list.extend([key, value])

    ctx.actions.write(
        output = environ_file,
        content = "\n".join(environ_list),
    )

    launcher_files = [environ_file]

    # Replace the `DefaultInfo` provider in the returned list
    default_info = None
    for i in range(len(providers)):
        if type(providers[i]) == "DefaultInfo":
            default_info = providers[i]
            providers.pop(i)
            break

    if not default_info:
        fail("No DefaultInfo provider returned from `rustc_compile_action`")

    providers.extend([
        DefaultInfo(
            files = default_info.files,
            runfiles = default_info.default_runfiles.merge(
                # The output is now also considered a runfile
                ctx.runfiles(files = launcher_files + [output]),
            ),
            executable = launcher,
        ),
        OutputGroupInfo(
            launcher_files = depset(launcher_files),
            output = depset([output]),
        ),
    ])

    return providers

def _rust_test_common(ctx, toolchain, output):
    """Builds a Rust test binary.

    Args:
        ctx (ctx): The ctx object for the current target.
        toolchain (rust_toolchain): The current `rust_toolchain`
        output (File): The output File that will be produced, depends on crate type.

    Returns:
        list: The list of providers. See `rustc_compile_action`
    """
    _assert_no_deprecated_attributes(ctx)
    _assert_correct_dep_mapping(ctx)

    crate_name = crate_name_from_attr(ctx.attr)
    crate_type = "bin"

    make_rust_providers_target_independent = toolchain._incompatible_make_rust_providers_target_independent
    deps = transform_deps(ctx.attr.deps, make_rust_providers_target_independent)
    proc_macro_deps = transform_deps(ctx.attr.proc_macro_deps, make_rust_providers_target_independent)

    if ctx.attr.crate:
        # Target is building the crate in `test` config
        crate = ctx.attr.crate[rust_common.crate_info]

        # Optionally join compile data
        if crate.compile_data:
            compile_data = depset(ctx.files.compile_data, transitive = [crate.compile_data])
        else:
            compile_data = depset(ctx.files.compile_data)

        # Build the test binary using the dependency's srcs.
        crate_info = rust_common.create_crate_info(
            name = crate_name,
            type = crate_type,
            root = crate.root,
            srcs = depset(ctx.files.srcs, transitive = [crate.srcs]),
            deps = depset(deps, transitive = [crate.deps]),
            proc_macro_deps = depset(proc_macro_deps, transitive = [crate.proc_macro_deps]),
            aliases = ctx.attr.aliases,
            output = output,
            edition = crate.edition,
            rustc_env = ctx.attr.rustc_env,
            is_test = True,
            compile_data = compile_data,
            wrapped_crate_type = crate.type,
            owner = ctx.label,
        )
    else:
        # Target is a standalone crate. Build the test binary as its own crate.
        crate_info = rust_common.create_crate_info(
            name = crate_name,
            type = crate_type,
            root = crate_root_src(ctx.attr, ctx.files.srcs, "lib"),
            srcs = depset(ctx.files.srcs),
            deps = depset(deps),
            proc_macro_deps = depset(proc_macro_deps),
            aliases = ctx.attr.aliases,
            output = output,
            edition = get_edition(ctx.attr, toolchain),
            rustc_env = ctx.attr.rustc_env,
            is_test = True,
            compile_data = depset(ctx.files.compile_data),
            owner = ctx.label,
        )

    providers = rustc_compile_action(
        ctx = ctx,
        attr = ctx.attr,
        toolchain = toolchain,
        crate_info = crate_info,
        rust_flags = ["--test"] if ctx.attr.use_libtest_harness else ["--cfg", "test"],
    )
    data = getattr(ctx.attr, "data", [])

    env = expand_dict_value_locations(
        ctx,
        getattr(ctx.attr, "env", {}),
        data,
    )
    providers.append(testing.TestEnvironment(env))

    if any(["{pwd}" in v for v in env.values()]):
        # Some of the environment variables require expanding {pwd} placeholder at runtime,
        # we need a launcher for that.
        return _create_test_launcher(ctx, toolchain, output, env, providers)
    else:
        return providers

def _rust_test_impl(ctx):
    """The implementation of the `rust_test` rule

    Args:
        ctx (ctx): The rule's context object

    Returns:
        list: A list of providers. See `_rust_test_common`
    """
    toolchain = find_toolchain(ctx)

    output = ctx.actions.declare_file(
        ctx.label.name + toolchain.binary_ext,
    )

    return _rust_test_common(ctx, toolchain, output)

_common_attrs = {
    "aliases": attr.label_keyed_string_dict(
        doc = dedent("""\
            Remap crates to a new name or moniker for linkage to this target

            These are other `rust_library` targets and will be presented as the new name given.
        """),
    ),
    "compile_data": attr.label_list(
        doc = dedent("""\
            List of files used by this rule at compile time.

            This attribute can be used to specify any data files that are embedded into
            the library, such as via the
            [`include_str!`](https://doc.rust-lang.org/std/macro.include_str!.html)
            macro.
        """),
        allow_files = True,
    ),
    "crate_features": attr.string_list(
        doc = dedent("""\
            List of features to enable for this crate.

            Features are defined in the code using the `#[cfg(feature = "foo")]`
            configuration option. The features listed here will be passed to `rustc`
            with `--cfg feature="${feature_name}"` flags.
        """),
    ),
    "crate_name": attr.string(
        doc = dedent("""\
            Crate name to use for this target.

            This must be a valid Rust identifier, i.e. it may contain only alphanumeric characters and underscores.
            Defaults to the target name, with any hyphens replaced by underscores.
        """),
    ),
    "crate_root": attr.label(
        doc = dedent("""\
            The file that will be passed to `rustc` to be used for building this crate.

            If `crate_root` is not set, then this rule will look for a `lib.rs` file (or `main.rs` for rust_binary)
            or the single file in `srcs` if `srcs` contains only one file.
        """),
        allow_single_file = [".rs"],
    ),
    "data": attr.label_list(
        doc = dedent("""\
            List of files used by this rule at compile time and runtime.

            If including data at compile time with include_str!() and similar,
            prefer `compile_data` over `data`, to prevent the data also being included
            in the runfiles.
        """),
        allow_files = True,
    ),
    "deps": attr.label_list(
        doc = dedent("""\
            List of other libraries to be linked to this library target.

            These can be either other `rust_library` targets or `cc_library` targets if
            linking a native library.
        """),
    ),
    "edition": attr.string(
        doc = "The rust edition to use for this crate. Defaults to the edition specified in the rust_toolchain.",
    ),
    # Previously `proc_macro_deps` were a part of `deps`, and then proc_macro_host_transition was
    # used into cfg="host" using `@local_config_platform//:host`.
    # This fails for remote execution, which needs cfg="exec", and there isn't anything like
    # `@local_config_platform//:exec` exposed.
    "proc_macro_deps": attr.label_list(
        doc = dedent("""\
            List of `rust_library` targets with kind `proc-macro` used to help build this library target.
        """),
        cfg = "exec",
        providers = [rust_common.crate_info],
    ),
    "rustc_env": attr.string_dict(
        doc = dedent("""\
            Dictionary of additional `"key": "value"` environment variables to set for rustc.

            rust_test()/rust_binary() rules can use $(rootpath //package:target) to pass in the
            location of a generated file or external tool. Cargo build scripts that wish to
            expand locations should use cargo_build_script()'s build_script_env argument instead,
            as build scripts are run in a different environment - see cargo_build_script()'s
            documentation for more.
        """),
    ),
    "rustc_env_files": attr.label_list(
        doc = dedent("""\
            Files containing additional environment variables to set for rustc.

            These files should  contain a single variable per line, of format
            `NAME=value`, and newlines may be included in a value by ending a
            line with a trailing back-slash (`\\`).

            The order that these files will be processed is unspecified, so
            multiple definitions of a particular variable are discouraged.
        """),
        allow_files = True,
    ),
    "rustc_flags": attr.string_list(
        doc = dedent("""\
            List of compiler flags passed to `rustc`.

            These strings are subject to Make variable expansion for predefined
            source/output path variables like `$location`, `$execpath`, and `$rootpath`.
            This expansion is useful if you wish to pass a generated file of
            arguments to rustc: `@$(location //package:target)`.
        """),
    ),
    # TODO(stardoc): How do we provide additional documentation to an inherited attribute?
    # "name": attr.string(
    #     doc = "This name will also be used as the name of the crate built by this rule.",
    # `),
    "srcs": attr.label_list(
        doc = dedent("""\
            List of Rust `.rs` source files used to build the library.

            If `srcs` contains more than one file, then there must be a file either
            named `lib.rs`. Otherwise, `crate_root` must be set to the source file that
            is the root of the crate to be passed to rustc to build this crate.
        """),
        allow_files = [".rs"],
    ),
    "version": attr.string(
        doc = "A version to inject in the cargo environment variable.",
        default = "0.0.0",
    ),
    "_cc_toolchain": attr.label(
        default = "@bazel_tools//tools/cpp:current_cc_toolchain",
    ),
    "_error_format": attr.label(default = "//:error_format"),
    "_extra_rustc_flags": attr.label(default = "//:extra_rustc_flags"),
    "_process_wrapper": attr.label(
        default = Label("//util/process_wrapper"),
        executable = True,
        allow_single_file = True,
        cfg = "exec",
    ),
}

_rust_test_attrs = {
    "crate": attr.label(
        mandatory = False,
        doc = dedent("""\
            Target inline tests declared in the given crate

            These tests are typically those that would be held out under
            `#[cfg(test)]` declarations.
        """),
    ),
    "env": attr.string_dict(
        mandatory = False,
        doc = dedent("""\
            Specifies additional environment variables to set when the test is executed by bazel test.
            Values are subject to `$(rootpath)`, `$(execpath)`, location, and
            ["Make variable"](https://docs.bazel.build/versions/master/be/make-variables.html) substitution.

            Execpath returns absolute path, and in order to be able to construct the absolute path we
            need to wrap the test binary in a launcher. Using a launcher comes with complications, such as
            more complicated debugger attachment.
        """),
    ),
    "use_libtest_harness": attr.bool(
        mandatory = False,
        default = True,
        doc = dedent("""\
            Whether to use libtest.
        """),
    ),
    "_grep_includes": attr.label(
        allow_single_file = True,
        cfg = "host",
        default = Label("@bazel_tools//tools/cpp:grep-includes"),
        executable = True,
    ),
    "_launcher": attr.label(
        executable = True,
        default = Label("//util/launcher:launcher"),
        cfg = "exec",
        doc = dedent("""\
            A launcher executable for loading environment and argument files passed in via the `env` attribute
            and ensuring the variables are set for the underlying test executable.
        """),
    ),
}

_common_providers = [
    rust_common.crate_info,
    rust_common.dep_info,
    DefaultInfo,
]
ProvidedFunctionInfo = provider(fields = {"fn": ""})

def _rust_library_like_impl(ctx):
    """The common implementation of the library-like rules.

    Args:
        ctx (ctx): The rule's context object
        crate_type (String): one of lib|rlib|dylib|staticlib|cdylib|proc-macro

    Returns:
        list: A list of providers. See `rustc_compile_action`
    """

    # Find lib.rs
    crate_root = crate_root_src(ctx.attr, ctx.files.srcs, "lib")
    crate_type = ctx.attr._crate_type
    _assert_no_deprecated_attributes(ctx)
    _assert_correct_dep_mapping(ctx)

    toolchain = find_toolchain(ctx)

    # Determine unique hash for this rlib
    output_hash = determine_output_hash(crate_root)

    crate_name = crate_name_from_attr(ctx.attr)
    rust_lib_name = _determine_lib_name(
        crate_name,
        crate_type,
        toolchain,
        output_hash,
    )
    rust_lib = ctx.actions.declare_file(rust_lib_name)

    transform_deps_fn = ctx.attr._transform_deps_fn[ProvidedFunctionInfo].fn

    make_rust_providers_target_independent = toolchain._incompatible_make_rust_providers_target_independent
    deps = transform_deps_fn(ctx.attr.deps, make_rust_providers_target_independent)
    proc_macro_deps = transform_deps_fn(ctx.attr.proc_macro_deps, make_rust_providers_target_independent)

    return rustc_compile_action(
        ctx = ctx,
        attr = ctx.attr,
        toolchain = toolchain,
        crate_info = rust_common.create_crate_info(
            name = crate_name,
            type = crate_type,
            root = crate_root,
            srcs = depset(ctx.files.srcs),
            deps = depset(deps),
            proc_macro_deps = depset(proc_macro_deps),
            aliases = ctx.attr.aliases,
            output = rust_lib,
            edition = get_edition(ctx.attr, toolchain),
            rustc_env = ctx.attr.rustc_env,
            is_test = False,
            compile_data = depset(ctx.files.compile_data),
            owner = ctx.label,
        ),
        output_hash = output_hash,
    )


def _transform_deps_fn_impl(ctx):
    return [ProvidedFunctionInfo(fn = transform_deps)]

transform_deps_fn = rule(
    implementation = _transform_deps_fn_impl,
    provides = [ProvidedFunctionInfo]
)

def _rust_library_like_rule(crate_type, doc, extra_attrs = {}, transform_deps_fn = transform_deps):
    return rule(
        implementation = _rust_library_like_impl,
        provides = _common_providers,
        attrs = dict(
            _common_attrs.items() + extra_attrs.items() + {
                "_crate_type": attr.string(default = crate_type),
                "_transform_deps_fn": attr.label(default = "//rust/private:transform_deps_fn")
            }.items(),
        ),
        fragments = ["cpp"],
        host_fragments = ["cpp"],
        toolchains = [
            str(Label("//rust:toolchain")),
            "@bazel_tools//tools/cpp:toolchain_type",
        ],
        incompatible_use_toolchain_transition = True,
        doc = dedent(doc),
    )

rust_library = _rust_library_like_rule(
    "rlib",
    """\
        Builds a Rust library crate.

        Example:

        Suppose you have the following directory structure for a simple Rust library crate:

        ```output
        [workspace]/
            WORKSPACE
            hello_lib/
                BUILD
                src/
                    greeter.rs
                    lib.rs
        ```

        `hello_lib/src/greeter.rs`:
        ```rust
        pub struct Greeter {
            greeting: String,
        }

        impl Greeter {
            pub fn new(greeting: &str) -> Greeter {
                Greeter { greeting: greeting.to_string(), }
            }

            pub fn greet(&self, thing: &str) {
                println!("{} {}", &self.greeting, thing);
            }
        }
        ```

        `hello_lib/src/lib.rs`:

        ```rust
        pub mod greeter;
        ```

        `hello_lib/BUILD`:
        ```python
        package(default_visibility = ["//visibility:public"])

        load("@rules_rust//rust:rust.bzl", "rust_library")

        rust_library(
            name = "hello_lib",
            srcs = [
                "src/greeter.rs",
                "src/lib.rs",
            ],
        )
        ```

        Build the library:
        ```output
        $ bazel build //hello_lib
        INFO: Found 1 target...
        Target //examples/rust/hello_lib:hello_lib up-to-date:
        bazel-bin/examples/rust/hello_lib/libhello_lib.rlib
        INFO: Elapsed time: 1.245s, Critical Path: 1.01s
        ```
        """,
)

rust_static_library = _rust_library_like_rule(
    "staticlib",
    """\
        Builds a Rust static library.

        This static library will contain all transitively reachable crates and native objects.
        It is meant to be used when producing an artifact that is then consumed by some other build system
        (for example to produce an archive that Python program links against).

        This rule provides CcInfo, so it can be used everywhere Bazel expects `rules_cc`.

        When building the whole binary in Bazel, use `rust_library` instead.
        """,
)

rust_shared_library = _rust_library_like_rule(
    "cdylib",
    """"\
        Builds a Rust shared library.

        This shared library will contain all transitively reachable crates and native objects.
        It is meant to be used when producing an artifact that is then consumed by some other build system
        (for example to produce a shared library that Python program links against).

        This rule provides CcInfo, so it can be used everywhere Bazel expects `rules_cc`.

        When building the whole binary in Bazel, use `rust_library` instead.
        """,
)

rust_proc_macro = _rust_library_like_rule(
    "proc-macro",
    """\
        Builds a Rust proc-macro crate.
        """,
)

_rust_binary_attrs = {
    "crate_type": attr.string(
        doc = dedent("""\
            Crate type that will be passed to `rustc` to be used for building this crate.

            This option is a temporary workaround and should be used only when building
            for WebAssembly targets (//rust/platform:wasi and //rust/platform:wasm).
        """),
        default = "bin",
    ),
    "linker_script": attr.label(
        doc = dedent("""\
            Link script to forward into linker via rustc options.
        """),
        cfg = "exec",
        allow_single_file = True,
    ),
    "out_binary": attr.bool(
        doc = (
            "Force a target, regardless of it's `crate_type`, to always mark the " +
            "file as executable. This attribute is only used to support wasm targets but is " +
            "expected to be removed following a resolution to https://github.com/bazelbuild/rules_rust/issues/771."
        ),
        default = False,
    ),
    "stamp": attr.int(
        doc = dedent("""\
            Embed additional information into the binaries.

            By default stamping is controlled by the --stamp flag.
            See https://docs.bazel.build/versions/main/user-manual.html#workspace_status
            and https://docs.bazel.build/versions/main/user-manual.html#flag--stamp.
        """),
        default = -1,
    ),
    "_grep_includes": attr.label(
        allow_single_file = True,
        cfg = "host",
        default = Label("@bazel_tools//tools/cpp:grep-includes"),
        executable = True,
    ),
}

rust_binary = rule(
    implementation = _rust_binary_impl,
    provides = _common_providers,
    attrs = dict(_common_attrs.items() + _rust_binary_attrs.items()),
    executable = True,
    fragments = ["cpp"],
    host_fragments = ["cpp"],
    toolchains = [
        str(Label("//rust:toolchain")),
        "@bazel_tools//tools/cpp:toolchain_type",
    ],
    incompatible_use_toolchain_transition = True,
    doc = dedent("""\
        Builds a Rust binary crate.

        Example:

        Suppose you have the following directory structure for a Rust project with a
        library crate, `hello_lib`, and a binary crate, `hello_world` that uses the
        `hello_lib` library:

        ```output
        [workspace]/
            WORKSPACE
            hello_lib/
                BUILD
                src/
                    lib.rs
            hello_world/
                BUILD
                src/
                    main.rs
        ```

        `hello_lib/src/lib.rs`:
        ```rust
        pub struct Greeter {
            greeting: String,
        }

        impl Greeter {
            pub fn new(greeting: &str) -> Greeter {
                Greeter { greeting: greeting.to_string(), }
            }

            pub fn greet(&self, thing: &str) {
                println!("{} {}", &self.greeting, thing);
            }
        }
        ```

        `hello_lib/BUILD`:
        ```python
        package(default_visibility = ["//visibility:public"])

        load("@rules_rust//rust:rust.bzl", "rust_library")

        rust_library(
            name = "hello_lib",
            srcs = ["src/lib.rs"],
        )
        ```

        `hello_world/src/main.rs`:
        ```rust
        extern crate hello_lib;

        fn main() {
            let hello = hello_lib::Greeter::new("Hello");
            hello.greet("world");
        }
        ```

        `hello_world/BUILD`:
        ```python
        load("@rules_rust//rust:rust.bzl", "rust_binary")

        rust_binary(
            name = "hello_world",
            srcs = ["src/main.rs"],
            deps = ["//hello_lib"],
        )
        ```

        Build and run `hello_world`:
        ```
        $ bazel run //hello_world
        INFO: Found 1 target...
        Target //examples/rust/hello_world:hello_world up-to-date:
        bazel-bin/examples/rust/hello_world/hello_world
        INFO: Elapsed time: 1.308s, Critical Path: 1.22s

        INFO: Running command line: bazel-bin/examples/rust/hello_world/hello_world
        Hello world
        ```
"""),
)

rust_test = rule(
    implementation = _rust_test_impl,
    provides = _common_providers,
    attrs = dict(_common_attrs.items() +
                 _rust_test_attrs.items()),
    executable = True,
    fragments = ["cpp"],
    host_fragments = ["cpp"],
    test = True,
    toolchains = [
        str(Label("//rust:toolchain")),
        "@bazel_tools//tools/cpp:toolchain_type",
    ],
    incompatible_use_toolchain_transition = True,
    doc = dedent("""\
        Builds a Rust test crate.

        Examples:

        Suppose you have the following directory structure for a Rust library crate \
        with unit test code in the library sources:

        ```output
        [workspace]/
            WORKSPACE
            hello_lib/
                BUILD
                src/
                    lib.rs
        ```

        `hello_lib/src/lib.rs`:
        ```rust
        pub struct Greeter {
            greeting: String,
        }

        impl Greeter {
            pub fn new(greeting: &str) -> Greeter {
                Greeter { greeting: greeting.to_string(), }
            }

            pub fn greet(&self, thing: &str) -> String {
                format!("{} {}", &self.greeting, thing)
            }
        }

        #[cfg(test)]
        mod test {
            use super::Greeter;

            #[test]
            fn test_greeting() {
                let hello = Greeter::new("Hi");
                assert_eq!("Hi Rust", hello.greet("Rust"));
            }
        }
        ```

        To build and run the tests, simply add a `rust_test` rule with no `srcs` and \
        only depends on the `hello_lib` `rust_library` target:

        `hello_lib/BUILD`:
        ```python
        package(default_visibility = ["//visibility:public"])

        load("@rules_rust//rust:defs.bzl", "rust_library", "rust_test")

        rust_library(
            name = "hello_lib",
            srcs = ["src/lib.rs"],
        )

        rust_test(
            name = "hello_lib_test",
            deps = [":hello_lib"],
        )
        ```

        Run the test with `bazel build //hello_lib:hello_lib_test`.

        To run a crate or lib with the `#[cfg(test)]` configuration, handling inline \
        tests, you should specify the crate directly like so.

        ```python
        rust_test(
            name = "hello_lib_test",
            crate = ":hello_lib",
            # You may add other deps that are specific to the test configuration
            deps = ["//some/dev/dep"],
        )
        ```

        ### Example: `test` directory

        Integration tests that live in the [`tests` directory][int-tests], they are \
        essentially built as separate crates. Suppose you have the following directory \
        structure where `greeting.rs` is an integration test for the `hello_lib` \
        library crate:

        [int-tests]: http://doc.rust-lang.org/book/testing.html#the-tests-directory

        ```output
        [workspace]/
            WORKSPACE
            hello_lib/
                BUILD
                src/
                    lib.rs
                tests/
                    greeting.rs
        ```

        `hello_lib/tests/greeting.rs`:
        ```rust
        extern crate hello_lib;

        use hello_lib;

        #[test]
        fn test_greeting() {
            let hello = greeter::Greeter::new("Hello");
            assert_eq!("Hello world", hello.greeting("world"));
        }
        ```

        To build the `greeting.rs` integration test, simply add a `rust_test` target
        with `greeting.rs` in `srcs` and a dependency on the `hello_lib` target:

        `hello_lib/BUILD`:
        ```python
        package(default_visibility = ["//visibility:public"])

        load("@rules_rust//rust:defs.bzl", "rust_library", "rust_test")

        rust_library(
            name = "hello_lib",
            srcs = ["src/lib.rs"],
        )

        rust_test(
            name = "greeting_test",
            srcs = ["tests/greeting.rs"],
            deps = [":hello_lib"],
        )
        ```

        Run the test with `bazel build //hello_lib:hello_lib_test`.
"""),
)

def rust_test_suite(name, srcs, **kwargs):
    """A rule for creating a test suite for a set of `rust_test` targets.

    This rule can be used for setting up typical rust [integration tests][it]. Given the following
    directory structure:

    ```text
    [crate]/
        BUILD.bazel
        src/
            lib.rs
            main.rs
        tests/
            integrated_test_a.rs
            integrated_test_b.rs
            integrated_test_c.rs
            patterns/
                fibonacci_test.rs
    ```

    The rule can be used to generate [rust_test](#rust_test) targets for each source file under `tests`
    and a [test_suite][ts] which encapsulates all tests.

    ```python
    load("//rust:defs.bzl", "rust_binary", "rust_library", "rust_test_suite")

    rust_library(
        name = "math_lib",
        srcs = ["src/lib.rs"],
    )

    rust_binary(
        name = "math_bin",
        srcs = ["src/main.rs"],
    )

    rust_test_suite(
        name = "integrated_tests_suite",
        srcs = glob(["tests/**"]),
        deps = [":math_lib"],
    )
    ```

    [it]: https://doc.rust-lang.org/rust-by-example/testing/integration_testing.html
    [ts]: https://docs.bazel.build/versions/master/be/general.html#test_suite

    Args:
        name (str): The name of the `test_suite`.
        srcs (list): All test sources, typically `glob(["tests/**/*.rs"])`.
        **kwargs (dict): Additional keyword arguments for the underyling [rust_test](#rust_test) targets. The
            `tags` argument is also passed to the generated `test_suite` target.
    """
    tests = []

    for src in srcs:
        if not src.endswith(".rs"):
            fail("srcs should have `.rs` extensions")

        # Prefixed with `name` to allow parameterization with macros
        # The test name should not end with `.rs`
        test_name = name + "_" + src[:-3]
        rust_test(
            name = test_name,
            crate_name = test_name.replace("/", "_"),
            srcs = [src],
            **kwargs
        )
        tests.append(test_name)

    native.test_suite(
        name = name,
        tests = tests,
        tags = kwargs.get("tags", None),
    )
