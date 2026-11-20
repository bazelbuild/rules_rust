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

# Replace the placeholders in $1 and store the result in `expanded`.
expand_placeholders() {
    expanded=$1
    case "$expanded" in
        *'${pwd}'*)
            prefix="${expanded%%\$\{pwd\}*}"
            suffix="${expanded#*\$\{pwd\}}"
            expanded="${prefix}${phys_pwd}${suffix}"
            ;;
    esac
    case "$expanded" in
        *'${output_base}'*)
            prefix="${expanded%%\$\{output_base\}*}"
            suffix="${expanded#*\$\{output_base\}}"
            expanded="${prefix}${output_base}${suffix}"
            ;;
    esac
    case "$expanded" in
        *'${exec_root}'*)
            prefix="${expanded%%\$\{exec_root\}*}"
            suffix="${expanded#*\$\{exec_root\}}"
            expanded="${prefix}${exec_root}${suffix}"
            ;;
    esac
}

# Print the names of all exported variables.
#
# The real process wrapper also replaces placeholders in environment
# variables. This script needs to do the same. Only shell builtins are used
# because actions can run with an empty PATH.
#
# A value that spans several lines can produce extra names. This is fine
# because a variable is only changed if its value has a placeholder.
exported_names() {
    export -p | while IFS= read -r line; do
        case "$line" in
            "declare -x "*) line="${line#declare -x }" ;;
            "export "*) line="${line#export }" ;;
            *) continue ;;
        esac
        name="${line%%=*}"
        case "$name" in
            "" | [!A-Za-z_]* | *[!A-Za-z0-9_]*) continue ;;
        esac
        printf '%s\n' "$name"
    done
}

env_names=$(exported_names)
for name in $env_names; do
    eval "value=\${$name-}"
    case "$value" in
        *'${pwd}'* | *'${output_base}'* | *'${exec_root}'*)
            expand_placeholders "$value"
            export "$name=$expanded"
            ;;
    esac
done

for arg in "$@"; do
    expand_placeholders "$arg"
    set -- "$@" "$expanded"
    shift
done

exec "$@"
