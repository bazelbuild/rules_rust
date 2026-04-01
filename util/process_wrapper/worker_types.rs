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

//! Newtype wrappers for domain values used throughout the worker pipelining code.
//!
//! These types prevent mismatched pairs (e.g. passing a request ID where a pipeline
//! key is expected) and make function signatures self-documenting.

use std::fmt;
use std::path::Path;

/// Identifies a pipelining pipeline — the crate being compiled.
/// Derived from `--pipelining-key=<value>` in rustc args.
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

/// Bazel worker request ID. Unique within a build invocation.
///
/// Singleplex requests use ID 0; multiplex requests use positive IDs.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct RequestId(pub i64);

impl RequestId {
    /// Returns true for singleplex requests (requestId == 0).
    pub fn is_singleplex(&self) -> bool {
        self.0 == 0
    }
}

impl fmt::Display for RequestId {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.0)
    }
}

/// Bazel sandbox directory path (from WorkRequest.sandbox_dir).
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

/// The --out-dir value for rustc output placement.
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
