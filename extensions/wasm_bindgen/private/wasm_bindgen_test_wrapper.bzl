"""wasm_bindgen_test_wrapper"""

load(
    ":wasm_bindgen_test.bzl",
    "rust_wasm_bindgen_test_binary",
    _rust_wasm_bindgen_test = "rust_wasm_bindgen_test",
)

def rust_wasm_bindgen_test(
        *,
        name,
        aliases = {},
        compile_data = [],
        crate_features = [],
        data = [],
        edition = None,
        env = {},
        env_inherit = [],
        proc_macro_deps = [],
        rustc_env = {},
        rustc_env_files = [],
        rustc_flags = [],
        target_arch = None,
        version = "0.0.0",
        wasm = None,
        tags = [],
        **kwargs):
    """"A test rule for running [wasm-bindgen tests](https://rustwasm.github.io/wasm-bindgen/wasm-bindgen-test/index.html)."

    Args:
        name (str): A unique name for this target.
        aliases (dict, optional): Remap crates to a new name or moniker for linkage to this target.
        compile_data (list, optional): List of files used by this rule at compile time.
        crate_features (list, optional): List of features to enable for this crate.
        data (list, optional): List of files used by this rule at compile time and runtime.
        edition (str, optional): The rust edition to use for this crate. Defaults to the edition specified in the rust_toolchain.
        env (dict, optional): Specifies additional environment variables to set when the test is executed by bazel test.
        env_inherit (list, optional): Specifies additional environment variables to inherit from the external environment when the test is executed by bazel test.
        proc_macro_deps (list, optional): List of `rust_proc_macro` targets used to help build this library target.
        rustc_env (dict, optional): Dictionary of additional `"key": "value"` environment variables to set for rustc.
        rustc_env_files (list, optional): Files containing additional environment variables to set for rustc.
        rustc_flags (list, optional): List of compiler flags passed to `rustc`.
        target_arch (str, optional): The target architecture to use for the wasm-bindgen command line option.
        version (str, optional): A version to inject in the cargo environment variable.
        wasm (Label, optional): The wasm target to test.
        tags (list, optional): Tags to apply to the target.
        **kwargs (dict): Additional keyword arguments.
    """
    visibility = kwargs.pop("visibility", [])

    # Create a test binary for `wasm-bindgen-test-runner` to invoke.
    # Ideally this target would be produced within the `wasm_bindgen_test`
    # rule directly but the design of that rule is to consume wasm files
    # and run a test on the target environment.
    rust_wasm_bindgen_test_binary(
        name = name + ".bin",
        aliases = aliases,
        compile_data = compile_data,
        crate_features = crate_features,
        data = data,
        edition = edition,
        env = env,
        env_inherit = env_inherit,
        proc_macro_deps = proc_macro_deps,
        rustc_env = rustc_env,
        rustc_env_files = rustc_env_files,
        rustc_flags = rustc_flags,
        version = version,
        wasm = wasm,
        tags = depset(tags + ["manual"]).to_list(),
        visibility = ["//visibility:private"],
        target_compatible_with = select({
            "@platforms//cpu:wasm32": [],
            "@platforms//cpu:wasm64": [],
            "//conditions:default": ["@platforms//:incompatible"],
        }),
        **kwargs
    )

    _rust_wasm_bindgen_test(
        name = name,
        wasm = name + ".bin",
        target_arch = target_arch,
        tags = tags,
        env = env,
        visibility = visibility,
        **kwargs
    )
