#!/bin/bash

set -euo pipefail

#######################################################################################################################
# Crate Universe
#######################################################################################################################

# Find the location of the script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
BOOTSTRAP_DIR="${SCRIPT_DIR}/crate_universe/private/bootstrap"

# Go to root of rules_rust
pushd "${SCRIPT_DIR}" &> /dev/null
has_changes="$(git diff --name-only origin/main -- crate_universe bootstrap.sh)"
popd &> /dev/null

# Only bootstrap the binary if there are changes
if [[ -n "${has_changes}" ]] || git ls-files --others --exclude-standard | grep 'crate_universe'; then
    pushd "${BOOTSTRAP_DIR}" &> /dev/null
    bazel run //:build && bazel run //:install && bazel clean
    popd &> /dev/null

    # Generate a bazelrc file for ensuring we always use the resolver binary for the current host
    cat << EOF > "${SCRIPT_DIR}/crate_universe.bazelrc"
common --announce_rc
common --repo_env="RULES_RUST_CRATE_UNIVERSE_RESOLVER_URL_OVERRIDE=file://${BOOTSTRAP_DIR}/file/resolver"
EOF

    cp ${SCRIPT_DIR}/crate_universe.bazelrc ${SCRIPT_DIR}/examples/crate_universe/crate_universe.bazelrc
else
    echo "No changes to crate_universe. Nothing to do"
fi

#######################################################################################################################
