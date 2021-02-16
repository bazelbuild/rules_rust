#!/usr/bin/env bash

# publish-new-version.sh
# EXAMPLE USAGE: publish-new-version.sh 0.1.1
#
# This script accepts a desired new crate version as an argument and updates
# the Cargo.toml version of the repository to the given version, builds the
# crate, commits the changes, publishes the crate, and then pushes the crate
# to github.
#
# The script performs some types of sanity checking, but in general you should
# read and understand this script before running it.
#
# This script assumes that your git upstream is called "origin".

set -eu

command_exists() {
    command -v "$1" >/dev/null 2>&1 || ( echo "Command \`$1\` isn't available. Please install before continuing."; exit 1 )
}

update_cargo_toml_version() {
  crate_version=$1
  sed -i "s/^version =.*/version = \"${crate_version}\"/g" Cargo.toml
}

cargo_build_crate() {
  # Build so that our `Cargo.lock` gets updated (before we commit).
  cargo build --release
}

git_commit_changes() {
  crate_version=$1
  git add . && git commit -m "Up to ${crate_version} [via publish-new-version.sh]"
}

git_last_commit() {
  echo "$(git rev-parse --short HEAD)"
}

git_tag_commit_with_version() {
  last_commit_hash=$1
  crate_version=$2
  git tag "v${crate_version}" "${last_commit_hash}"
}

cargo_publish_crate() {
  cargo publish
}

git_push_changes_and_tags() {
  git push origin master && git push origin --tags
}

publish_crate_version() {
  crate_version=$1
  update_cargo_toml_version "${crate_version}"
  cargo_build_crate
  git_commit_changes "${crate_version}"
  last_commit_hash=$(git_last_commit)
  git_tag_commit_with_version "${last_commit_hash}" "${crate_version}"
  cargo_publish_crate
  git_push_changes_and_tags
}

command_exists "cargo"

NEXT_CRATE_VERSION=$1
if [[ -z "${NEXT_CRATE_VERSION+x}" ]]
then
  echo "A version argument must be provided, of the form X.Y.Z."
  echo "Example Usage: ./publish-new-version.sh 0.1.1"
  exit 1
fi

if ! [[ -z "$(git status --porcelain)" ]]; then
  echo "Working directory is not clean. Commit pending changes before running command."
  exit 1
fi

if [[ -z "${BUILD_WORKSPACE_DIRECTORY+x}" ]]; then
  SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
  REPO_ROOT="$(dirname $SCRIPT_DIR)"
else
  REPO_ROOT="${BUILD_WORKSPACE_DIRECTORY}"
fi

pushd "${REPO_ROOT}/impl"
set -x
publish_crate_version "${NEXT_CRATE_VERSION}"
popd
