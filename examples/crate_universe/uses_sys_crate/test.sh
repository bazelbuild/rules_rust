#!/bin/bash -eu

out="$(echo -n "Hello world" | "$1")"

expected="Compressed 11 to 50 bytes"
[[ "${out}" == ${expected} ]] || { echo "Expected '${expected}', got '${out}'"; exit 1; }
