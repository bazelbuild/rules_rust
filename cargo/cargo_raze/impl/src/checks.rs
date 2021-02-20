// Copyright 2020 Google Inc.
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
  collections::{HashMap, HashSet},
  fs,
  path::Path,
  path::PathBuf,
};

use anyhow::{anyhow, Result};

use crate::{
  error::RazeError,
  metadata::RazeMetadata,
  settings::{CrateSettingsPerVersion, GenMode, RazeSettings},
  util::collect_up_to,
  util::package_ident,
};

use cargo_metadata::{Metadata, Package, PackageId};

// TODO(acmcarther): Consider including a switch to disable limiting
const MAX_DISPLAYED_MISSING_VENDORED_CRATES: usize = 5;
const MAX_DISPLAYED_MISSING_RESOLVE_PACKAGES: usize = 5;

/// Ensure that the given Metadata is valid and ready to use for planning.
pub fn check_metadata(
  raze_metadata: &RazeMetadata,
  settings: &RazeSettings,
  bazel_workspace_root: &Path,
) -> Result<()> {
  // Check for errors
  check_resolve_matches_packages(&raze_metadata.metadata)?;

  if settings.genmode == GenMode::Vendored {
    check_all_vendored(&raze_metadata.metadata, settings, bazel_workspace_root)?;
  }

  // Check for incomplete lockfiles
  if let Err(err) =
    check_lockfile_for_missing_checksums(&raze_metadata.metadata, &raze_metadata.checksums)
  {
    eprintln!("WARNING: {}", err);
  }

  // Check for unused crate settings
  warn_unused_settings(&settings.crates, &raze_metadata.metadata.packages);

  Ok(())
}

fn check_lockfile_for_missing_checksums(
  metadata: &Metadata,
  checksums: &HashMap<String, String>,
) -> Result<()> {
  let missing_checksums: Vec<String> = metadata
    .packages
    .iter()
    // Filter out workspace members
    .filter(|pkg| !metadata.workspace_members.contains(&pkg.id))
    // Filter out non crates.io sources
    .filter(|pkg| pkg.source.as_ref().map_or(false, |src| src.is_crates_io()))
    // Filter for missing checksums and save the package identifier
    .filter_map(|pkg| {
      let package_ident = package_ident(&pkg.name, &pkg.version.to_string());
      if !checksums.contains_key(&package_ident) {
        Some(package_ident)
      } else {
        None
      }
    })
    .collect();

  if !missing_checksums.is_empty() {
    let lockfile_path = metadata.workspace_root.join("Cargo.lock");
    if !lockfile_path.exists() {
      return Err(anyhow!(
        "Packages are missing checksums, perhaps `cargo generate-lockfile` needs to be run in the \
         current cargo workspace. Missing checksums: {:?}",
        missing_checksums
      ));
    }
    return Err(anyhow!(
      "Packages are missing checksums, perhaps `cargo update` needs to be run in the current \
       cargo workspace. Missing checksums: {:?}",
      missing_checksums
    ));
  }

  Ok(())
}

/// Verifies that all provided packages are vendored (in settings.vendor_dir relative to CWD)
fn check_all_vendored(
  metadata: &Metadata,
  settings: &RazeSettings,
  bazel_workspace_root: &Path,
) -> Result<()> {
  let non_workspace_packages: Vec<&Package> = metadata
    .packages
    .iter()
    .filter(|pkg| !metadata.workspace_members.contains(&pkg.id))
    .collect();

  let missing_package_ident_iter = non_workspace_packages
    .iter()
    .filter(|p| {
      fs::metadata(expected_vendored_path(
        p,
        bazel_workspace_root,
        &settings.workspace_path,
        &settings.vendor_dir,
      ))
      .is_err()
    })
    .map(|p| package_ident(&p.name, &p.version.to_string()));

  let limited_missing_crates = collect_up_to(
    MAX_DISPLAYED_MISSING_VENDORED_CRATES,
    missing_package_ident_iter,
  );

  if limited_missing_crates.is_empty() {
    return Ok(());
  }

  // Oops, missing some crates. Yield a nice message
  let expected_full_path = vendor_path(
    bazel_workspace_root,
    &settings.workspace_path,
    &settings.vendor_dir,
  );

  Err(
    RazeError::Planning {
      dependency_name_opt: None,
      message: format!(
        "Failed to find expected vendored crates in {:?}: {:?}. Did you forget to run cargo \
         vendor?",
        expected_full_path.display(),
        limited_missing_crates
      ),
    }
    .into(),
  )
}

fn vendor_path(bazel_workspace_root: &Path, workspace_path: &str, vendor_dir: &str) -> PathBuf {
  bazel_workspace_root
    // Trim the absolute label identifier from the start of the workspace path
    .join(workspace_path.trim_start_matches('/'))
    .join(vendor_dir)
}

/// Returns the packages expected path during current execution.
fn expected_vendored_path(
  package: &Package,
  bazel_workspace_root: &Path,
  workspace_path: &str,
  vendor_dir: &str,
) -> String {
  vendor_path(bazel_workspace_root, workspace_path, vendor_dir)
    .join(package_ident(&package.name, &package.version.to_string()))
    .display()
    .to_string()
}

