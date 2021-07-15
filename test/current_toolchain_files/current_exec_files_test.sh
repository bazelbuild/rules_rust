#!/bin/bash

set -euo pipefail

TARGET="$1"
OPTION="$2"

# To parse this argument on windows it must be wrapped in quotes but
# these quotes should not be passed to grep. Remove them here.
PATTERN="$(echo -n "$3" | sed "s/'//g")"

if [[ "${OPTION}" == "--executable" ]]; then
    # Clippy requires this environment variable is set
    export SYSROOT=""

    "${TARGET}" --version
    "${TARGET}" --version | grep "${PATTERN}"
    exit 0
fi

if [[ "${OPTION}" == "--files" ]]; then
    cat "${TARGET}"
    grep "${PATTERN}" "${TARGET}"
    exit 0
fi

echo "Unexpected option: ${OPTION}"
exit 1
