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

use anyhow::Result;
use pathdiff::diff_paths;
use tera::{self, Context, Tera};

use crate::{
  context::{CrateContext, WorkspaceContext},
  error::RazeError,
  planning::PlannedBuild,
  rendering::{BuildRenderer, FileOutputs, RenderDetails},
};

use std::{error::Error, path::Path};

macro_rules! unwind_tera_error {
  ($err:ident) => {{
    let mut messages = vec![$err.to_string()];
    let mut cause = $err.source();
    while let Some(e) = cause {
      messages.push(e.to_string());
      cause = e.source();
    }
    messages.join("\n|__")
  }};
}

// A Bazel block that exposts the `crates.bz` files renderd in Remote genmode
const EXPORTS_FILES: &str = r#"
# Export file for Stardoc support
exports_files(
    [
        "crates.bzl",
    ],
    visibility = ["//visibility:public"],
)
"#;

#[derive(Default)]
pub struct BazelRenderer {
  internal_renderer: Tera,
}

/// Generate the expected Bazel package name
fn bazel_package_name(render_details: &RenderDetails) -> String {
  if let Some(package_name) = diff_paths(&render_details.cargo_root, &render_details.bazel_root) {
    package_name.display().to_string().replace("\\", "/")
  } else {
    "".to_owned()
  }
}

impl BazelRenderer {
  pub fn new() -> Self {
    // Configure tera with a bogus template dir: We don't want any runtime template support
    let mut internal_renderer = Tera::new("/tmp/cargo-raze/doesnt/exist/*").unwrap();
    internal_renderer
      .add_raw_templates(vec![
        (
          "templates/crate.BUILD.template",
          include_str!("templates/crate.BUILD.template"),
        ),
        (
          "templates/partials/build_script.template",
          include_str!("templates/partials/build_script.template"),
        ),
        (
          "templates/partials/common_attrs.template",
          include_str!("templates/partials/common_attrs.template"),
        ),
        (
          "templates/partials/crates_macro.template",
          include_str!("templates/partials/crates_macro.template"),
        ),
        (
          "templates/partials/header.template",
          include_str!("templates/partials/header.template"),
        ),
        (
          "templates/partials/remote_crates_patch.template",
          include_str!("templates/partials/remote_crates_patch.template"),
        ),
        (
          "templates/partials/rust_binary.template",
          include_str!("templates/partials/rust_binary.template"),
        ),
        (
          "templates/partials/rust_library.template",
          include_str!("templates/partials/rust_library.template"),
        ),
        (
          "templates/partials/targeted_dependencies.template",
          include_str!("templates/partials/targeted_dependencies.template"),
        ),
        (
          "templates/remote_crates.bzl.template",
          include_str!("templates/remote_crates.bzl.template"),
        ),
        (
          "templates/workspace.BUILD.template",
          include_str!("templates/workspace.BUILD.template"),
        ),
      ])
      .unwrap();

    Self {
      internal_renderer,
    }
  }

  pub fn render_crate(
    &self,
    workspace_context: &WorkspaceContext,
    package: &CrateContext,
    rust_rules_workspace_name: &str,
  ) -> Result<String, tera::Error> {
    let mut context = Context::new();
    context.insert("workspace", &workspace_context);
    context.insert("crate", &package);
    context.insert("rust_rules_workspace_name", rust_rules_workspace_name);
    self
      .internal_renderer
      .render("templates/crate.BUILD.template", &context)
  }

  pub fn render_vendored_aliases(
    &self,
    workspace_context: &WorkspaceContext,
    all_packages: &[CrateContext],
  ) -> Result<String, tera::Error> {
    let mut context = Context::new();
    context.insert("workspace", &workspace_context);
    context.insert("crates", &all_packages);
    context.insert("is_remote_mode", &false);
    self
      .internal_renderer
      .render("templates/workspace.BUILD.template", &context)
  }

