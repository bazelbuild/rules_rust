#!/bin/bash -eu

set -o pipefail

output="$($1)"
[[ "${output}" == "Howdy from version 1.2.3" ]] || { echo >&2 "Unexpected output: ${output}"; exit 1;}
