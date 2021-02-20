#!/usr/bin/env bash

set -eu

SOURCE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
COMMAND="cargo run --manifest-path $SOURCE_DIR/tools/Cargo.toml --bin dump_metadata -- $@"

echo "RUNNING \"$COMMAND\""
$COMMAND