  pub fn render_remote_crate(
    &self,
    workspace_context: &WorkspaceContext,
    package: &CrateContext,
    rust_rules_workspace_name: &str,
  ) -> Result<String, tera::Error> {
    let mut context = Context::new();
    context.insert("workspace", &workspace_context);
    context.insert("crate", &package);
    context.insert("rust_rules_workspace_name", rust_rules_workspace_name);
    self
      .internal_renderer
      .render("templates/crate.BUILD.template", &context)
  }

  pub fn render_remote_aliases(
    &self,
    workspace_context: &WorkspaceContext,
    all_packages: &[CrateContext],
  ) -> Result<String, tera::Error> {
    let mut context = Context::new();
    context.insert("workspace", &workspace_context);
    context.insert("crates", &all_packages);
    context.insert("is_remote_mode", &true);
    self
      .internal_renderer
      .render("templates/workspace.BUILD.template", &context)
  }

  pub fn render_crates_bzl(
    &self,
    workspace_context: &WorkspaceContext,
    all_packages: &[CrateContext],
    bazel_package_name: &str,
    is_remote_genmode: bool,
    experimental_api: bool,
  ) -> Result<String, tera::Error> {
    let mut context = Context::new();
    context.insert("workspace", &workspace_context);
    context.insert("crates", &all_packages);
    context.insert("bazel_package_name", &bazel_package_name);
    context.insert("is_remote_genmode", &is_remote_genmode);
    context.insert("experimental_api", &experimental_api);
    self
      .internal_renderer
      .render("templates/remote_crates.bzl.template", &context)
  }

  pub fn render_aliases(
    &self,
    planned_build: &PlannedBuild,
    render_details: &RenderDetails,
    is_remote_mode: bool,
  ) -> Result<Vec<FileOutputs>> {
    let mut file_outputs = Vec::new();
    for member_path in planned_build.workspace_context.workspace_members.iter() {
      let all_packages: Vec<CrateContext> = planned_build
        .crate_contexts
        .iter()
        .filter(|ctx| {
          ctx.is_binary_dependency
            || ctx.workspace_member_dependents.contains(member_path)
            || ctx.workspace_member_dev_dependents.contains(member_path)
        })
        .cloned()
        .collect();

      let mut rendered_alias_build_file = if is_remote_mode {
        self
          .render_remote_aliases(&planned_build.workspace_context, &all_packages)
          .map_err(|e| RazeError::Rendering {
            crate_name_opt: None,
            message: unwind_tera_error!(e),
          })?
      } else {
        self
          .render_vendored_aliases(&planned_build.workspace_context, &all_packages)
          .map_err(|e| RazeError::Rendering {
            crate_name_opt: None,
            message: unwind_tera_error!(e),
          })?
      };

      // Only the root package will have a `crates.bzl` file to export
      let is_root_workspace_member = member_path
        .to_str()
        // Root workspace paths will are represented by an exmpty string
        .map(|member_path| member_path.is_empty())
        .unwrap_or(false);
      if is_root_workspace_member {
        // In remote genmode, a `crates.bzl` file will always be rendered. For
        // vendored genmode, one is only rendered when using the experimental
        // api so it would otherwise be incorrect to export a nonexistent file.
        if is_remote_mode || render_details.experimental_api {
          rendered_alias_build_file += EXPORTS_FILES;
        }
      }

      file_outputs.push(FileOutputs {
        path: render_details
          .cargo_root
          .join(member_path)
          .join(&render_details.package_aliases_dir)
          .join("BUILD.bazel"),
        contents: rendered_alias_build_file,
      });
    }
    Ok(file_outputs)
  }

  fn render_crates_bzl_package_file(
    &self,
    path_prefix: &Path,
    file_outputs: &[FileOutputs],
  ) -> Result<Option<FileOutputs>> {
    let crates_bzl_pkg_file = path_prefix.join("BUILD.bazel");
    let outputs_contain_crates_bzl_build_file = file_outputs
      .iter()
      .any(|output| output.path == crates_bzl_pkg_file);
    if outputs_contain_crates_bzl_build_file {
      return Ok(None);
    }

    let mut contents = self
      .internal_renderer
      .render("templates/partials/header.template", &tera::Context::new())?;

    contents += EXPORTS_FILES;

    Ok(Some(FileOutputs {
      path: crates_bzl_pkg_file,
      contents,
    }))
  }
}

