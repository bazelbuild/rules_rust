#!/bin/bash

set -euo pipefail
set -x

cd "${BUILD_WORKSPACE_DIRECTORY}"

if [[ "$#" -ne 1 ]]; then
  echo >&2 "Usage: $0 //:vendor_target"
  exit 1
fi
vendor_target="$1"

echo >&2 "Patching lazy_static dependency"

vendored_lazy_static_dir="$(bazel run "${vendor_target}" | awk '$0 ~ /Copied to/ {print $3}')"
echo >&2 "Vendored lazy_static to ${vendored_lazy_static_dir}"

echo >&2 "Running test which is expected to pass, now that patch is applied"
bazel test ...

echo >&2 "Changing the version of the vendored crate, so that the patch no longer applies"
sed_i=(sed -i)
if [[ "$(uname)" == "Darwin" ]]; then
  sed_i=(sed -i '')
fi
"${sed_i[@]}" -e 's#^version = "1\.5\.0"$#version = "2.0.0"#' "${vendored_lazy_static_dir}/Cargo.toml"

echo >&2 "Running build which is expected to fail, as the patch no longer applies"

set +e
output="$(bazel build ... 2>&1)"
exit_code=$?
set -e

if [[ "$exit_code" -ne 1 ]]; then
  echo >&2 "Expected build failure, but exit code was ${exit_code}. Output:"
  echo >&2 "${output}"
  exit 1
fi

if [[ "${output}" != *"cannot find value \`VENDORED_BY\` in crate \`lazy_static\`"* ]]; then
  echo >&2 "Expected compile failure due to missing VENDORED_BY symbol because the patch stopped applying. Output:"
  echo >&2 "${output}"
  exit 1
fi

echo >&2 "Build failed as expected, making patch re-apply"

"${sed_i[@]}" -e 's#^version = "2\.0\.0"$#version = "1.5.0"#' "${vendored_lazy_static_dir}/Cargo.toml"

echo >&2 "Running test which is expected to pass, now that patch is re-applied"
bazel test ...

echo >&2 "Test passed as expected"
