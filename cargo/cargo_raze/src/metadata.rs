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
  collections::HashMap,
  fs,
  path::{Path, PathBuf},
  string::String,
};

use anyhow::{anyhow, Context, Result};
use cargo_lock::Lockfile;
use cargo_metadata::{Metadata, MetadataCommand};
use glob::glob;
use pathdiff::diff_paths;
use regex::Regex;
use rustc_serialize::hex::ToHex;
use tempfile::TempDir;
use url::Url;

use crate::util::{cargo_bin_path, package_ident};

pub(crate) const DEFAULT_CRATE_REGISTRY_URL: &str = "https://crates.io";
pub(crate) const DEFAULT_CRATE_INDEX_URL: &str = "https://github.com/rust-lang/crates.io-index";

/// An entity that can generate Cargo metadata within a Cargo workspace
pub trait MetadataFetcher {
  fn fetch_metadata(&self, working_dir: &Path, include_deps: bool) -> Result<Metadata>;
}

/// A lockfile generator which simply wraps the `cargo_metadata::MetadataCommand` command
struct CargoMetadataFetcher {
  pub cargo_bin_path: PathBuf,
}

impl Default for CargoMetadataFetcher {
  fn default() -> CargoMetadataFetcher {
    CargoMetadataFetcher {
      cargo_bin_path: cargo_bin_path(),
    }
  }
}

impl MetadataFetcher for CargoMetadataFetcher {
  fn fetch_metadata(&self, working_dir: &Path, include_deps: bool) -> Result<Metadata> {
    let mut command = MetadataCommand::new();

    if !include_deps {
      command.no_deps();
    }

    command
      .cargo_path(&self.cargo_bin_path)
      .current_dir(working_dir)
      .exec()
      .with_context(|| {
        format!(
          "Failed to fetch Metadata with `{}` from `{}`",
          &self.cargo_bin_path.display(),
          working_dir.display()
        )
      })
  }
}

/// An entity that can generate a lockfile data within a Cargo workspace
pub trait LockfileGenerator {
  fn generate_lockfile(&self, crate_root_dir: &Path) -> Result<Lockfile>;
}

/// A lockfile generator which simply wraps the `cargo generate-lockfile` command
struct CargoLockfileGenerator {
  cargo_bin_path: PathBuf,
}

impl LockfileGenerator for CargoLockfileGenerator {
  /// Generate lockfile information from a cargo workspace root
  fn generate_lockfile(&self, crate_root_dir: &Path) -> Result<Lockfile> {
    let lockfile_path = crate_root_dir.join("Cargo.lock");

    // Generate lockfile
    std::process::Command::new(&self.cargo_bin_path)
      .arg("generate-lockfile")
      .current_dir(&crate_root_dir)
      .output()?;

    // Load lockfile contents
    Lockfile::load(&lockfile_path)
      .with_context(|| format!("Failed to load lockfile: {}", lockfile_path.display()))
  }
}

/// A struct containing all metadata about a project with which to plan generated output files for
#[derive(Debug, Clone)]
pub struct RazeMetadata {
  // `cargo metadata` output of the current project
  pub metadata: Metadata,

  // The absolute path to the current project's cargo workspace root. Note that the workspace
  // root in `metadata` will be inside of a temporary directory. For details see:
  // https://doc.rust-lang.org/cargo/reference/workspaces.html#root-package
  pub cargo_workspace_root: PathBuf,

  // The metadata of a lockfile that was generated as a result of fetching metadata
  pub lockfile: Option<Lockfile>,

  // A map of all known crates with checksums. Use `checksums_for` to access data from this map.
  pub checksums: HashMap<String, String>,
}

impl RazeMetadata {
  /// Get the checksum of a crate using a unique formatter.
  pub fn checksum_for(&self, name: &str, version: &str) -> Option<&String> {
    self.checksums.get(&package_ident(name, version))
  }
}

/// Create a symlink file on unix systems
#[cfg(target_family = "unix")]
fn make_symlink(src: &Path, dest: &Path) -> Result<()> {
  std::os::unix::fs::symlink(src, dest)
    .with_context(|| "Failed to create symlink for generating metadata")
}

