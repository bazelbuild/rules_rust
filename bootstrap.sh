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
has_changes="$(git log origin/main.. -- crate_universe/**)"
popd &> /dev/null

# Only bootstrap the binary if there are changes
if [[ -n "${has_changes}" ]]; then
    pushd "${BOOTSTRAP_DIR}" &> /dev/null
    bazel run //:build && bazel run //:install && bazel clean
    popd &> /dev/null

    # Generate a bazelrc file for ensuring we always use the resolver binary for the current host
    cat << EOF > "${SCRIPT_DIR}/crate_universe.bazelrc"
common --announce_rc
common --override_repository="rules_rust_crate_universe__aarch64-apple-darwin=${BOOTSTRAP_DIR}"
common --override_repository="rules_rust_crate_universe__aarch64-unknown-linux-gnu=${BOOTSTRAP_DIR}"
common --override_repository="rules_rust_crate_universe__x86_64-apple-darwin=${BOOTSTRAP_DIR}"
common --override_repository="rules_rust_crate_universe__x86_64-pc-windows-gnu=${BOOTSTRAP_DIR}"
common --override_repository="rules_rust_crate_universe__x86_64-unknown-linux-gnu=${BOOTSTRAP_DIR}"
EOF

    cp ${SCRIPT_DIR}/crate_universe.bazelrc ${SCRIPT_DIR}/examples/crate_universe/crate_universe.bazelrc
else
    echo "No changes to crate_universe. Nothing to do"
fi

#######################################################################################################################
