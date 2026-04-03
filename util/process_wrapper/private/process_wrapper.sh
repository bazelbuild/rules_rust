#!/bin/sh

set -eu

# Skip the first argument which is expected to be `--`
shift

# Derive output_base and exec_root so we can expand their placeholders
# in rustc flags (e.g. --remap-path-prefix, -oso_prefix). This mirrors
# the logic in options.rs used by the real process wrapper.
phys_pwd=$(cd -P . && pwd)
if [ -d "external" ]; then
    output_base=$(cd -P external/.. && pwd)
else
    output_base="${phys_pwd%/*}"
    output_base="${output_base%/*}"
fi
workspace_name="${phys_pwd##*/}"
exec_root="${output_base}/execroot/${workspace_name}"

for arg in "$@"; do
    case "$arg" in
        *'${pwd}'*)
            prefix="${arg%%\$\{pwd\}*}"
            suffix="${arg#*\$\{pwd\}}"
            arg="${prefix}${PWD}${suffix}"
            ;;
    esac
    case "$arg" in
        *'${output_base}'*)
            prefix="${arg%%\$\{output_base\}*}"
            suffix="${arg#*\$\{output_base\}}"
            arg="${prefix}${output_base}${suffix}"
            ;;
    esac
    case "$arg" in
        *'${exec_root}'*)
            prefix="${arg%%\$\{exec_root\}*}"
            suffix="${arg#*\$\{exec_root\}}"
            arg="${prefix}${exec_root}${suffix}"
            ;;
    esac
    set -- "$@" "$arg"
    shift
done

exec "$@"
