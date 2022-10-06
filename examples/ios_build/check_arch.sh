#!/bin/bash
#
# When compiling with --platforms=//:ios_sim_arm64 or --platforms=//:ios_x86_64,
# the library should not contain any references to macOS (platform 1)

set -e

if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "This test only makes sense on macOS."
    exit 0
fi

if otool -l $1 | grep 'platform 1'; then
    echo "macOS detected."
    exit 1
fi