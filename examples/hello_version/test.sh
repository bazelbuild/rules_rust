#!/bin/bash -eu

if [[ $# -ne 1 ]]; then
  echo >&2 "Usage: $0 binary-to-run"
  exit 1
fi

want="Version: 0.1.2-alpha0
Major: 0
Minor: 1
Patch: 2
Pre: alpha0"

got="$($1)"
if [[ "${got}" != "${want}" ]]; then
  echo >&2 "Wanted:
${want}

Got:
${got}"
  exit 1
fi
