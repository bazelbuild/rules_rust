#!/bin/sh
#
# For details, see:
# `@rules_rust//crate_universe/src/metadata/cargo_tree_resolver.rs - TreeResolver::create_rustc_wrapper`

set -eu

# When cargo is detecting the host configuration, the host target needs to be
# injected into the command.
case "$*" in
    *"rustc - --crate-name ___ "*)
        case "$*" in
            *" --target "*) ;;
            *)
                exec "$@" --target "${HOST_TRIPLE}"
                ;;
        esac
        ;;
esac

# When querying info about the compiler, ensure the triple is mocked out to be
# the desired target triple for the host.
case "$*" in
    *"rustc -Vv"*|*"rustc -vV"*)
        set +e
        _RUSTC_OUTPUT="$("$@")"
        _EXIT_CODE=$?
        set -e

        # Loop through each line of the output
        while IFS= read -r line; do
            # If the line starts with "host:", replace it with the new host value
            case "${line}" in
                host:*)
                    echo "host: ${HOST_TRIPLE}"
                    ;;
                *)
                    echo "${line}"
                    ;;
            esac
        done <<EOF
${_RUSTC_OUTPUT}
EOF

        exit ${_EXIT_CODE}
        ;;
esac

# If there is nothing special to do then simply forward the call
exec "$@"
