#!/usr/bin/env bash

set -euo pipefail

wrapper_template=$1
fake_binary_src=$2

workdir="${TEST_TMPDIR:-$(mktemp -d)}"
fake_binary="$workdir/fake_libtest_binary"
wrapper="$workdir/wrapper.sh"

cp "$fake_binary_src" "$fake_binary"
chmod +x "$fake_binary"

sed 's|{{TEST_BINARY}}|fake_libtest_binary|g' "$wrapper_template" > "$wrapper"
chmod +x "$wrapper"

collect_mapping() {
    local variant=$1
    local order=$2
    local output=$3
    local unsorted_output="${output}.unsorted"
    local shard

    : > "$unsorted_output"
    for shard in 0 1 2; do
        local shard_output="$workdir/${variant}_${order}_${shard}.txt"
        : > "$shard_output"

        (
            cd "$workdir"
            TEST_LIST_VARIANT="$variant" \
                TEST_LIST_ORDER="$order" \
                TEST_SHARD_OUTPUT="$shard_output" \
                RULES_RUST_TEST_SHARD_INDEX="$shard" \
                RULES_RUST_TEST_TOTAL_SHARDS=3 \
                ./wrapper.sh
        )

        while IFS= read -r test_name; do
            printf '%s %s\n' "$test_name" "$shard" >> "$unsorted_output"
        done < "$shard_output"
    done

    LC_ALL=C sort "$unsorted_output" > "$output"
}

assert_same_mapping() {
    local expected=$1
    local actual=$2
    local message=$3

    if ! diff -u "$expected" "$actual"; then
        echo "$message" >&2
        exit 1
    fi
}

base_normal="$workdir/base_normal.txt"
base_reversed="$workdir/base_reversed.txt"
with_added="$workdir/with_added.txt"
with_added_existing_tests="$workdir/with_added_existing_tests.txt"

collect_mapping base normal "$base_normal"
collect_mapping base reversed "$base_reversed"
collect_mapping with_added normal "$with_added"

assert_same_mapping "$base_normal" "$base_reversed" \
    "test shard assignment changed when libtest list order changed"

sed '/^aardvark::test_added /d' "$with_added" > "$with_added_existing_tests"
assert_same_mapping "$base_normal" "$with_added_existing_tests" \
    "existing test shard assignment changed after adding a new test"
