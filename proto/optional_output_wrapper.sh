#!/bin/bash
# Copyright 2018 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# A simple wrapper around a binary to ensure we always create some outputs
# Optional outputs are not available in Skylark :(
# Syntax: $0 output1 output2 ... -- program  [arg1...argn]

optional_outputs=()

while [ "${1-}" != "" -a  "${1-}" != "--" ]; do
  optional_outputs+=("$1")
  shift 1
done

if (( "$#" < 2 )); then
  echo "Usage: $0 [optional_output1...optional_outputN] -- program [arg1...argn]" >&2
  exit 1
fi

shift 1

"$@" || exit $?
for f in "${optional_outputs[@]}"; do
  if [ ! -f "$f" ]; then
    touch "$f"
  fi
done
