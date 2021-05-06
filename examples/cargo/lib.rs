// Copyright 2020 The Bazel Authors. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// theoretically this should be safe, as unit tests are built without
// optimizations
#![allow(clippy::assertions_on_constants)]
mod test {
    #[test]
    fn test_env_contents() {
        assert_eq!(env!("FOO"), "BAR");
        assert_eq!(env!("BAR"), "FOO");
    }

    #[test]
    fn test_cfg_contents() {
        assert!(cfg!(foobar));
    }

    #[test]
    fn test_rustc_contents() {
        assert!(cfg!(blah = "bleh"));
    }

    #[test]
    fn test_access_data() {
        assert!(cfg!(data = "Yeah!"));
    }
}
