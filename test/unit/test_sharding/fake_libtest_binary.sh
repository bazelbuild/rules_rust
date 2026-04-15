#!/usr/bin/env bash

set -euo pipefail

emit_base_tests() {
    cat <<'EOF'
delta::test_delta: test
alpha::test_alpha: test
foxtrot::test_foxtrot: test
bravo::test_bravo: test
echo::test_echo: test
charlie::test_charlie: test
helper::bench: bench
EOF
}

emit_reversed_base_tests() {
    cat <<'EOF'
helper::bench: bench
charlie::test_charlie: test
echo::test_echo: test
bravo::test_bravo: test
foxtrot::test_foxtrot: test
alpha::test_alpha: test
delta::test_delta: test
EOF
}

emit_tests_with_added_test() {
    cat <<'EOF'
delta::test_delta: test
alpha::test_alpha: test
foxtrot::test_foxtrot: test
aardvark::test_added: test
bravo::test_bravo: test
echo::test_echo: test
charlie::test_charlie: test
helper::bench: bench
EOF
}

if [[ "${1:-}" == "--list" ]]; then
    case "${TEST_LIST_VARIANT:-base}:${TEST_LIST_ORDER:-normal}" in
        base:normal)
            emit_base_tests
            ;;
        base:reversed)
            emit_reversed_base_tests
            ;;
        with_added:normal)
            emit_tests_with_added_test
            ;;
        *)
            echo "unknown test list variant: ${TEST_LIST_VARIANT:-base}:${TEST_LIST_ORDER:-normal}" >&2
            exit 1
            ;;
    esac
    exit 0
fi

: "${TEST_SHARD_OUTPUT:?}"

for test_name in "$@"; do
    if [[ "$test_name" != "--exact" ]]; then
        printf '%s\n' "$test_name" >> "$TEST_SHARD_OUTPUT"
    fi
done
