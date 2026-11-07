#!/bin/sh
set -eu

# Require the binary's RPATH to find the runtime libraries. The link-time
# interfaces live in different directories and are not runtime dependencies.
unset LD_LIBRARY_PATH
ulimit -c 0
export RUST_BACKTRACE=0

abort_binary="$(pwd)/$1"
unwind_binary="$(pwd)/$2"
# A build-directory DT_NEEDED path must not accidentally work because the
# test's current directory happens to contain bazel-out.
cd "$TEST_TMPDIR"

abort_marker="$TEST_TMPDIR/abort-marker"
status=0
"$abort_binary" "$abort_marker" > "$TEST_TMPDIR/abort.stdout" 2> "$TEST_TMPDIR/abort.stderr" || status=$?
if [ "$status" -ne 134 ]; then
    cat "$TEST_TMPDIR/abort.stderr" >&2
    echo "Expected SIGABRT (134), got $status" >&2
    exit 1
fi
grep -q '^linked=73$' "$TEST_TMPDIR/abort.stdout"
grep -q 'controlled panic' "$TEST_TMPDIR/abort.stderr"
test ! -e "$abort_marker"

unwind_marker="$TEST_TMPDIR/unwind-marker"
status=0
"$unwind_binary" "$unwind_marker" > "$TEST_TMPDIR/unwind.stdout" 2> "$TEST_TMPDIR/unwind.stderr" || status=$?
if [ "$status" -ne 101 ]; then
    cat "$TEST_TMPDIR/unwind.stderr" >&2
    echo "Expected Rust panic status 101, got $status" >&2
    exit 1
fi
grep -q '^linked=73$' "$TEST_TMPDIR/unwind.stdout"
grep -q 'controlled panic' "$TEST_TMPDIR/unwind.stderr"
test "$(cat "$unwind_marker")" = unwound
