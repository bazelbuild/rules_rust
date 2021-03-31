#!/bin/bash

set -euo pipefail

if [[ -n "${BUILD_WORKSPACE_DIRECTORY:-}" ]]; then
    DOCS_WORKSPACE="${BUILD_WORKSPACE_DIRECTORY}"
else
    # https://stackoverflow.com/a/246128/7768383
    DOCS_WORKSPACE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
fi

pushd "${DOCS_WORKSPACE}" &> /dev/null
# It's important to clean the workspace so we don't end up with unintended
# docs artifacts in the new commit.
bazel clean \
&& bazel build //... \
&& cp bazel-bin/*.md . \
&& chmod 0644 *.md

if [ -n "$(git status --porcelain)" ]; then 
    git status
    echo '/docs is out of date. Please run `./docs/update_docs.sh` from the root of rules_rust and push the results' >&2
    exit 1
fi

popd &> /dev/null
