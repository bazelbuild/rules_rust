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
    path::{Path, PathBuf},
    string::String,
};

use anyhow::{Context, Result};
use cargo_lock::Lockfile;
use cargo_metadata::{Metadata, MetadataCommand};

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
        let output = std::process::Command::new(&self.cargo_bin_path)
            .arg("generate-lockfile")
            .current_dir(&crate_root_dir)
            .output()
            .with_context(|| format!("Generating lockfile in {}", crate_root_dir.display()))?;

        if !output.status.success() {
            anyhow::bail!(
                "Failed to generate lockfile in {}: {}",
                crate_root_dir.display(),
                String::from_utf8_lossy(&output.stderr)
            );
        }

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
    pub lockfile: Lockfile,

    // A map of all known crates with checksums. Use `checksums_for` to access data from this map.
    pub checksums: HashMap<String, String>,
}

impl RazeMetadata {
    /// Get the checksum of a crate using a unique formatter.
    pub fn checksum_for(&self, name: &str, version: &str) -> Option<&String> {
        self.checksums.get(&package_ident(name, version))
    }
}

/// A workspace metadata fetcher that uses the Cargo commands to gather information about a Cargo
/// project and it's transitive dependencies for planning and rendering of Bazel BUILD files.
pub struct RazeMetadataFetcher {
    metadata_fetcher: Box<dyn MetadataFetcher>,
    lockfile_generator: Box<dyn LockfileGenerator>,
}

impl RazeMetadataFetcher {
    pub fn new<P: Into<PathBuf>>(cargo_bin_path: P) -> RazeMetadataFetcher {
        let cargo_bin_pathbuf: PathBuf = cargo_bin_path.into();
        RazeMetadataFetcher {
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

    /// Ensures a lockfile is generated for a crate on disk
    ///
    /// Args:
    ///   - reused_lockfile: An optional lockfile to use for fetching metadata to
    ///       ensure subsequent metadata fetches return consistent results.
    ///   - cargo_dir: The directory of the cargo workspace to gather metadata for.
    /// Returns:
    ///   Either the contents of the reusable lockfile or a newly generated one
    fn cargo_generate_lockfile(
        &self,
        reused_lockfile: &Option<PathBuf>,
        cargo_dir: &Path,
    ) -> Result<Lockfile> {
        // Use the reusable lockfile if one is provided
        if let Some(reused_lockfile) = reused_lockfile {
            if reused_lockfile.exists() {
                return Ok(Lockfile::load(reused_lockfile)?);
            }
        }

        // Generate a new if a reusable file was not provided
        self.lockfile_generator
            .generate_lockfile(&cargo_dir)
            .with_context(|| "Failed to generate lockfile")
    }

    /// Gather all information about a Cargo project to use for planning and rendering steps
    pub fn fetch_metadata(
        &self,
        cargo_workspace_root: &Path,
        reused_lockfile: Option<PathBuf>,
    ) -> Result<RazeMetadata> {
        let output_lockfile =
            self.cargo_generate_lockfile(&reused_lockfile, cargo_workspace_root)?;

        // Load checksums from the lockfile
        let mut checksums: HashMap<String, String> = HashMap::new();
        for package in &output_lockfile.packages {
            if let Some(checksum) = &package.checksum {
                checksums.insert(
                    package_ident(&package.name.to_string(), &package.version.to_string()),
                    checksum.to_string(),
                );
            }
        }

        let metadata = self
            .metadata_fetcher
            .fetch_metadata(cargo_workspace_root, /*include_deps=*/ true)?;

        Ok(RazeMetadata {
            metadata,
            checksums,
            cargo_workspace_root: cargo_workspace_root.to_path_buf(),
            lockfile: output_lockfile,
        })
    }
}

impl Default for RazeMetadataFetcher {
    fn default() -> RazeMetadataFetcher {
        RazeMetadataFetcher::new(cargo_bin_path())
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
    use std::{
        fs::{self, File},
        io::Write,
        str::FromStr,
    };

    use anyhow::Context;
    use tempfile::TempDir;
    use tera::Tera;

    use super::*;
    use crate::testing::*;

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
                    fs::read_to_string(
                        templates_dir.join(self.metadata_template.as_ref().unwrap()),
                    )
                    .unwrap(),
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
                None => Lockfile::from_str(basic_lock_contents()).with_context(|| {
                    format!("Failed to load dummy lockfile:\n{}", basic_lock_contents())
                }),
            }
        }
    }

