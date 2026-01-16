#!/usr/bin/env bash
# Copyright 2024 The Bazel Authors. All rights reserved.
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

# Wrapper script for rust_test that enables Bazel test sharding support.
# This script intercepts test execution, enumerates tests using libtest's
# --list flag, partitions them by shard index, and runs only the relevant subset.

set -euo pipefail

TEST_BINARY="{{TEST_BINARY}}"

# If sharding is not enabled, run test binary directly
if [[ -z "${TEST_TOTAL_SHARDS:-}" ]]; then
    exec "./${TEST_BINARY}" "$@"
fi

# Touch status file to advertise sharding support to Bazel
if [[ -n "${TEST_SHARD_STATUS_FILE:-}" ]]; then
    touch "${TEST_SHARD_STATUS_FILE}"
fi

# Enumerate all tests using libtest's --list flag
# Output format: "test_name: test" - we need to strip the ": test" suffix
test_list=$("./${TEST_BINARY}" --list --format terse 2>/dev/null | grep ': test$' | sed 's/: test$//' || true)

# If no tests found, exit successfully
if [[ -z "$test_list" ]]; then
    exit 0
fi

# Filter tests for this shard
# test_index % TEST_TOTAL_SHARDS == TEST_SHARD_INDEX
shard_tests=()
index=0
while IFS= read -r test_name; do
    if (( index % TEST_TOTAL_SHARDS == TEST_SHARD_INDEX )); then
        shard_tests+=("$test_name")
    fi
    ((index++)) || true
done <<< "$test_list"

# If no tests for this shard, exit successfully
if [[ ${#shard_tests[@]} -eq 0 ]]; then
    exit 0
fi

# Run the filtered tests with --exact to match exact test names
exec "./${TEST_BINARY}" "${shard_tests[@]}" --exact "$@"
