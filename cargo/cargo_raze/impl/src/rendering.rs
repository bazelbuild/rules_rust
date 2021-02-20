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

pub mod bazel;

use crate::planning::PlannedBuild;
use anyhow::Result;
use std::path::PathBuf;

pub trait BuildRenderer {
  fn render_planned_build(
    &mut self,
    render_details: &RenderDetails,
    planned_build: &PlannedBuild,
  ) -> Result<Vec<FileOutputs>>;
  fn render_remote_planned_build(
    &mut self,
    render_details: &RenderDetails,
    planned_build: &PlannedBuild,
  ) -> Result<Vec<FileOutputs>>;
}

#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord)]
pub struct FileOutputs {
  pub path: PathBuf,
  pub contents: String,
}

#[derive(Debug, Clone)]
pub struct RenderDetails {
  pub cargo_root: PathBuf,
  pub path_prefix: PathBuf,
  pub package_aliases_dir: String,
  pub vendored_buildfile_name: String,
  pub bazel_root: PathBuf,
  pub rust_rules_workspace_name: String,
  pub experimental_api: bool,
  pub render_package_aliases: bool,
}
