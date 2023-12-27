#!/usr/bin/env bash

# MARK - Functions

fail() {
  echo >&2 "$@"
  exit 1
}

# MARK - Args

if [[ "$#" -ne 1 ]]; then
  fail "Usage: $0 /path/to/hello_world"
fi
hello_world="$1"

# MARK - Test

output="$( "${hello_world}" )"
[[ "${output}" == "Hello, world!" ]] || \
  fail 'Expected "Hello, world!", but was' "${output}"