fn include_additional_build_file(
  package: &CrateContext,
  existing_contents: String,
) -> Result<String> {
  match &package.canonical_additional_build_file {
    Some(file_path) => {
      assert!(
        package.raze_settings.additional_build_file.is_some(),
        "The raze_settings.additional_build_file should always be set if \
         canonical_additional_build_file is set"
      );
      let additional_content =
        std::fs::read_to_string(file_path).map_err(|e| RazeError::Rendering {
          crate_name_opt: Some(package.pkg_name.to_owned()),
          message: format!(
            "failed to read additional_build_file '{}': {}",
            file_path.display(),
            e
          ),
        })?;

      Ok(format!(
        "{}\n# Additional content from {}\n{}",
        existing_contents,
        // UNWRAP: Safe due to assert above
        package
          .raze_settings
          .additional_build_file
          .as_ref()
          .unwrap()
          .display(),
        additional_content
      ))
    },
    None => Ok(existing_contents),
  }
}

impl BuildRenderer for BazelRenderer {
  fn render_planned_build(
    &mut self,
    render_details: &RenderDetails,
    planned_build: &PlannedBuild,
  ) -> Result<Vec<FileOutputs>> {
    let &PlannedBuild {
      ref workspace_context,
      ref crate_contexts,
      ..
    } = planned_build;
    let mut file_outputs = Vec::new();
    let path_prefix = render_details
      .bazel_root
      .as_path()
      .join(&render_details.path_prefix);

    if render_details.experimental_api {
      let crates_bzl_file_path = path_prefix.as_path().join("crates.bzl");
      let rendered_crates_bzl_file = self
        .render_crates_bzl(
          &workspace_context,
          &crate_contexts,
          &bazel_package_name(render_details),
          /*is_remote_genmode=*/ false,
          render_details.experimental_api,
        )
        .map_err(|e| RazeError::Rendering {
          crate_name_opt: None,
          message: unwind_tera_error!(e),
        })?;
      file_outputs.push(FileOutputs {
        path: crates_bzl_file_path,
        contents: rendered_crates_bzl_file,
      });

      if render_details.render_package_aliases {
        file_outputs.extend(self.render_aliases(planned_build, render_details, false)?);
      }

      // Ensure there is always a `BUILD.bazel` file to accompany `crates.bzl`
      if let Some(rendered_output) =
        self.render_crates_bzl_package_file(&path_prefix, &file_outputs)?
      {
        file_outputs.push(rendered_output);
      }
    } else {
      file_outputs.extend(self.render_aliases(planned_build, render_details, false)?);
    }

    for package in crate_contexts {
      let rendered_crate_build_file = self
        .render_crate(
          &workspace_context,
          &package,
          &render_details.rust_rules_workspace_name,
        )
        .map_err(|e| RazeError::Rendering {
          crate_name_opt: None,
          message: unwind_tera_error!(e),
        })?;

      let final_crate_build_file =
        include_additional_build_file(package, rendered_crate_build_file)?;

      file_outputs.push(FileOutputs {
        path: path_prefix.as_path().join(&package.expected_build_path),
        contents: final_crate_build_file,
      })
    }

    file_outputs.sort();
    Ok(file_outputs)
  }

