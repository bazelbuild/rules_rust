#!/bin/bash -eu

out="$(echo -n "Hello world" | "$1")"

[[ "${out}" == "Compressed 11 to 50 bytes" ]] || (echo "Got ${out}" && exit 1)