/// Create a symlink file on windows systems
#[cfg(target_family = "windows")]
fn make_symlink(src: &Path, dest: &Path) -> Result<()> {
  std::os::windows::fs::symlink_file(dest, src)
    .with_context(|| "Failed to create symlink for generating metadata")
}

/// A workspace metadata fetcher that uses the Cargo commands to gather information about a Cargo
/// project and it's transitive dependencies for planning and rendering of Bazel BUILD files.
pub struct RazeMetadataFetcher {
  registry_url: Url,
  index_url: Url,
  metadata_fetcher: Box<dyn MetadataFetcher>,
  lockfile_generator: Box<dyn LockfileGenerator>,
}

impl RazeMetadataFetcher {
  pub fn new<P: Into<PathBuf>>(
    cargo_bin_path: P,
    registry_url: Url,
    index_url: Url,
  ) -> RazeMetadataFetcher {
    let cargo_bin_pathbuf: PathBuf = cargo_bin_path.into();
    RazeMetadataFetcher {
      registry_url,
      index_url,
      metadata_fetcher: Box::new(CargoMetadataFetcher {
        cargo_bin_path: cargo_bin_pathbuf.clone(),
      }),
      lockfile_generator: Box::new(CargoLockfileGenerator {
        cargo_bin_path: cargo_bin_pathbuf,
      }),
    }
  }

  /// Reassign the [`crate::metadata::MetadataFetcher`] associated with the Raze Metadata Fetcher
  pub fn set_metadata_fetcher(&mut self, fetcher: Box<dyn MetadataFetcher>) {
    self.metadata_fetcher = fetcher;
  }

  /// Reassign the [`crate::metadata::LockfileGenerator`] associated with the current Fetcher
  pub fn set_lockfile_generator(&mut self, generator: Box<dyn LockfileGenerator>) {
    self.lockfile_generator = generator;
  }

  /// Symlinks the source code of all workspace members into the temp workspace
  fn link_src_to_workspace(&self, no_deps_metadata: &Metadata, temp_dir: &Path) -> Result<()> {
    let crate_member_id_re = Regex::new(r".+\(path\+file://(.+)\)")?;
    for member in no_deps_metadata.workspace_members.iter() {
      // Get a path to the workspace member directory
      let workspace_member_directory = {
        let crate_member_id_match = crate_member_id_re
          .captures(&member.repr)
          .and_then(|cap| cap.get(1));

        if crate_member_id_match.is_none() {
          continue;
        }

        // UNWRAP: guarded above
        PathBuf::from(crate_member_id_match.unwrap().as_str())
      };

      // Sanity check: The assumption is that any crate with an `id` that matches
      // the regex pattern above should contain a Cargo.toml file with which we
      // can use to infer the existence of libraries from relative paths such as
      // `src/lib.rs` and `src/main.rs`.
      let toml_path = workspace_member_directory.join("Cargo.toml");
      if !toml_path.exists() {
        return Err(anyhow!(format!(
          "The regex pattern `{}` found a path that did not contain a Cargo.toml file: `{}`",
          crate_member_id_re.as_str(),
          workspace_member_directory.display()
        )));
      }

      // Copy the Cargo.toml files into the temp directory to match the directory structure on disk
      let diff = diff_paths(
        &workspace_member_directory,
        &no_deps_metadata.workspace_root,
      )
      .ok_or_else(|| {
        anyhow!("All workspace memebers are expected to be under the workspace root")
      })?;
      let new_path = temp_dir.join(diff);
      fs::create_dir_all(&new_path)?;
      fs::copy(
        workspace_member_directory.join("Cargo.toml"),
        new_path.join("Cargo.toml"),
      )?;

      // Additionally, symlink everything in some common source directories to ensure specified
      // library targets can be relied on and won't prevent fetching metadata
      for dir in vec!["bin", "src"].iter() {
        let glob_pattern = format!("{}/**/*.rs", workspace_member_directory.join(dir).display());
        for entry in glob(glob_pattern.as_str()).expect("Failed to read glob pattern") {
          let path = entry?;

          // Determine the difference between the workspace root and the current file
          let diff = diff_paths(&path, &no_deps_metadata.workspace_root).ok_or_else(|| {
            anyhow!("All workspace memebers are expected to be under the workspace root")
          })?;

          // Create a matching directory tree for the current file within the temp workspace
          let new_path = temp_dir.join(diff);
          if let Some(parent) = new_path.parent() {
            fs::create_dir_all(parent)?;
          }

          make_symlink(&path, &new_path)?;
        }
      }
    }

    Ok(())
  }