  fn render_remote_planned_build(
    &mut self,
    render_details: &RenderDetails,
    planned_build: &PlannedBuild,
  ) -> Result<Vec<FileOutputs>> {
    let &PlannedBuild {
      ref workspace_context,
      ref crate_contexts,
      ..
    } = planned_build;
    let mut file_outputs: Vec<FileOutputs> = Vec::new();

    let path_prefix = render_details
      .bazel_root
      .as_path()
      .join(&render_details.path_prefix);
    let buildfile_suffix = &render_details.vendored_buildfile_name;

    // N.B. File needs to exist so that contained xyz-1.2.3.BUILD can be referenced
    file_outputs.push(FileOutputs {
      path: path_prefix.as_path().join("remote").join(buildfile_suffix),
      contents: String::new(),
    });

    for package in crate_contexts {
      let rendered_crate_build_file = self
        .render_remote_crate(
          &workspace_context,
          &package,
          &render_details.rust_rules_workspace_name,
        )
        .map_err(|e| RazeError::Rendering {
          crate_name_opt: Some(package.pkg_name.to_owned()),
          message: unwind_tera_error!(e),
        })?;

      let final_crate_build_file =
        include_additional_build_file(package, rendered_crate_build_file)?;

      file_outputs.push(FileOutputs {
        path: path_prefix.as_path().join(&package.expected_build_path),
        contents: final_crate_build_file,
      })
    }

    if render_details.render_package_aliases {
      file_outputs.extend(self.render_aliases(planned_build, render_details, true)?);
    }

    let crates_bzl_file_path = path_prefix.as_path().join("crates.bzl");
    let rendered_bzl_fetch_file = self
      .render_crates_bzl(
        &workspace_context,
        &crate_contexts,
        &bazel_package_name(render_details),
        /*is_remote_genmode=*/ true,
        render_details.experimental_api,
      )
      .map_err(|e| RazeError::Rendering {
        crate_name_opt: None,
        message: unwind_tera_error!(e),
      })?;

    file_outputs.push(FileOutputs {
      path: crates_bzl_file_path,
      contents: rendered_bzl_fetch_file,
    });

    // Optionally write out a unique lockfile for Cargo Raze. This happens in the case
    // where a project has specified binary dependencies.
    if let Some(lockfile) = &planned_build.lockfile {
      file_outputs.push(FileOutputs {
        path: path_prefix.as_path().join("Cargo.raze.lock"),
        contents: lockfile.to_string(),
      });
    }

    // Ensure there is always a `BUILD.bazel` file to accompany `crates.bzl`
    if let Some(rendered_output) =
      self.render_crates_bzl_package_file(&path_prefix, &file_outputs)?
    {
      file_outputs.push(rendered_output);
    }

    file_outputs.sort();
    Ok(file_outputs)
  }
}

#[cfg(test)]
mod tests {
  use hamcrest2::{core::expect, prelude::*};

  use semver::Version;
  use tempfile::TempDir;

  use crate::{
    context::*,
    planning::PlannedBuild,
    rendering::{FileOutputs, RenderDetails},
    settings::CrateSettings,
    testing::basic_lock_contents,
  };

  use super::*;

  use std::{fs, path::PathBuf, str::FromStr};

  fn dummy_render_details(buildfile_suffix: &str) -> RenderDetails {
    RenderDetails {
      cargo_root: PathBuf::from("/some/cargo/root"),
      path_prefix: PathBuf::from("./some_render_prefix"),
      package_aliases_dir: "cargo".to_string(),
      vendored_buildfile_name: buildfile_suffix.to_owned(),
      bazel_root: PathBuf::from("/some/bazel/root"),
      rust_rules_workspace_name: "rules_rust".to_owned(),
      experimental_api: true,
      render_package_aliases: true,
    }
  }

  fn dummy_planned_build(crate_contexts: Vec<CrateContext>) -> PlannedBuild {
    PlannedBuild {
      workspace_context: WorkspaceContext {
        workspace_path: "//workspace/prefix".to_owned(),
        gen_workspace_prefix: "".to_owned(),
        output_buildfile_suffix: "BUILD".to_owned(),
        // This will typically resolve to:
        // `/some/cargo/root/some/crate`
        workspace_members: vec![PathBuf::from("some/crate")],
      },
      crate_contexts,
      lockfile: None,
    }
  }