fn check_resolve_matches_packages(metadata: &Metadata) -> Result<()> {
  let known_package_ids = metadata
    .packages
    .iter()
    .map(|p| p.id.clone())
    .collect::<HashSet<PackageId>>();

  let node_ids_missing_package_decl_iter = metadata
    .resolve
    .as_ref()
    .ok_or_else(|| RazeError::Generic("Missing resolve graph".into()))?
    .nodes
    .iter()
    .filter(|n| !known_package_ids.contains(&n.id))
    .map(|n| n.id.clone());
  let limited_missing_node_ids = collect_up_to(
    MAX_DISPLAYED_MISSING_RESOLVE_PACKAGES,
    node_ids_missing_package_decl_iter,
  );

  if limited_missing_node_ids.is_empty() {
    return Ok(());
  }

  // Oops, missing some package metadata. Yield a nice message
  Err(
    RazeError::Planning {
      dependency_name_opt: None,
      message: format!(
        "Failed to find metadata.packages which were expected from metadata.resolve {:?}. {}",
        limited_missing_node_ids,
        crate::error::PLEASE_FILE_A_BUG
      ),
    }
    .into(),
  )
}

fn warn_unused_settings(
  all_crate_settings: &HashMap<String, CrateSettingsPerVersion>,
  all_packages: &[Package],
) {
  let mut known_versions_per_crate = HashMap::new();
  for &Package {
    ref name,
    ref version,
    ..
  } in all_packages
  {
    known_versions_per_crate
      .entry(name.clone())
      .or_insert_with(HashSet::new)
      .insert(version.clone());
  }

  // 1st check names
  let pkg_names = all_packages
    .iter()
    .map(|pkg| &pkg.name)
    .collect::<HashSet<_>>();
  let setting_names: HashSet<_> = all_crate_settings.keys().collect();
  for missing in setting_names.difference(&pkg_names) {
    eprintln!("Found unused raze crate settings for `{}`", missing);
  }

  // Then check versions
  all_crate_settings
    .iter()
    .flat_map(|(name, settings)| settings.iter().map(move |x| (x.0, name)))
    .filter(|(ver_req, _)| !all_packages.iter().any(|pkg| ver_req.matches(&pkg.version)))
    .for_each(|(ver_req, name)| {
      eprintln!(
        "Found unused raze settings for version `{}` against crate `{}`",
        ver_req, name
      );
    });
}

#[cfg(test)]
mod tests {
  use super::*;
  use crate::{
    metadata::tests::dummy_raze_metadata,
    settings::tests::dummy_raze_settings,
    testing::{template_metadata, templates},
  };

  #[test]
  fn test_check_resolve_matches_packages_fails_correctly() {
    let mut metadata = dummy_raze_metadata().metadata.clone();

    // Invalidate the metadata, expect an error.
    metadata.packages = Vec::new();
    assert!(check_resolve_matches_packages(&metadata).is_err());
  }

  #[test]
  fn test_check_resolve_matches_packages_works_correctly() {
    let metadata = dummy_raze_metadata().metadata.clone();

    // Should not panic with valid metadata.
    check_resolve_matches_packages(&metadata).unwrap();
  }

  #[test]
  fn test_check_all_vendored_verifies_vendored_state() {
    let mut settings = dummy_raze_settings();
    settings.genmode = GenMode::Vendored;

    let result = check_all_vendored(
      &template_metadata(templates::DUMMY_MODIFIED_METADATA),
      &settings,
      &PathBuf::from("/tmp/some/path"),
    );

    // Vendored crates will not have been rendered at that path
    assert!(result.is_err());
  }

  #[test]
  fn test_missing_checksums() {
    let metadata = template_metadata(templates::DUMMY_WORKSPACE_MEMBERS_METADATA);
    let checksums: HashMap<String, String> = HashMap::new();

    let result = check_lockfile_for_missing_checksums(&metadata, &checksums);
    assert!(result.is_err());
  }

  #[test]
  fn test_valid_checksums() {
    let metadata = template_metadata(templates::DUMMY_WORKSPACE_MEMBERS_METADATA);
    let mut checksums: HashMap<String, String> = HashMap::new();

    // Add checksums
    checksums.insert("unicode-xid-0.1.0".to_owned(), "some-checksum".to_owned());
    checksums.insert("unicode-xid-0.2.1".to_owned(), "some-checksum".to_owned());

    // Ensure we have a complete match
    check_lockfile_for_missing_checksums(&metadata, &checksums).unwrap();
  }

  #[test]
  fn test_no_deps_and_no_checksums() {
    let raze_metadata = dummy_raze_metadata();
    let checksums: HashMap<String, String> = HashMap::new();

    // Ensure all packages are workspace members for this test
    for package in raze_metadata.metadata.packages.iter() {
      assert!(raze_metadata
        .metadata
        .workspace_members
        .contains(&package.id))
    }

    // Ensure no checks fail
    check_lockfile_for_missing_checksums(&raze_metadata.metadata, &checksums).unwrap();
  }
}
