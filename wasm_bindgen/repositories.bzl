# Copyright 2019 The Bazel Authors. All rights reserved.
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
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")
load("//crate_universe:defs.bzl", "crate", "crates_repository")

WASM_BINDGEN_VERSION = "0.2.78"

# buildifier: disable=unnamed-macro
def rust_wasm_bindgen_dependencies():
    """Declare dependencies needed for the `rules_rust` [wasm-bindgen][wb] rules.

    [wb]: https://github.com/rustwasm/wasm-bindgen
    """

    maybe(
        http_archive,
        name = "rules_rust_wasm_bindgen_cli",
        sha256 = "262a79690c18f5160ca109e839814783e29b71f1fd28448f80838145f93c08b6",
        urls = ["https://crates.io/api/v1/crates/wasm-bindgen-cli/{}/download".format(WASM_BINDGEN_VERSION)],
        type = "tar.gz",
        strip_prefix = "wasm-bindgen-cli-{}".format(WASM_BINDGEN_VERSION),
        build_file = Label("//wasm_bindgen/3rdparty:BUILD.wasm-bindgen-cli.bazel"),
    )

    maybe(
        http_archive,
        name = "rules_nodejs",
        sha256 = "26766278d815a6e2c43d2f6c9c72fde3fec8729e84138ffa4dabee47edc7702a",
        urls = ["https://github.com/bazelbuild/rules_nodejs/releases/download/5.4.2/rules_nodejs-core-5.4.2.tar.gz"],
    )

    crates_repository(
        name = "rules_rust_wasm_bindgen_crate_index",
        annotations = {
            "curl-sys": [crate.annotation(
                gen_build_script = False,
            )],
            "log": [crate.annotation(
                rustc_flags = [
                    "--cfg=atomic_cas",
                    "--cfg=use_std",
                ],
                version = "<5",
            )],
            "openssl-sys": [crate.annotation(
                gen_build_script = False,
                rustc_flags = [
                    # Vendored openssl is 1.0.2m
                    "--cfg=ossl101",
                    "--cfg=ossl102",
                    "--cfg=ossl102f",
                    "--cfg=ossl102h",
                    "--cfg=ossl110",
                    "--cfg=ossl110f",
                    "--cfg=ossl110g",
                    "--cfg=ossl111",
                    "--cfg=ossl111b",
                    "-l",
                    "dylib=ssl",
                    "-l",
                    "dylib=crypto",
                ],
            )],
            "proc-macro2": [crate.annotation(
                rustc_flags = ["--cfg=use_proc_macro"],
            )],
            "unicase": [crate.annotation(
                rustc_flags = [
                    "--cfg=__unicase__iter_cmp",
                    "--cfg=__unicase__defauler_hasher",
                ],
            )],
        },
        manifests = ["@rules_rust_wasm_bindgen_cli//:Cargo.toml"],
        packages = {
            "wasm-bindgen": crate.spec(
                version = WASM_BINDGEN_VERSION,
            ),
        },
        lockfile = "@rules_rust//wasm_bindgen:Cargo.Bazel.lock",
    )

# buildifier: disable=unnamed-macro
def rust_wasm_bindgen_register_toolchains(register_toolchains = True):
    """Registers the default toolchains for the `rules_rust` [wasm-bindgen][wb] rules.

    [wb]: https://github.com/rustwasm/wasm-bindgen

    Args:
        register_toolchains (bool, optional): Whether or not to register toolchains.
    """

    if register_toolchains:
        native.register_toolchains(str(Label("//wasm_bindgen:default_wasm_bindgen_toolchain")))

# buildifier: disable=unnamed-macro
def rust_wasm_bindgen_repositories(register_default_toolchain = True):
    """Declare dependencies needed for [rust_wasm_bindgen](#rust_wasm_bindgen).

    **Deprecated**: Use [rust_wasm_bindgen_dependencies](#rust_wasm_bindgen_depednencies) and [rust_wasm_bindgen_register_toolchains](#rust_wasm_bindgen_register_toolchains).

    Args:
        register_default_toolchain (bool, optional): If True, the default [rust_wasm_bindgen_toolchain](#rust_wasm_bindgen_toolchain)
            (`@rules_rust//wasm_bindgen:default_wasm_bindgen_toolchain`) is registered. This toolchain requires a set of dependencies
            that were generated using [cargo raze](https://github.com/google/cargo-raze). These will also be loaded.
    """

    rust_wasm_bindgen_dependencies()

    rust_wasm_bindgen_register_toolchains(register_toolchains = register_default_toolchain)