  fn dummy_binary_crate_with_name(buildfile_suffix: &str) -> CrateContext {
    CrateContext {
      pkg_name: "test-binary".to_owned(),
      pkg_version: Version::parse("1.1.1").unwrap(),
      edition: "2015".to_owned(),
      features: vec!["feature1".to_owned(), "feature2".to_owned()].to_owned(),
      expected_build_path: format!("vendor/test-binary-1.1.1/{}", buildfile_suffix),
      license: LicenseData::default(),
      raze_settings: CrateSettings::default(),
      canonical_additional_build_file: CrateSettings::default().additional_build_file,
      default_deps: CrateDependencyContext {
        dependencies: Vec::new(),
        proc_macro_dependencies: Vec::new(),
        data_dependencies: Vec::new(),
        build_dependencies: Vec::new(),
        build_proc_macro_dependencies: Vec::new(),
        build_data_dependencies: Vec::new(),
        dev_dependencies: Vec::new(),
        aliased_dependencies: Vec::new(),
      },
      targeted_deps: Vec::new(),
      workspace_member_dependents: Vec::new(),
      workspace_member_dev_dependents: Vec::new(),
      is_workspace_member_dependency: false,
      is_binary_dependency: false,
      is_proc_macro: false,
      workspace_path_to_crate: "@raze__test_binary__1_1_1//".to_owned(),
      targets: vec![BuildableTarget {
        name: "some_binary".to_owned(),
        kind: "bin".to_owned(),
        path: "bin/main.rs".to_owned(),
        edition: "2015".to_owned(),
      }],
      build_script_target: None,
      links: None,
      source_details: SourceDetails {
        git_data: None,
      },
      sha256: None,
      registry_url: "https://crates.io/api/v1/crates/test-binary/1.1.1/download".to_string(),
      lib_target_name: None,
    }
  }

  fn dummy_binary_crate() -> CrateContext {
    return dummy_binary_crate_with_name("BUILD");
  }

  fn dummy_library_crate_with_name(buildfile_suffix: &str) -> CrateContext {
    CrateContext {
      pkg_name: "test-library".to_owned(),
      pkg_version: Version::parse("1.1.1").unwrap(),
      edition: "2015".to_owned(),
      license: LicenseData::default(),
      raze_settings: CrateSettings::default(),
      canonical_additional_build_file: CrateSettings::default().additional_build_file,
      features: vec!["feature1".to_owned(), "feature2".to_owned()].to_owned(),
      expected_build_path: format!("vendor/test-library-1.1.1/{}", buildfile_suffix),
      default_deps: CrateDependencyContext {
        dependencies: Vec::new(),
        proc_macro_dependencies: Vec::new(),
        data_dependencies: Vec::new(),
        build_dependencies: Vec::new(),
        build_proc_macro_dependencies: Vec::new(),
        build_data_dependencies: Vec::new(),
        dev_dependencies: Vec::new(),
        aliased_dependencies: Vec::new(),
      },
      targeted_deps: Vec::new(),
      workspace_member_dependents: Vec::new(),
      workspace_member_dev_dependents: Vec::new(),
      is_workspace_member_dependency: false,
      is_binary_dependency: false,
      is_proc_macro: false,
      workspace_path_to_crate: "@raze__test_library__1_1_1//".to_owned(),
      targets: vec![BuildableTarget {
        name: "some_library".to_owned(),
        kind: "lib".to_owned(),
        path: "path/lib.rs".to_owned(),
        edition: "2015".to_owned(),
      }],
      build_script_target: None,
      links: Some("ssh2".to_owned()),
      source_details: SourceDetails {
        git_data: None,
      },
      sha256: None,
      registry_url: "https://crates.io/api/v1/crates/test-binary/1.1.1/download".to_string(),
      lib_target_name: Some("test_library".to_owned()),
    }
  }

  fn dummy_library_crate() -> CrateContext {
    return dummy_library_crate_with_name("BUILD");
  }

  fn extract_contents_matching_path(file_outputs: &Vec<FileOutputs>, file_name: &str) -> String {
    println!("Known files :{:?}", file_outputs);
    let mut matching_files_contents = file_outputs
      .iter()
      .filter(|output| output.path.starts_with(file_name))
      .map(|output| output.contents.to_owned())
      .collect::<Vec<String>>();

    assert_that!(matching_files_contents.len(), equal_to(1));
    matching_files_contents.pop().unwrap()
  }

