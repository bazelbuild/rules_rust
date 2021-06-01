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

cd "${BUILD_WORKSPACE_DIRECTORY}"

# Executes a bazel build command and handles the return value, exiting
# upon seeing an error.
#
# Takes two arguments:
# ${1}: The expected return code.
# ${2}: The target within "//test/rustfmt" to be tested.
function check_build_result() {
  local ret=0
  echo -n "Testing ${2}... "
  (bazel test //test/rustfmt:"${2}" &> /dev/null) || ret="$?" && true
  if [[ "${ret}" -ne "${1}" ]]; then
    echo "FAIL: Unexpected return code [saw: ${ret}, want: ${1}] building target //test/rustfmt:${2}"
    echo "  Run \"bazel test //test/rustfmt:${2}\" to see the output"
    exit 1
  else
    echo "OK"
  fi
}

function test_all_and_apply() {
  local -r TEST_OK=0
  local -r TEST_FAILED=3

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

  # Drop the 'norustfmt' tags
  if [ "$(uname)" == "Darwin" ]; then
    SEDOPTS=(-i '' -e)
  else
    SEDOPTS=(-i)
  fi
  sed ${SEDOPTS[@]} 's/"norustfmt"//' "${new_workspace}/test/rustfmt/BUILD.bazel"

  pushd "${new_workspace}"

  check_build_result $TEST_FAILED test_unformatted_2015
  check_build_result $TEST_FAILED test_unformatted_2018
  check_build_result $TEST_OK test_formatted_2015
  check_build_result $TEST_OK test_formatted_2018

  # Format a specific target
  bazel run @rules_rust//tools/rustfmt -- //test/rustfmt:unformatted_2018

  check_build_result $TEST_FAILED test_unformatted_2015
  check_build_result $TEST_OK test_unformatted_2018
  check_build_result $TEST_OK test_formatted_2015
  check_build_result $TEST_OK test_formatted_2018

  # Format all targets
  bazel run @rules_rust//tools/rustfmt --@rules_rust//:rustfmt.toml=//test/rustfmt:test_rustfmt.toml

  check_build_result $TEST_OK test_unformatted_2015
  check_build_result $TEST_OK test_unformatted_2018
  check_build_result $TEST_OK test_formatted_2015
  check_build_result $TEST_OK test_formatted_2018

  popd

  rm -rf "${temp_dir}"
}

test_all_and_apply
