#!/bin/bash

pushd ${0%/*}
# It's important to clean the workspace so we don't end up with unintended
# docs artifacts in the new commit.
bazel clean \
&& bazel build //... \
&& cp bazel-bin/*.md . \
&& chmod 0644 *.md \
&& git add *.md \
&& git commit -m "Regenerate documentation"
popd