  /// Creates a copy workspace in a temporary directory for fetching the metadata of the current workspace
  fn make_temp_workspace(&self, cargo_workspace_root: &Path) -> Result<(TempDir, PathBuf)> {
    let temp_dir = TempDir::new()?;

    // First gather metadata without downloading any dependencies so we can identify any path dependencies.
    let no_deps_metadata = self
      .metadata_fetcher
      .fetch_metadata(cargo_workspace_root, /*include_deps=*/ false)?;

    // There should be a `Cargo.toml` file in the workspace root
    fs::copy(
      no_deps_metadata.workspace_root.join("Cargo.toml"),
      temp_dir.as_ref().join("Cargo.toml"),
    )?;

    // Optionally copy over the lock file
    if no_deps_metadata.workspace_root.join("Cargo.lock").exists() {
      fs::copy(
        no_deps_metadata.workspace_root.join("Cargo.lock"),
        temp_dir.as_ref().join("Cargo.lock"),
      )?;
    }

    // Copy over the Cargo.toml files of each workspace member
    self.link_src_to_workspace(&no_deps_metadata, temp_dir.as_ref())?;

    Ok((temp_dir, no_deps_metadata.workspace_root))
  }

  /// Download a crate's source code from the current registry url
  fn fetch_crate_src(&self, dir: &Path, name: &str, version: &str) -> Result<PathBuf> {
    // The registry url should only be the host URL with ports. No path
    let registry_url = {
      let mut r_url = self.registry_url.clone();
      r_url.set_path("");
      r_url.to_string()
    };

    // Generate a URL with no path. This allows the path to keep any port information
    // associated with it.
    let mut url = url::Url::parse(&registry_url)?;
    url.set_path("");

    log::debug!("Cloning binary dependency: {}", &name);
    let mut cloner = cargo_clone::Cloner::new();
    cloner
      .set_registry_url(url.to_string().trim_end_matches('/'))
      .set_out_dir(dir);

    cloner.clone(
      cargo_clone::CloneMethodKind::Crate,
      name,
      Some(version),
      &Vec::new(),
    )?;

    let crate_dir = dir.join(package_ident(name, version));
    if !crate_dir.exists() {
      return Err(anyhow!("Directory does not exist"));
    }

    Ok(crate_dir)
  }

  /// Add binary dependencies as workspace members to the given workspace root Cargo.toml file
  fn inject_binaries_into_workspace(
    &self,
    binary_deps: Vec<String>,
    root_toml: &Path,
  ) -> Result<()> {
    // Read the current manifest
    let mut manifest = {
      let content = fs::read_to_string(root_toml)?;
      cargo_toml::Manifest::from_str(content.as_str())?
    };

    // Parse the current `workspace` section of the manifest if one exists
    let mut workspace = match manifest.workspace {
      Some(workspace) => workspace,
      None => cargo_toml::Workspace::default(),
    };

    // Add the binary dependencies as workspace members to the `workspace` metadata
    for dep in binary_deps.iter() {
      workspace.members.push(dep.to_string());
    }

    // Replace the workspace metadata with the modified metadata
    manifest.workspace = Some(workspace);

    // Write the metadata back to disk.
    // cargo_toml::Manifest cannot be serialized direcly.
    // see: https://gitlab.com/crates.rs/cargo_toml/-/issues/3
    let value = toml::Value::try_from(&manifest)?;
    std::fs::write(root_toml, toml::to_string(&value)?).with_context(|| {
      format!(
        "Failed to inject workspace metadata to {}",
        root_toml.display()
      )
    })
  }

