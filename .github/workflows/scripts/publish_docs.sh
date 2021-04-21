#!/bin/bash
set -exuo pipefail

# run within the docs workspace
pushd docs &> /dev/null

# We use a bazelisk-installed bazel
"${GITHUB_WORKSPACE}/bin/bazel" clean
"${GITHUB_WORKSPACE}/bin/bazel" build //...

# Pull out the relevant docs
cp bazel-bin/*.md .
chmod 0644 *.md

# And generate a new commit, that we push to the "docs" branch.
git config user.name github-actions
git config user.email github-actions@github.com
git add *.md
git commit -m "Regenerate documentation"
git remote -v
git push -f origin HEAD:docs

popd &> /dev/null

