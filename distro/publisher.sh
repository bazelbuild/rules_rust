#!/bin/bash

set -euo pipefail

ABS_ARCHIVE="$(pwd)/${ARCHIVE}"
cd "${BUILD_WORKING_DIRECTORY}"
mkdir -p "$@"

set -x
cp -fp "${ABS_ARCHIVE}" "$@"/"$(basename "${ARCHIVE}")"
