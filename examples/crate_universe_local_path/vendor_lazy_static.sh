#!/bin/bash

set -eou pipefail
set -x

cd "${BUILD_WORKSPACE_DIRECTORY}"

if [[ "$#" -eq 0 ]]; then
    copy_to="$(mktemp -d)"
    path_dep_path="${copy_to}"
elif [[ "$#" -eq 1 ]]; then
    path_dep_path="$1"
    copy_to="crates_from_workspace/$1"
    mkdir -p "${copy_to}"
    sed_i=(sed -i)
    if [[ "$(uname)" == "Darwin" ]]; then
      sed_i=(sed -i '')
    fi
    "${sed_i[@]}" -e 's#manifests = \["//crates_from_workspace:Cargo\.toml"\],#manifests = ["//crates_from_workspace:Cargo.toml", "//crates_from_workspace:'"$1"'/Cargo.toml"],#g' WORKSPACE.bazel
    "${sed_i[@]}" -e 's#manifests = \["//crates_from_workspace:Cargo\.toml"\],#manifests = ["//crates_from_workspace:Cargo.toml", "//crates_from_workspace:'"$1"'/Cargo.toml"],#g' MODULE.bazel
else
    echo >&2 "Usage: $0 [/path/to/copy/to]"
    echo >&2 "If no arg is passed, a tempdir will be created"
    exit 1
fi

cp -r "lazy_static_1.5.0_copy/"* "${copy_to}/"

echo "pub const VENDORED_BY: &'static str = \"rules_rust\";" >> "${copy_to}/src/lib.rs"

cargo_toml_to_update="crates_from_workspace/Cargo.toml"
workspace_bazel_to_update="WORKSPACE.bazel"
module_bazel_to_update="MODULE.bazel"
echo "lazy_static = { path = \"${path_dep_path}\" }" >> "${cargo_toml_to_update}"
sed -i -e "s|\"lazy_static\": crate.spec(version = \"1.5.0\")|\"lazy_static\": crate.spec(path = \"${copy_to}\")|" "${workspace_bazel_to_update}"
sed -i -e "s|version = \"1.5.0\",  # lazy_static|path = \"${copy_to}\",  # lazy_static|" "${module_bazel_to_update}"

echo "Copied to ${copy_to}, updated ${cargo_toml_to_update}, updated ${workspace_bazel_to_update}, and updated ${module_bazel_to_update}"

echo "VENDOR_EDIT_TEST: ${copy_to}"
