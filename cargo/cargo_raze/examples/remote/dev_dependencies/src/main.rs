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

use std::io::{stdout, BufWriter};

fn main() {
  let out = b"Hello fellow Rustaceans!";
  let width = 24;

  let mut writer = BufWriter::new(stdout());
  ferris_says::say(out, width, &mut writer).unwrap();
}

#[cfg(test)]
mod tests {
  use super::*;

  use indoc::indoc;

  #[test]
  fn test_dev_dependencies() {
    let out = indoc! { b"
      Hello fellow Rustaceans!
    " };
    let width = 24;

    let mut writer = BufWriter::new(stdout());
    ferris_says::say(out, width, &mut writer).unwrap();
  }
}
