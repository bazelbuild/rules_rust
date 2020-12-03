#!/bin/bash -eu

out="$("$1")"
[[ "${out}" == "It worked!" ]] || { echo "Unexpected output: ${out}"; exit 1; }
