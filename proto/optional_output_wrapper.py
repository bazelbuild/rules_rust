#!/usr/bin/python
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

import os
import sys
import subprocess

def usage():
  exit("Usage: %s [optional_output1...optional_outputN] -- program [arg1...argn]" % sys.argv[0])

args = sys.argv
try:
  split_at = args.index("--")
except ValueError:
  usage()
optional_outputs = args[1:split_at]
wrapped_program_args = args[split_at + 1 :]
if len(wrapped_program_args) < 1:
  usage()

subprocess.check_call(wrapped_program_args)

for f in optional_outputs:
  if not os.path.exists(f):
    # Create f if it does not exists.
    open(f, "a").close()