  /// Look up a crate in a specified crate index to determine it's checksum
  fn fetch_crate_checksum(&self, name: &str, version: &str) -> Result<String> {
    let index_url_is_file = self.index_url.scheme().to_lowercase() == "file";
    let crate_index_path = if !index_url_is_file {
      crates_index::BareIndex::from_url(&self.index_url.to_string())?
        .open_or_clone()?
        .crate_(name)
        .ok_or_else(|| anyhow!("Failed to find crate '{}' in index", name))?
    } else {
      crates_index::Index::new(&self.index_url.path())
        .crate_(name)
        .ok_or_else(|| anyhow!("Failed to find crate '{}' in index", name))?
    };

    let (_index, crate_version) = crate_index_path
      .versions()
      .iter()
      .enumerate()
      .find(|(_, ver)| ver.version() == version)
      .ok_or_else(|| anyhow!("Failed to find version {} for crate {}", version, name))?;

    Ok(crate_version.checksum()[..].to_hex())
  }

  /// Ensures a lockfile is generated for a crate on disk
  ///
  /// Args:
  ///   - reused_lockfile: An optional lockfile to use for fetching metadata to
  ///       ensure subsequent metadata fetches return consistent results.
  ///   - cargo_dir: The directory of the cargo workspace to gather metadata for.
  /// Returns:
  ///   If a new lockfile was generated via the `lockfile_generator`, that
  ///   Lockfile object is returned. New lockfiles are generated when
  ///   `reused_lockfile` is not provided.
  fn cargo_generate_lockfile(
    &self,
    reused_lockfile: &Option<PathBuf>,
    cargo_dir: &Path,
  ) -> Result<Option<Lockfile>> {
    let lockfile_path = cargo_dir.join("Cargo.lock");

    // Use the reusable lockfile if one is provided
    if let Some(reused_lockfile) = reused_lockfile {
      fs::copy(&reused_lockfile, &lockfile_path)?;
      return Ok(None);
    }

    let lockfile = self.lockfile_generator.generate_lockfile(&cargo_dir)?;

    // Returning the lockfile here signifies that a new lockfile has been created.
    Ok(Some(lockfile))
  }

  /// Gather all information about a Cargo project to use for planning and rendering steps
  pub fn fetch_metadata(
    &self,
    cargo_workspace_root: &Path,
    binary_dep_info: Option<&HashMap<String, cargo_toml::Dependency>>,
    reused_lockfile: Option<PathBuf>,
  ) -> Result<RazeMetadata> {
    let (cargo_dir, cargo_workspace_root) = self.make_temp_workspace(cargo_workspace_root)?;
    let cargo_root_toml = cargo_dir.as_ref().join("Cargo.toml");

    // Gather new lockfile data if any binary dependencies were provided
    let mut checksums: HashMap<String, String> = HashMap::new();
    if let Some(binary_dep_info) = binary_dep_info {
      if !binary_dep_info.is_empty() {
        let mut src_dirnames: Vec<String> = Vec::new();

        for (name, info) in binary_dep_info.iter() {
          let version = info.req();
          let src_dir = self.fetch_crate_src(cargo_dir.as_ref(), &name, version)?;
          checksums.insert(
            package_ident(name, version),
            self.fetch_crate_checksum(name, version)?,
          );
          if let Some(dirname) = src_dir.file_name() {
            if let Some(dirname_str) = dirname.to_str() {
              src_dirnames.push(dirname_str.to_string());
            }
          }
        }

        self.inject_binaries_into_workspace(src_dirnames, &cargo_root_toml)?;
      }
    }

    let output_lockfile = self.cargo_generate_lockfile(&reused_lockfile, cargo_dir.as_ref())?;

    // Load checksums from the lockfile
    let workspace_toml_lock = cargo_dir.as_ref().join("Cargo.lock");
    if workspace_toml_lock.exists() {
      let lockfile = Lockfile::load(workspace_toml_lock)?;
      for package in &lockfile.packages {
        if let Some(checksum) = &package.checksum {
          checksums.insert(
            package_ident(&package.name.to_string(), &package.version.to_string()),
            checksum.to_string(),
          );
        }
      }
    }

    let metadata = self
      .metadata_fetcher
      .fetch_metadata(cargo_dir.as_ref(), /*include_deps=*/ true)?;

    Ok(RazeMetadata {
      metadata,
      checksums,
      cargo_workspace_root,
      lockfile: output_lockfile,
    })
  }
}