    pub fn dummy_raze_metadata_fetcher() -> RazeMetadataFetcher {
        let mut fetcher = RazeMetadataFetcher::new(cargo_bin_path());
        fetcher.set_metadata_fetcher(Box::new(DummyCargoMetadataFetcher {
            metadata_template: None,
        }));
        fetcher.set_lockfile_generator(Box::new(DummyLockfileGenerator {
            lockfile_contents: None,
        }));

        fetcher
    }

    pub fn dummy_raze_metadata() -> RazeMetadata {
        let dir = make_basic_workspace();
        let mut fetcher = dummy_raze_metadata_fetcher();

        // Always render basic metadata
        fetcher.set_metadata_fetcher(Box::new(DummyCargoMetadataFetcher {
            metadata_template: Some(templates::BASIC_METADATA.to_string()),
        }));

        fetcher.fetch_metadata(dir.as_ref(), None).unwrap()
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
        fetcher.fetch_metadata(dir.as_ref(), None).unwrap();
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
        fetcher.fetch_metadata(dir.as_ref(), None).unwrap();
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
        assert!(fetcher.fetch_metadata(dir.as_ref(), None).is_err());
    }

    #[test]
    fn test_generate_lockfile_use_previously_generated() {
        let fetcher = dummy_raze_metadata_fetcher();

        let crate_dir = make_workspace_with_dependency();
        let reused_lockfile = crate_dir.as_ref().join("locks_test/Cargo.raze.lock");

        fs::create_dir_all(reused_lockfile.parent().unwrap()).unwrap();
        fs::write(&reused_lockfile, "# test_generate_lockfile").unwrap();

        // Returns the built in lockfile
        assert_eq!(
            cargo_lock::Lockfile::load(&reused_lockfile).unwrap(),
            fetcher
                .cargo_generate_lockfile(&Some(reused_lockfile.clone()), crate_dir.as_ref())
                .unwrap(),
        );
    }

    #[test]
    fn test_cargo_generate_lockfile_new_file() {
        let mut fetcher = dummy_raze_metadata_fetcher();
        fetcher.set_lockfile_generator(Box::new(DummyLockfileGenerator {
            lockfile_contents: Some(advanced_lock_contents().to_string()),
        }));

        let crate_dir = make_workspace(advanced_toml_contents(), None);

        // A new lockfile should have been created and it should match the expected contents for the advanced_toml workspace
        assert_eq!(
            fetcher
                .cargo_generate_lockfile(&None, crate_dir.as_ref())
                .unwrap(),
            Lockfile::from_str(advanced_lock_contents()).unwrap()
        );
    }

    #[test]
    fn test_cargo_generate_lockfile_no_file() {
        let mut fetcher = dummy_raze_metadata_fetcher();
        fetcher.set_lockfile_generator(Box::new(DummyLockfileGenerator {
            lockfile_contents: Some(advanced_lock_contents().to_string()),
        }));

        let crate_dir = make_workspace(advanced_toml_contents(), None);
        let expected_lockfile = crate_dir.as_ref().join("expected/Cargo.expected.lock");

        fs::create_dir_all(expected_lockfile.parent().unwrap()).unwrap();
        fs::write(&expected_lockfile, advanced_lock_contents()).unwrap();

        // Ensure a Cargo.lock file was generated and matches the expected file
        assert_eq!(
            Lockfile::from_str(&fs::read_to_string(&expected_lockfile).unwrap()).unwrap(),
            fetcher
                .cargo_generate_lockfile(&Some(expected_lockfile), crate_dir.as_ref())
                .unwrap(),
        );
    }
}
