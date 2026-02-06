// Copyright 2024 The Bazel Authors. All rights reserved.
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

//! Test file with multiple tests for verifying sharding support.
//!
//! These tests are intentionally trivial - their purpose is to provide multiple
//! enumerable test functions that can be partitioned across shards. The BUILD
//! file runs this with `shard_count = 3`, so these 6 tests should be split
//! ~2 per shard. The sharding wrapper script enumerates tests via `--list`,
//! assigns each to a shard based on `index % shard_count`, and runs only the
//! subset for the current shard.

#[cfg(test)]
mod tests {
    #[test]
    fn test_1() {}

    #[test]
    fn test_2() {}

    #[test]
    fn test_3() {}

    #[test]
    fn test_4() {}

    #[test]
    fn test_5() {}

    #[test]
    fn test_6() {}
}