impl Default for RazeMetadataFetcher {
  fn default() -> RazeMetadataFetcher {
    RazeMetadataFetcher::new(
      cargo_bin_path(),
      // UNWRAP: The default is covered by testing and should never return err
      Url::parse(DEFAULT_CRATE_REGISTRY_URL).unwrap(),
      Url::parse(DEFAULT_CRATE_INDEX_URL).unwrap(),
    )
  }
}

/// A struct containing information about a binary dependency
pub struct BinaryDependencyInfo {
  pub name: String,
  pub info: cargo_toml::Dependency,
  pub lockfile: Option<PathBuf>,
}

#[cfg(test)]
pub mod tests {
  use anyhow::Context;
  use httpmock::MockServer;
  use tera::Tera;

  use super::*;
  use crate::testing::*;

  use std::{fs::File, io::Write, str::FromStr};

  pub struct DummyCargoMetadataFetcher {
    pub metadata_template: Option<String>,
  }

  impl DummyCargoMetadataFetcher {
    fn render_metadata(&self, mock_workspace_path: &Path) -> Option<Metadata> {
      if self.metadata_template.is_none() {
        return None;
      }

      let dir = TempDir::new().unwrap();
      let mut renderer = Tera::new(&format!("{}/*", dir.as_ref().display())).unwrap();

      let templates_dir = PathBuf::from(std::file!())
        .parent()
        .unwrap()
        .join("testing/metadata_templates")
        .canonicalize()
        .unwrap();

      renderer
        .add_raw_templates(vec![(
          self.metadata_template.as_ref().unwrap(),
          fs::read_to_string(templates_dir.join(self.metadata_template.as_ref().unwrap())).unwrap(),
        )])
        .unwrap();

      let mut context = tera::Context::new();
      context.insert("mock_workspace", &mock_workspace_path);
      context.insert("crate_index_root", "/some/fake/home/path/.cargo");
      let content = renderer
        .render(self.metadata_template.as_ref().unwrap(), &context)
        .unwrap();

      Some(serde_json::from_str::<Metadata>(&content).unwrap())
    }
  }

  impl MetadataFetcher for DummyCargoMetadataFetcher {
    fn fetch_metadata(&self, working_dir: &Path, include_deps: bool) -> Result<Metadata> {
      // Only use the template if the command is looking to reach out to the internet.
      if include_deps {
        if let Some(metadata) = self.render_metadata(working_dir) {
          return Ok(metadata);
        }
      }

      // Ensure no the command is ran in `offline` mode and no dependencies are checked.
      MetadataCommand::new()
        .cargo_path(cargo_bin_path())
        .no_deps()
        .current_dir(working_dir)
        .other_options(vec!["--offline".to_string()])
        .exec()
        .with_context(|| {
          format!(
            "Failed to run `{} metadata` with contents:\n{}",
            cargo_bin_path().display(),
            fs::read_to_string(working_dir.join("Cargo.toml")).unwrap()
          )
        })
    }
  }

  pub struct DummyLockfileGenerator {
    // Optional lockfile to use for generation
    pub lockfile_contents: Option<String>,
  }

  impl LockfileGenerator for DummyLockfileGenerator {
    fn generate_lockfile(&self, _crate_root_dir: &Path) -> Result<Lockfile> {
      match &self.lockfile_contents {
        Some(contents) => Lockfile::from_str(contents)
          .with_context(|| format!("Failed to load provided lockfile:\n{}", contents)),
        None => Lockfile::from_str(basic_lock_contents())
          .with_context(|| format!("Failed to load dummy lockfile:\n{}", basic_lock_contents())),
      }
    }
  }

