#!/bin/bash

# Runs Bazel build commands over clippy rules, where some are expected
# to fail.
#
# Can be run from anywhere within the rules_rust workspace.

set -euo pipefail

if [[ -z "${BUILD_WORKSPACE_DIRECTORY:-}" ]]; then
  echo "This script should be run under Bazel"
  exit 1
fi

cd "${BUILD_WORKSPACE_DIRECTORY}"

# Executes a bazel build command and handles the return value, exiting
# upon seeing an error.
#
# Takes two arguments:
# ${1}: The expected return code.
# ${2}: The target within "//test/clippy" to be tested.
#
# Optional third argument:
# ${3}: The clippy.toml file to pass as an override.
function check_build_result() {
  local ret=0
  echo -n "Testing ${2}... "
  ADDITIONAL_ARGS=()
  if [[ -n "${3-}" ]]; then
    ADDITIONAL_ARGS+=("--@rules_rust//:clippy.toml=${3}")
  fi
  (bazel build "${ADDITIONAL_ARGS[@]}" //test/clippy:"${2}" &> /dev/null) || ret="$?" && true
  if [[ "${ret}" -ne "${1}" ]]; then
    echo "FAIL: Unexpected return code [saw: ${ret}, want: ${1}] building target //test/clippy:${2}"
    echo "  Run \"bazel build //test/clippy:${2}\" to see the output"
    exit 1
  else
    echo "OK"
  fi
}

function test_all() {
  local -r BUILD_OK=0
  local -r BUILD_FAILED=1
  local -r TEST_FAIL=3

  temp_dir="$(mktemp -d -t ci-XXXXXXXXXX)"
  new_workspace="${temp_dir}/rules_rust_test_clippy"
  
  mkdir -p "${new_workspace}/test/clippy" && \
  cp -r test/clippy/* "${new_workspace}/test/clippy/" && \
  cat << EOF > "${new_workspace}/WORKSPACE.bazel"
workspace(name = "rules_rust_test_clippy")
local_repository(
    name = "rules_rust",
    path = "${BUILD_WORKSPACE_DIRECTORY}",
)
load("@rules_rust//rust:repositories.bzl", "rust_repositories")
rust_repositories()
EOF

  # Drop the 'noclippy' tags
  if [ "$(uname)" == "Darwin" ]; then
    SEDOPTS=(-i '' -e)
  else
    SEDOPTS=(-i)
  fi
  sed ${SEDOPTS[@]} 's/"noclippy"//' "${new_workspace}/test/clippy/BUILD.bazel"

  pushd "${new_workspace}"

  check_build_result $BUILD_OK ok_binary_clippy
  check_build_result $BUILD_OK ok_library_clippy
  check_build_result $BUILD_OK ok_test_clippy
  check_build_result $BUILD_FAILED bad_binary_clippy
  check_build_result $BUILD_FAILED bad_library_clippy
  check_build_result $BUILD_FAILED bad_test_clippy

  # Test that we can make the ok_library_clippy fail when using an extra config file.
  # Proves that the config file is used and overrides default settings.
  check_build_result $BUILD_FAILED ok_library_clippy //too_many_args:clippy.toml
}

test_all
