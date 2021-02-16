// Copyright 2018 Google Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

use std::{
  io::{stdout, BufWriter},
  path::Path,
  process::Command,
};

fn main() {

  // Note: This will need to change if the dependency version changes
  let texture_synthesis_path =
    Path::new("./external/remote_binary_dependencies__texture_synthesis_cli__0_8_0/cargo_bin_texture_synthesis");
    

  // Run the command
  let texture_synthesis_output = Command::new(texture_synthesis_path)
    .arg("--help")
    .output()
    .unwrap();

  // Print the results
  let mut writer = BufWriter::new(stdout());
  ferris_says::say(&texture_synthesis_output.stdout, 120, &mut writer).unwrap();
}
