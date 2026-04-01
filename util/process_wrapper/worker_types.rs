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

//! Strongly typed worker identifiers and paths.

use std::fmt;
use std::path::Path;

/// Key from `--pipelining-key=...`.
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct PipelineKey(pub String);

impl PipelineKey {
    pub fn as_str(&self) -> &str {
        &self.0
    }
}

impl fmt::Display for PipelineKey {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.0)
    }
}

/// Bazel worker request id. `0` is singleplex.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct RequestId(pub i64);

impl RequestId {
    /// Returns true when `requestId == 0`.
    pub fn is_singleplex(&self) -> bool {
        self.0 == 0
    }
}

impl fmt::Display for RequestId {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.0)
    }
}

/// Path from `WorkRequest.sandbox_dir`.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SandboxDir(pub String);

impl SandboxDir {
    pub fn as_str(&self) -> &str {
        &self.0
    }

    pub fn as_path(&self) -> &Path {
        Path::new(&self.0)
    }
}

impl fmt::Display for SandboxDir {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.0)
    }
}

/// rustc `--out-dir` value.
#[derive(Debug, Clone)]
pub struct OutputDir(pub String);

impl OutputDir {
    pub fn as_str(&self) -> &str {
        &self.0
    }

    pub fn as_path(&self) -> &Path {
        Path::new(&self.0)
    }
}

impl fmt::Display for OutputDir {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.0)
    }
}

impl Default for OutputDir {
    fn default() -> Self {
        OutputDir(String::new())
    }
}
