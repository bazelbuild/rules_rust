#!/bin/sh
# Fake "linker" for this directory's regression test. A real link is never
# meant to succeed here -- the point is only to check the flags rustc built
# for --codegen=linker= and --sysroot=. `bazel test` on the wrapping
# analysistest never executes this (it only inspects the analysis-time
# action graph), but `bazel coverage` does actually build and run the
# target under test's own actions, so this still has to produce *a* file
# at whichever output path it's given, or Bazel's "output was not created"
# check fails the build outright.
out=""
prev=""
for arg in "$@"; do
    case "$prev" in
        -o) out="$arg" ;;
    esac
    case "$arg" in
        /OUT:*) out="${arg#/OUT:}" ;;
    esac
    prev="$arg"
done
if [ -n "$out" ]; then
    # A shell builtin, not the external `touch`: the sandbox PATH a linker
    # is invoked under is minimal and doesn't reliably have it (observed as
    # "touch: not found" from this script's own stderr in CI).
    : > "$out"
fi
exit 0
