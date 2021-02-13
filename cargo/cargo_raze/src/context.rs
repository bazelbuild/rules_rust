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

use std::path::PathBuf;

use crate::settings::CrateSettings;
use semver::Version;
use serde::Serialize;

/// A struct containing information about a crate's dependency that's buildable in Bazel
#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Serialize)]
pub struct BuildableDependency {
  // Note: Buildifier-compliant BUILD file generation depends on correct sorting of collections
  // of this struct by `buildable_target`. Do not add fields preceeding this field.
  pub buildable_target: String,
  pub name: String,
  pub version: Version,
  pub is_proc_macro: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Serialize)]
pub struct DependencyAlias {
  pub target: String,
  pub alias: String,
}

#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Serialize)]
pub struct BuildableTarget {
  pub kind: String,
  pub name: String,

  /// The path in Bazel's format (i.e. with forward slashes) to the target's entry point.
  pub path: String,
  pub edition: String,
}

#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Serialize)]
pub struct Metadep {
  pub name: String,
  pub min_version: Version,
}

#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Serialize)]
pub struct LicenseData {
  pub name: String,
  pub rating: String,
}

impl Default for LicenseData {
  fn default() -> Self {
    LicenseData {
      name: "no license".into(),
      rating: "restricted".into(),
    }
  }
}

#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Serialize)]
pub struct GitRepo {
  pub remote: String,
  pub commit: String,

  // Directory containing the crate's Cargo.toml file, relative to the git repo root.
  // Will be None iff the crate lives at the root of the git repo.
  pub path_to_crate_root: Option<String>,
}

#[derive(Debug, Clone, Serialize)]
pub struct SourceDetails {
  pub git_data: Option<GitRepo>,
}

#[derive(Debug, Clone, Serialize, PartialEq, Eq, PartialOrd, Ord)]
pub struct CrateDependencyContext {
  pub dependencies: Vec<BuildableDependency>,
  pub proc_macro_dependencies: Vec<BuildableDependency>,
  // data_dependencies can only be set when using cargo-raze as a library at the moment.
  pub data_dependencies: Vec<BuildableDependency>,
  pub build_dependencies: Vec<BuildableDependency>,
  pub build_proc_macro_dependencies: Vec<BuildableDependency>,
  // build_data_dependencies can only be set when using cargo-raze as a library at the moment.
  pub build_data_dependencies: Vec<BuildableDependency>,
  pub dev_dependencies: Vec<BuildableDependency>,
  pub aliased_dependencies: Vec<DependencyAlias>,
}

impl CrateDependencyContext {
  pub fn contains(&self, name: &str, version: Version) -> bool {
    let condition = |dep: &BuildableDependency| dep.name.eq(&name) && dep.version.eq(&version);
    self.dependencies.iter().any(condition)
      || self.proc_macro_dependencies.iter().any(condition)
      || self.build_dependencies.iter().any(condition)
      || self.build_proc_macro_dependencies.iter().any(condition)
      || self.dev_dependencies.iter().any(condition)
  }
}

#[derive(Debug, Clone, Serialize, PartialEq, Eq, PartialOrd, Ord)]
pub struct CrateTargetedDepContext {
  pub target: String,
  pub deps: CrateDependencyContext,
  pub conditions: Vec<String>,
}

#[derive(Debug, Clone, Serialize)]
pub struct CrateContext {
  pub pkg_name: String,
  pub pkg_version: Version,
  pub edition: String,
  pub raze_settings: CrateSettings,
  pub canonical_additional_build_file: Option<PathBuf>,
  pub default_deps: CrateDependencyContext,
  pub targeted_deps: Vec<CrateTargetedDepContext>,
  pub license: LicenseData,
  pub features: Vec<String>,
  pub workspace_path_to_crate: String,
  pub workspace_member_dependents: Vec<PathBuf>,
  pub workspace_member_dev_dependents: Vec<PathBuf>,
  pub is_workspace_member_dependency: bool,
  pub is_binary_dependency: bool,
  pub targets: Vec<BuildableTarget>,
  pub build_script_target: Option<BuildableTarget>,
  pub links: Option<String>,
  pub source_details: SourceDetails,
  pub sha256: Option<String>,
  pub registry_url: String,

  // TODO(acmcarther): This is used internally by renderer to know where to put the build file. It
  // probably should live somewhere else. Renderer params (separate from context) should live
  // somewhere more explicit.
  //
  // I'm punting on this now because this requires a more serious look at the renderer code.
  pub expected_build_path: String,

  // The name of the main lib target for this crate (if present).
  // Currently only one such lib can exist per crate.
  pub lib_target_name: Option<String>,
  // This field tracks whether or not the lib target of `lib_target_name`
  // is a proc_macro library or not.
  pub is_proc_macro: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Serialize)]
pub struct WorkspaceContext {
  // The bazel path prefix to the vendor directory
  pub workspace_path: String,

  // The generated new_http_library Bazel workspace prefix.
  //
  // This has no effect unless the GenMode setting is Remote.
  pub gen_workspace_prefix: String,

  // The file extension of generated BUILD files.
  //
  // Bare files will just be named after this setting. Named files, such as those passed to
  // repository rules, will take the form of $prefix.$this_value.
  pub output_buildfile_suffix: String,

  // A list of relative paths from a Cargo workspace root to a Cargo package.
  pub workspace_members: Vec<PathBuf>,
}
