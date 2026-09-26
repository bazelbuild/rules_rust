#!/bin/bash
set -euo pipefail
out=""
dep=""
while [[ $# -gt 0 ]]; do
  if [[ "$1" == "-o" ]]; then
    out="$2"
    shift
  elif [[ "$1" == "-MF" ]]; then
    dep="$2"
    shift
  fi
  shift
done
if [[ -n "$dep" ]]; then
  mkdir -p "$(dirname "$dep")"
  : > "$dep"
fi
if [[ -n "$out" ]]; then
  mkdir -p "$(dirname "$out")"
  : > "$out"
fi
