#!/bin/sh

set -eu

# Skip the first argument which is expected to be `--`
shift

for arg in "$@"; do
    case "$arg" in
        *'${pwd}'*)
            # Split on '${pwd}' and rejoin with the actual PWD value
            prefix="${arg%%\$\{pwd\}*}"
            suffix="${arg#*\$\{pwd\}}"
            arg="${prefix}${PWD}${suffix}"
            ;;
    esac
    set -- "$@" "$arg"
    shift
done

exec "$@"