  fn render_crates_for_test_with_name(
    buildfile_suffix: &str,
    crate_contexts: Vec<CrateContext>,
  ) -> Vec<FileOutputs> {
    BazelRenderer::new()
      .render_planned_build(
        &dummy_render_details(buildfile_suffix),
        &dummy_planned_build(crate_contexts),
      )
      .unwrap()
  }

  fn render_crates_for_test(crate_contexts: Vec<CrateContext>) -> Vec<FileOutputs> {
    return render_crates_for_test_with_name("BUILD", crate_contexts);
  }

  #[test]
  fn all_plans_contain_root_build_file() {
    let file_outputs = render_crates_for_test(Vec::new());
    let file_names = file_outputs
      .iter()
      .map(|output| output.path.display().to_string())
      .collect::<Vec<String>>();

    assert_that!(
      &file_names,
      contains(vec![
        "/some/bazel/root/./some_render_prefix/BUILD.bazel".to_owned(),
        "/some/bazel/root/./some_render_prefix/crates.bzl".to_owned(),
        "/some/cargo/root/some/crate/cargo/BUILD.bazel".to_owned(),
      ])
      .exactly()
    );
  }

  #[test]
  fn crates_generate_build_files() {
    let file_outputs = render_crates_for_test(vec![dummy_library_crate()]);
    let file_names = file_outputs
      .iter()
      .map(|output| output.path.display().to_string())
      .collect::<Vec<String>>();

    assert_that!(
      &file_names,
      contains(vec![
        "/some/bazel/root/./some_render_prefix/BUILD.bazel".to_owned(),
        "/some/bazel/root/./some_render_prefix/crates.bzl".to_owned(),
        "/some/bazel/root/./some_render_prefix/vendor/test-library-1.1.1/BUILD".to_owned(),
        "/some/cargo/root/some/crate/cargo/BUILD.bazel".to_owned(),
      ])
      .exactly()
    );
  }

  #[test]
  fn crates_generate_build_files_bazel() {
    let file_outputs = render_crates_for_test_with_name(
      "BUILD.bazel",
      vec![dummy_library_crate_with_name("BUILD.bazel")],
    );
    let file_names = file_outputs
      .iter()
      .map(|output| output.path.display().to_string())
      .collect::<Vec<String>>();

    assert_that!(
      &file_names,
      contains(vec![
        "/some/bazel/root/./some_render_prefix/BUILD.bazel".to_owned(),
        "/some/bazel/root/./some_render_prefix/crates.bzl".to_owned(),
        "/some/bazel/root/./some_render_prefix/vendor/test-library-1.1.1/BUILD.bazel".to_owned(),
        "/some/cargo/root/some/crate/cargo/BUILD.bazel".to_owned(),
      ])
      .exactly()
    );
  }

  #[test]
  fn workspace_member_dependencies_get_build_aliases() {
    let mut context = dummy_library_crate();
    context.is_workspace_member_dependency = true;
    context
      .workspace_member_dependents
      .push(PathBuf::from("some/crate"));

    let file_outputs = render_crates_for_test(vec![context]);
    let workspace_crate_build_contents = extract_contents_matching_path(
      &file_outputs,
      "/some/cargo/root/some/crate/cargo/BUILD.bazel",
    );

    expect(
      workspace_crate_build_contents.contains("alias"),
      format!(
        "expected root build contents to contain an alias for test-library crate, but it just \
         contained [{}]",
        workspace_crate_build_contents
      ),
    )
    .unwrap();
  }

