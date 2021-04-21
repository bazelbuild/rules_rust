#!/bin/bash
set -euo pipefail

curl -LO "https://github.com/bazelbuild/bazelisk/releases/download/v1.1.0/bazelisk-linux-amd64"
mkdir -p "${GITHUB_WORKSPACE}/bin/"
mv bazelisk-linux-amd64 "${GITHUB_WORKSPACE}/bin/bazel"
chmod +x "${GITHUB_WORKSPACE}/bin/bazel"