  pub fn dummy_raze_metadata_fetcher() -> (RazeMetadataFetcher, MockServer, TempDir) {
    let tempdir = TempDir::new().unwrap();
    let mock_server = MockServer::start();
    let mut fetcher = RazeMetadataFetcher::new(
      cargo_bin_path(),
      Url::parse(&mock_server.base_url()).unwrap(),
      Url::parse(&format!("file://{}", tempdir.as_ref().display())).unwrap(),
    );
    fetcher.set_metadata_fetcher(Box::new(DummyCargoMetadataFetcher {
      metadata_template: None,
    }));
    fetcher.set_lockfile_generator(Box::new(DummyLockfileGenerator {
      lockfile_contents: None,
    }));

    (fetcher, mock_server, tempdir)
  }

  pub fn dummy_raze_metadata() -> RazeMetadata {
    let dir = make_basic_workspace();
    let (mut fetcher, _server, _index_dir) = dummy_raze_metadata_fetcher();

    // Always render basic metadata
    fetcher.set_metadata_fetcher(Box::new(DummyCargoMetadataFetcher {
      metadata_template: Some(templates::BASIC_METADATA.to_string()),
    }));

    fetcher.fetch_metadata(dir.as_ref(), None, None).unwrap()
  }

  #[test]
  fn test_cargo_subcommand_metadata_fetcher_works_without_lock() {
    let dir = TempDir::new().unwrap();
    let toml_path = dir.path().join("Cargo.toml");
    let mut toml = File::create(&toml_path).unwrap();
    toml.write_all(basic_toml_contents().as_bytes()).unwrap();

    let mut fetcher = RazeMetadataFetcher::default();
    fetcher.set_lockfile_generator(Box::new(DummyLockfileGenerator {
      lockfile_contents: None,
    }));
    fetcher.fetch_metadata(dir.as_ref(), None, None).unwrap();
  }

  #[test]
  fn test_cargo_subcommand_metadata_fetcher_works_with_lock() {
    let dir = TempDir::new().unwrap();
    // Create Cargo.toml
    {
      let path = dir.path().join("Cargo.toml");
      let mut toml = File::create(&path).unwrap();
      toml.write_all(basic_toml_contents().as_bytes()).unwrap();
    }

    // Create Cargo.lock
    {
      let path = dir.path().join("Cargo.lock");
      let mut lock = File::create(&path).unwrap();
      lock.write_all(basic_lock_contents().as_bytes()).unwrap();
    }

    let mut fetcher = RazeMetadataFetcher::default();
    fetcher.set_lockfile_generator(Box::new(DummyLockfileGenerator {
      lockfile_contents: None,
    }));
    fetcher.fetch_metadata(dir.as_ref(), None, None).unwrap();
  }

  #[test]
  fn test_cargo_subcommand_metadata_fetcher_handles_bad_files() {
    let dir = TempDir::new().unwrap();
    // Create Cargo.toml
    {
      let path = dir.path().join("Cargo.toml");
      let mut toml = File::create(&path).unwrap();
      toml.write_all(b"hello").unwrap();
    }

    let fetcher = RazeMetadataFetcher::default();
    assert!(fetcher.fetch_metadata(dir.as_ref(), None, None).is_err());
  }

  #[test]
  fn test_fetching_src() {
    let (fetcher, mock_server, _index_url) = dummy_raze_metadata_fetcher();
    let mock = mock_remote_crate("fake-crate", "3.3.3", &mock_server);

    let path = fetcher
      .fetch_crate_src(mock.data_dir.as_ref(), "fake-crate", "3.3.3")
      .unwrap();

    for mock in mock.endpoints.iter() {
      mock.assert();
    }

    assert!(path.exists());

    // Ensure the name follows a consistent pattern: `{name}-{version}`
    assert_eq!(
      mock.data_dir.into_path().join("fake-crate-3.3.3").as_path(),
      path.as_path()
    );
    assert!(path.join("Cargo.toml").exists());
    assert!(path.join("Cargo.lock").exists());
    assert!(path.join("test").exists());
  }

