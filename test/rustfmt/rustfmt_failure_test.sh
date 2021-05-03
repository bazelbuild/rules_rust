#!/bin/bash

# Runs Bazel build commands over rustfmt rules, where some are expected
# to fail.
#
# Can be run from anywhere within the rules_rust workspace.

set -euo pipefail

if [[ -z "${BUILD_WORKSPACE_DIRECTORY:-}" ]]; then
  echo "This script should be run under Bazel"
  exit 1
fi

cd "${BUILD_WORKSPACE_DIRECTORY:-}"

# Executes a bazel build command and handles the return value, exiting
# upon seeing an error.
#
# Takes two arguments:
# ${1}: The expected return code.
# ${2}: The target within "//test/rustfmt" to be tested.
function check_build_result() {
  local ret=0
  echo -n "Testing ${2}... "
  (bazel build //test/rustfmt:"${2}" &> /dev/null) || ret="$?" && true
  if [[ "${ret}" -ne "${1}" ]]; then
    echo "FAIL: Unexpected return code [saw: ${ret}, want: ${1}] building target //test/rustfmt:${2}"
    echo "  Run \"bazel build //test/rustfmt:${2}\" to see the output"
    exit 1
  else
    echo "OK"
  fi
}

function test_all() {
  local -r BUILD_OK=0
  local -r BUILD_FAILED=1

  check_build_result $BUILD_FAILED check_unformatted_2015
  check_build_result $BUILD_FAILED check_unformatted_2018
  check_build_result $BUILD_OK check_formatted_2015
  check_build_result $BUILD_OK check_formatted_2018
}

function test_apply() {
  local -r BUILD_OK=0
  local -r BUILD_FAILED=1

  temp_dir="$(mktemp -d -t ci-XXXXXXXXXX)"
  new_workspace="${temp_dir}/rules_rust_test_rustfmt"
  
  mkdir -p "${new_workspace}/test/rustfmt" && \
  cp -r test/rustfmt/* "${new_workspace}/test/rustfmt/" && \
  cat << EOF > "${new_workspace}/WORKSPACE.bazel"
workspace(name = "rules_rust_test_rustfmt")
local_repository(
    name = "rules_rust",
    path = "${BUILD_WORKSPACE_DIRECTORY}",
)
load("@rules_rust//rust:repositories.bzl", "rust_repositories")
rust_repositories()
EOF

  pushd "${new_workspace}"

  # Format a specific target
  bazel run @rules_rust//tools/rustfmt -- //test/rustfmt:unformatted_2018

  check_build_result $BUILD_FAILED check_unformatted_2015
  check_build_result $BUILD_OK check_unformatted_2018
  check_build_result $BUILD_OK check_formatted_2015
  check_build_result $BUILD_OK check_formatted_2018

  # Format all targets
  bazel run @rules_rust//tools/rustfmt

  check_build_result $BUILD_OK check_unformatted_2015
  check_build_result $BUILD_OK check_unformatted_2018
  check_build_result $BUILD_OK check_formatted_2015
  check_build_result $BUILD_OK check_formatted_2018

  popd

  rm -rf "${temp_dir}"
}

test_all
test_apply