  #[test]
  fn non_workspace_crates_dont_get_build_aliases() {
    let mut non_workspace_crate = dummy_library_crate();
    non_workspace_crate.workspace_member_dependents = Vec::new();
    non_workspace_crate.is_workspace_member_dependency = false;

    let file_outputs = render_crates_for_test(vec![non_workspace_crate]);
    let root_build_contents = extract_contents_matching_path(
      &file_outputs,
      "/some/cargo/root/some/crate/cargo/BUILD.bazel",
    );

    expect(
      !root_build_contents.contains("alias"),
      format!(
        "expected root build contents not to contain an alias for test-library crate, but it just \
         contained [{}]",
        root_build_contents
      ),
    )
    .unwrap();
  }

  #[test]
  fn binaries_get_rust_binary_rules() {
    let file_outputs = render_crates_for_test(vec![dummy_binary_crate()]);
    let crate_build_contents = extract_contents_matching_path(
      &file_outputs,
      "/some/bazel/root/./some_render_prefix/vendor/test-binary-1.1.1/BUILD",
    );

    expect(
      crate_build_contents.contains("rust_binary("),
      format!(
        "expected crate build contents to contain rust_binary, but it just contained [{}]",
        crate_build_contents
      ),
    )
    .unwrap();
  }

  #[test]
  fn libraries_get_rust_library_rules() {
    let file_outputs = render_crates_for_test(vec![dummy_library_crate()]);
    let crate_build_contents = extract_contents_matching_path(
      &file_outputs,
      "/some/bazel/root/./some_render_prefix/vendor/test-library-1.1.1/BUILD",
    );

    expect(
      crate_build_contents.contains("rust_library("),
      format!(
        "expected crate build contents to contain rust_library, but it just contained [{}]",
        crate_build_contents
      ),
    )
    .unwrap();
  }

  #[test]
  fn additional_build_file_missing_file_failure() {
    let render_result = BazelRenderer::new().render_planned_build(
      &dummy_render_details("BUILD"),
      &dummy_planned_build(vec![CrateContext {
        raze_settings: CrateSettings {
          additional_build_file: Some("non-existent-file".into()),
          ..Default::default()
        },
        canonical_additional_build_file: Some("non-existent-file".into()),
        ..dummy_library_crate()
      }]),
    );

    assert_that!(render_result, err());
  }

  #[test]
  fn additional_build_file_included() {
    let tmp_dir = TempDir::new().unwrap();
    fs::write(
      tmp_dir.as_ref().join("some_additional_build_file"),
      "This is some additional BUILD file.",
    )
    .unwrap();

    let additional_build_file = tmp_dir.as_ref().join("some_additional_build_file");

    let file_outputs = render_crates_for_test(vec![CrateContext {
      raze_settings: CrateSettings {
        additional_build_file: Some(additional_build_file.clone()),
        ..Default::default()
      },
      canonical_additional_build_file: Some(additional_build_file.clone()),
      ..dummy_library_crate()
    }]);

    let file_name =
      "/some/bazel/root/./some_render_prefix/vendor/test-library-1.1.1/BUILD".to_owned();
    let crate_build_contents = extract_contents_matching_path(&file_outputs, &file_name);

    expect(
      crate_build_contents.contains(&format!(
        "# Additional content from {}",
        additional_build_file.display()
      )),
      format!(
        "expected crate build contents to include additional_build_file, but it just contained \
         [{}]",
        crate_build_contents
      ),
    )
    .unwrap();
  }

  #[test]
  fn test_generate_lockfile() {
    let render_details = dummy_render_details("BUILD.bazel");
    let mut planned_build = dummy_planned_build(Vec::new());
    planned_build.lockfile = Some(cargo_lock::Lockfile::from_str(basic_lock_contents()).unwrap());

    let render_result = BazelRenderer::new()
      .render_remote_planned_build(&render_details, &planned_build)
      .unwrap();

    // Ensure that the lockfiles for binary dependencies get written out propperly
    assert!(render_result.iter().any(|file_output| {
      file_output.path == PathBuf::from("/some/bazel/root/./some_render_prefix/Cargo.raze.lock")
        && file_output.contents
          == indoc::formatdoc! { r#"
              # This file is automatically @generated by Cargo.
              # It is not intended for manual editing.
              [[package]]
              name = "test"
              version = "0.0.1"
            "# }
    }))
  }
}