  #[test]
  fn test_inject_dependency_to_workspace() {
    let (fetcher, _mock_server, _index_url) = dummy_raze_metadata_fetcher();

    let crate_dir = make_workspace_with_dependency();
    let cargo_toml_path = crate_dir.as_ref().join("Cargo.toml");
    let mut manifest =
      cargo_toml::Manifest::from_str(fs::read_to_string(&cargo_toml_path).unwrap().as_str())
        .unwrap();

    let basic_dep_toml = crate_dir.as_ref().join("basic_dep/Cargo.toml");
    fs::create_dir_all(basic_dep_toml.parent().unwrap()).unwrap();
    fs::write(&basic_dep_toml, named_toml_contents("basic_dep", "0.0.1")).unwrap();
    assert!(basic_dep_toml.exists());

    manifest.workspace = Some({
      let mut workspace = cargo_toml::Workspace::default();
      workspace.members.push("test".to_string());
      workspace
    });

    // Ensure the manifest only includes the new workspace member after the injection
    assert_ne!(
      cargo_toml::Manifest::from_str(fs::read_to_string(&cargo_toml_path).unwrap().as_str())
        .unwrap(),
      manifest
    );

    // Fetch metadata
    fetcher
      .inject_binaries_into_workspace(vec!["test".to_string()], &cargo_toml_path)
      .unwrap();

    // Ensure workspace now has the new member
    assert_eq!(
      cargo_toml::Manifest::from_str(fs::read_to_string(&cargo_toml_path).unwrap().as_str())
        .unwrap(),
      manifest
    );
  }

  #[test]
  fn test_generate_lockfile_use_previously_generated() {
    let (fetcher, _mock_server, _index_url) = dummy_raze_metadata_fetcher();

    let crate_dir = make_workspace_with_dependency();
    let reused_lockfile = crate_dir.as_ref().join("locks_test/Cargo.raze.lock");

    fs::create_dir_all(reused_lockfile.parent().unwrap()).unwrap();
    fs::write(&reused_lockfile, "# test_generate_lockfile").unwrap();

    // A reuse lockfile was provided so no new lockfile should be returned
    assert!(fetcher
      .cargo_generate_lockfile(&Some(reused_lockfile.clone()), crate_dir.as_ref())
      .unwrap()
      .is_none());

    // Returns the built in lockfile
    assert_eq!(
      cargo_lock::Lockfile::load(crate_dir.as_ref().join("Cargo.lock")).unwrap(),
      cargo_lock::Lockfile::load(&reused_lockfile).unwrap(),
    );
  }

  #[test]
  fn test_cargo_generate_lockfile_new_file() {
    let (mut fetcher, _mock_server, _index_url) = dummy_raze_metadata_fetcher();
    fetcher.set_lockfile_generator(Box::new(DummyLockfileGenerator {
      lockfile_contents: Some(advanced_lock_contents().to_string()),
    }));

    let crate_dir = make_workspace(advanced_toml_contents(), None);

    // A new lockfile should have been created and it should match the expected contents for the advanced_toml workspace
    assert_eq!(
      fetcher
        .cargo_generate_lockfile(&None, crate_dir.as_ref())
        .unwrap()
        .unwrap(),
      Lockfile::from_str(advanced_lock_contents()).unwrap()
    );
  }

  #[test]
  fn test_cargo_generate_lockfile_no_file() {
    let (mut fetcher, _mock_server, _index_url) = dummy_raze_metadata_fetcher();
    fetcher.set_lockfile_generator(Box::new(DummyLockfileGenerator {
      lockfile_contents: Some(advanced_lock_contents().to_string()),
    }));

    let crate_dir = make_workspace(advanced_toml_contents(), None);
    let expected_lockfile = crate_dir.as_ref().join("expected/Cargo.expected.lock");

    fs::create_dir_all(expected_lockfile.parent().unwrap()).unwrap();
    fs::write(&expected_lockfile, advanced_lock_contents()).unwrap();

    assert!(fetcher
      .cargo_generate_lockfile(&Some(expected_lockfile.clone()), crate_dir.as_ref())
      .unwrap()
      .is_none());

    // Ensure a Cargo.lock file was generated and matches the expected file
    assert_eq!(
      Lockfile::from_str(&fs::read_to_string(expected_lockfile).unwrap()).unwrap(),
      Lockfile::from_str(&fs::read_to_string(crate_dir.as_ref().join("Cargo.lock")).unwrap())
        .unwrap()
    );
  }
}
