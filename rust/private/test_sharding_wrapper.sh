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
# --list flag, partitions them by stable test-name hash, and runs only the
# relevant subset.

set -euo pipefail

TEST_BINARY="{{TEST_BINARY}}"
# Native Bazel test sharding sets TEST_TOTAL_SHARDS/TEST_SHARD_INDEX. Explicit
# shard test targets can set RULES_RUST_TEST_TOTAL_SHARDS/RULES_RUST_TEST_SHARD_INDEX
# instead because Bazel may reserve TEST_* variables for its own test runner env.
TOTAL_SHARDS="${RULES_RUST_TEST_TOTAL_SHARDS:-${TEST_TOTAL_SHARDS:-}}"
SHARD_INDEX="${RULES_RUST_TEST_SHARD_INDEX:-${TEST_SHARD_INDEX:-}}"

test_shard_index() {
    local test_name="$1"
    # FNV-1a 32-bit hash. The initial value is the FNV offset basis, and
    # 16777619 is the FNV prime. This gives a stable, cheap string hash without
    # depending on platform-specific tools being present in the test sandbox.
    local hash=2166136261
    local byte
    local char
    local i
    local LC_ALL=C

    for ((i = 0; i < ${#test_name}; i++)); do
        char="${test_name:i:1}"
        printf -v byte "%d" "'$char"
        hash=$(( ((hash ^ byte) * 16777619) & 0xffffffff ))
    done

    echo $(( hash % TOTAL_SHARDS ))
}

# If sharding is not enabled, run test binary directly
if [[ -z "${TOTAL_SHARDS}" || "${TOTAL_SHARDS}" == "0" ]]; then
    exec "./${TEST_BINARY}" "$@"
fi

if [[ -z "${SHARD_INDEX}" ]]; then
    echo "TEST_SHARD_INDEX or RULES_RUST_TEST_SHARD_INDEX must be set when sharding is enabled" >&2
    exit 1
fi

# Touch status file to advertise sharding support to Bazel
if [[ -n "${TEST_SHARD_STATUS_FILE:-}" && "${TEST_TOTAL_SHARDS:-0}" != "0" ]]; then
    touch "${TEST_SHARD_STATUS_FILE}"
fi

# Enumerate all tests using libtest's --list flag. Sort the list so execution
# order does not depend on libtest's output order.
# Output format: "test_name: test" - we need to strip the ": test" suffix
test_list=$("./${TEST_BINARY}" --list --format terse 2>/dev/null | grep ': test$' | sed 's/: test$//' | LC_ALL=C sort || true)

# If no tests found, exit successfully
if [[ -z "$test_list" ]]; then
    exit 0
fi

# Filter tests for this shard. Use a stable name hash instead of list position
# so adding or removing one test does not move unrelated tests between shards.
shard_tests=()
while IFS= read -r test_name; do
    if (( $(test_shard_index "$test_name") == SHARD_INDEX )); then
        shard_tests+=("$test_name")
    fi
done <<< "$test_list"

# If no tests for this shard, exit successfully
if [[ ${#shard_tests[@]} -eq 0 ]]; then
    exit 0
fi

# Run the filtered tests with --exact to match exact test names
exec "./${TEST_BINARY}" "${shard_tests[@]}" --exact "$@"
