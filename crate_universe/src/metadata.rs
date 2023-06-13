//! Tools for gathering various kinds of metadata (Cargo.lock, Cargo metadata, Crate Index info).

mod dependency;
mod metadata_annotation;

use std::collections::{BTreeMap, BTreeSet};
use std::env;
use std::fs;
use std::io::BufRead;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::str::FromStr;
use std::sync::{Arc, Mutex};

use crate::lockfile::Digest;
use anyhow::{anyhow, bail, Context, Result};
use cargo_lock::Lockfile as CargoLockfile;
use cargo_metadata::{Metadata as CargoMetadata, MetadataCommand};
use semver::Version;

use crate::config::CrateId;
use crate::utils::starlark::SelectList;

pub use self::dependency::*;
pub use self::metadata_annotation::*;

// TODO: This should also return a set of [crate-index::IndexConfig]s for packages in metadata.packages
/// A Trait for generating metadata (`cargo metadata` output and a lock file) from a Cargo manifest.
pub trait MetadataGenerator {
    fn generate<T: AsRef<Path>>(&self, manifest_path: T) -> Result<(CargoMetadata, CargoLockfile)>;
}

/// Generates Cargo metadata and a lockfile from a provided manifest.
pub struct Generator {
    /// The path to a `cargo` binary
    cargo_bin: Cargo,

    /// The path to a `rustc` binary
    rustc_bin: PathBuf,
}

impl Generator {
    pub fn new() -> Self {
        Generator {
            cargo_bin: Cargo::new(PathBuf::from(
                env::var("CARGO").unwrap_or_else(|_| "cargo".to_string()),
            )),
            rustc_bin: PathBuf::from(env::var("RUSTC").unwrap_or_else(|_| "rustc".to_string())),
        }
    }

    pub fn with_cargo(mut self, cargo_bin: Cargo) -> Self {
        self.cargo_bin = cargo_bin;
        self
    }

    pub fn with_rustc(mut self, rustc_bin: PathBuf) -> Self {
        self.rustc_bin = rustc_bin;
        self
    }
}

impl MetadataGenerator for Generator {
    fn generate<T: AsRef<Path>>(&self, manifest_path: T) -> Result<(CargoMetadata, CargoLockfile)> {
        let manifest_dir = manifest_path
            .as_ref()
            .parent()
            .expect("The manifest should have a parent directory");
        let lockfile = {
            let lock_path = manifest_dir.join("Cargo.lock");
            if !lock_path.exists() {
                bail!("No `Cargo.lock` file was found with the given manifest")
            }
            cargo_lock::Lockfile::load(lock_path)?
        };

        let metadata = self
            .cargo_bin
            .metadata_command()?
            .current_dir(manifest_dir)
            .manifest_path(manifest_path.as_ref())
            .other_options(["--locked".to_owned()])
            .exec()?;

        Ok((metadata, lockfile))
    }
}

/// Cargo encapsulates a path to a `cargo` binary.
/// Any invocations of `cargo` (either as a `std::process::Command` or via `cargo_metadata`) should
/// go via this wrapper to ensure that any environment variables needed are set appropriately.
#[derive(Clone)]
pub struct Cargo {
    path: PathBuf,
    full_version: Arc<Mutex<Option<String>>>,
}

impl Cargo {
    pub fn new(path: PathBuf) -> Cargo {
        Cargo {
            path,
            full_version: Arc::new(Mutex::new(None)),
        }
    }

    /// Returns a new `Command` for running this cargo.
    pub fn command(&self) -> Result<Command> {
        let mut command = Command::new(&self.path);
        command.envs(self.env()?);
        Ok(command)
    }

    /// Returns a new `MetadataCommand` using this cargo.
    pub fn metadata_command(&self) -> Result<MetadataCommand> {
        let mut command = MetadataCommand::new();
        command.cargo_path(&self.path);
        for (k, v) in self.env()? {
            command.env(k, v);
        }
        Ok(command)
    }

    /// Returns the output of running `cargo version`, trimming any leading or trailing whitespace.
    /// This function performs normalisation to work around `<https://github.com/rust-lang/cargo/issues/10547>`
    pub fn full_version(&self) -> Result<String> {
        let mut full_version = self.full_version.lock().unwrap();
        if full_version.is_none() {
            let observed_version = Digest::bin_version(&self.path)?;
            *full_version = Some(observed_version);
        }
        Ok(full_version.clone().unwrap())
    }

    pub fn use_sparse_registries_for_crates_io(&self) -> Result<bool> {
        let full_version = self.full_version()?;
        let version_str = full_version.split(' ').nth(1);
        if let Some(version_str) = version_str {
            let version = Version::parse(version_str).context("Failed to parse cargo version")?;
            return Ok(version.major >= 1 && version.minor >= 68);
        }
        bail!("Couldn't parse cargo version");
    }

    fn env(&self) -> Result<BTreeMap<String, String>> {
        let mut map = BTreeMap::new();

        if self.use_sparse_registries_for_crates_io()? {
            map.insert(
                "CARGO_REGISTRIES_CRATES_IO_PROTOCOL".into(),
                "sparse".into(),
            );
        }
        Ok(map)
    }
}

/// A configuration desrcibing how to invoke [cargo update](https://doc.rust-lang.org/cargo/commands/cargo-update.html).
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum CargoUpdateRequest {
    /// Translates to an unrestricted `cargo update` command
    Eager,

    /// Translates to `cargo update --workspace`
    Workspace,

    /// Translates to `cargo update --package foo` with an optional `--precise` argument.
    Package {
        /// The name of the crate used with `--package`.
        name: String,

        /// If set, the `--precise` value that pairs with `--package`.
        version: Option<String>,
    },
}

impl FromStr for CargoUpdateRequest {
    type Err = anyhow::Error;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        let lower = s.to_lowercase();

        if ["eager", "full", "all"].contains(&lower.as_str()) {
            return Ok(Self::Eager);
        }

        if ["1", "yes", "true", "on", "workspace", "minimal"].contains(&lower.as_str()) {
            return Ok(Self::Workspace);
        }

        let mut split = s.splitn(2, '@');
        Ok(Self::Package {
            name: split.next().map(|s| s.to_owned()).unwrap(),
            version: split.next().map(|s| s.to_owned()),
        })
    }
}

impl CargoUpdateRequest {
    /// Determine what arguments to pass to the `cargo update` command.
    fn get_update_args(&self) -> Vec<String> {
        match self {
            CargoUpdateRequest::Eager => Vec::new(),
            CargoUpdateRequest::Workspace => vec!["--workspace".to_owned()],
            CargoUpdateRequest::Package { name, version } => {
                let mut update_args = vec!["--package".to_owned(), name.clone()];

                if let Some(version) = version {
                    update_args.push("--precise".to_owned());
                    update_args.push(version.clone());
                }

                update_args
            }
        }
    }

    /// Calls `cargo update` with arguments specific to the state of the current variant.
    pub fn update(&self, manifest: &Path, cargo_bin: &Cargo, rustc_bin: &Path) -> Result<()> {
        let manifest_dir = manifest.parent().unwrap();

        // Simply invoke `cargo update`
        let output = cargo_bin
            .command()?
            // Cargo detects config files based on `pwd` when running so
            // to ensure user provided Cargo config files are used, it's
            // critical to set the working directory to the manifest dir.
            .current_dir(manifest_dir)
            .arg("update")
            .arg("--manifest-path")
            .arg(manifest)
            .args(self.get_update_args())
            .env("RUSTC", rustc_bin)
            .output()
            .with_context(|| {
                format!(
                    "Error running cargo to update packages for manifest '{}'",
                    manifest.display()
                )
            })?;

        if !output.status.success() {
            eprintln!("{}", String::from_utf8_lossy(&output.stdout));
            eprintln!("{}", String::from_utf8_lossy(&output.stderr));
            bail!(format!("Failed to update lockfile: {}", output.status))
        }

        Ok(())
    }
}

pub struct LockGenerator {
    /// The path to a `cargo` binary
    cargo_bin: Cargo,

    /// The path to a `rustc` binary
    rustc_bin: PathBuf,
}

impl LockGenerator {
    pub fn new(cargo_bin: Cargo, rustc_bin: PathBuf) -> Self {
        Self {
            cargo_bin,
            rustc_bin,
        }
    }

    pub fn generate(
        &self,
        manifest_path: &Path,
        existing_lock: &Option<PathBuf>,
        update_request: &Option<CargoUpdateRequest>,
    ) -> Result<cargo_lock::Lockfile> {
        let manifest_dir = manifest_path.parent().unwrap();
        let generated_lockfile_path = manifest_dir.join("Cargo.lock");

        if let Some(lock) = existing_lock {
            if !lock.exists() {
                bail!(
                    "An existing lockfile path was provided but a file at '{}' does not exist",
                    lock.display()
                )
            }

            // Install the file into the target location
            if generated_lockfile_path.exists() {
                fs::remove_file(&generated_lockfile_path)?;
            }
            fs::copy(lock, &generated_lockfile_path)?;

            if let Some(request) = update_request {
                request.update(manifest_path, &self.cargo_bin, &self.rustc_bin)?;
            }

            // Ensure the Cargo cache is up to date to simulate the behavior
            // of having just generated a new one
            let output = self
                .cargo_bin
                .command()?
                // Cargo detects config files based on `pwd` when running so
                // to ensure user provided Cargo config files are used, it's
                // critical to set the working directory to the manifest dir.
                .current_dir(manifest_dir)
                .arg("fetch")
                .arg("--locked")
                .arg("--manifest-path")
                .arg(manifest_path)
                .env("RUSTC", &self.rustc_bin)
                .output()
                .context(format!(
                    "Error running cargo to fetch crates '{}'",
                    manifest_path.display()
                ))?;

            if !output.status.success() {
                eprintln!("{}", String::from_utf8_lossy(&output.stdout));
                eprintln!("{}", String::from_utf8_lossy(&output.stderr));
                bail!(format!(
                    "Failed to fetch crates for lockfile: {}",
                    output.status
                ))
            }
        } else {
            // Simply invoke `cargo generate-lockfile`
            let output = self
                .cargo_bin
                .command()?
                // Cargo detects config files based on `pwd` when running so
                // to ensure user provided Cargo config files are used, it's
                // critical to set the working directory to the manifest dir.
                .current_dir(manifest_dir)
                .arg("generate-lockfile")
                .arg("--manifest-path")
                .arg(manifest_path)
                .env("RUSTC", &self.rustc_bin)
                .output()
                .context(format!(
                    "Error running cargo to generate lockfile '{}'",
                    manifest_path.display()
                ))?;

            if !output.status.success() {
                eprintln!("{}", String::from_utf8_lossy(&output.stdout));
                eprintln!("{}", String::from_utf8_lossy(&output.stderr));
                bail!(format!("Failed to generate lockfile: {}", output.status))
            }
        }

        cargo_lock::Lockfile::load(&generated_lockfile_path).context(format!(
            "Failed to load lockfile: {}",
            generated_lockfile_path.display()
        ))
    }
}

/// A generator which runs `cargo vendor` on a given manifest
pub struct VendorGenerator {
    /// The path to a `cargo` binary
    cargo_bin: Cargo,

    /// The path to a `rustc` binary
    rustc_bin: PathBuf,
}

impl VendorGenerator {
    pub fn new(cargo_bin: Cargo, rustc_bin: PathBuf) -> Self {
        Self {
            cargo_bin,
            rustc_bin,
        }
    }

    pub fn generate(&self, manifest_path: &Path, output_dir: &Path) -> Result<()> {
        let manifest_dir = manifest_path.parent().unwrap();

        // Simply invoke `cargo generate-lockfile`
        let output = self
            .cargo_bin
            .command()?
            // Cargo detects config files based on `pwd` when running so
            // to ensure user provided Cargo config files are used, it's
            // critical to set the working directory to the manifest dir.
            .current_dir(manifest_dir)
            .arg("vendor")
            .arg("--manifest-path")
            .arg(manifest_path)
            .arg("--locked")
            .arg("--versioned-dirs")
            .arg(output_dir)
            .env("RUSTC", &self.rustc_bin)
            .output()
            .with_context(|| {
                format!(
                    "Error running cargo to vendor sources for manifest '{}'",
                    manifest_path.display()
                )
            })?;

        if !output.status.success() {
            eprintln!("{}", String::from_utf8_lossy(&output.stdout));
            eprintln!("{}", String::from_utf8_lossy(&output.stderr));
            bail!(format!("Failed to vendor sources with: {}", output.status))
        }

        Ok(())
    }
}

/// A generate which computes per-platform feature sets.
pub struct FeatureGenerator {
    /// The path to a `cargo` binary
    cargo_bin: Cargo,

    /// The path to a `rustc` binary
    rustc_bin: PathBuf,
}

impl FeatureGenerator {
    pub fn new(cargo_bin: Cargo, rustc_bin: PathBuf) -> Self {
        Self {
            cargo_bin,
            rustc_bin,
        }
    }

    /// Computes the set of enabled features for each target triplet for each crate.
    pub fn generate(
        &self,
        manifest_path: &Path,
        platform_triples: &BTreeSet<String>,
    ) -> Result<BTreeMap<CrateId, SelectList<String>>> {
        let manifest_dir = manifest_path.parent().unwrap();
        let mut target_to_child = BTreeMap::new();
        for target in platform_triples {
            // We use `cargo tree` here because `cargo metadata` doesn't report
            // back target-specific features (enabled with `resolver = "2"`).
            // This is unfortunately a bit of a hack. See:
            // - https://github.com/rust-lang/cargo/issues/9863
            // - https://github.com/bazelbuild/rules_rust/issues/1662
            let output = self
                .cargo_bin
                .command()?
                .current_dir(manifest_dir)
                .arg("tree")
                .arg("--locked")
                .arg("--manifest-path")
                .arg(manifest_path)
                .arg("--prefix=none")
                // https://doc.rust-lang.org/cargo/commands/cargo-tree.html#tree-formatting-options
                .arg("--format=|{p}|{f}|")
                .arg("--color=never")
                .arg("--workspace")
                .arg("--target")
                .arg(target)
                .env("RUSTC", &self.rustc_bin)
                .stdout(std::process::Stdio::piped())
                .stderr(std::process::Stdio::piped())
                .spawn()
                .with_context(|| {
                    format!(
                        "Error spawning cargo in child process to compute features for target '{}', manifest path '{}'",
                        target,
                        manifest_path.display()
                    )
                })?;
            target_to_child.insert(target, output);
        }
        let mut crate_features = BTreeMap::<CrateId, BTreeMap<String, BTreeSet<String>>>::new();
        for (target, child) in target_to_child.into_iter() {
            let output = child
                .wait_with_output()
                .with_context(|| {
                    format!(
                        "Error running cargo in child process to compute features for target '{}', manifest path '{}'",
                        target,
                        manifest_path.display()
                    )
                })?;
            if !output.status.success() {
                eprintln!("{}", String::from_utf8_lossy(&output.stdout));
                eprintln!("{}", String::from_utf8_lossy(&output.stderr));
                bail!(format!("Failed to run cargo tree: {}", output.status))
            }
            for (crate_id, features) in
                parse_features_from_cargo_tree_output(output.stdout.lines())?
            {
                crate_features
                    .entry(crate_id)
                    .or_default()
                    .insert(target.to_owned(), features);
            }
        }
        let mut result = BTreeMap::<CrateId, SelectList<String>>::new();
        for (crate_id, features) in crate_features.into_iter() {
            let common = features
                .iter()
                .fold(
                    None,
                    |common: Option<BTreeSet<String>>, (_, features)| match common {
                        Some(common) => Some(common.intersection(features).cloned().collect()),
                        None => Some(features.clone()),
                    },
                )
                .unwrap_or_default();
            let mut select_list = SelectList::default();
            for (target, fs) in features {
                if fs != common {
                    for f in fs {
                        select_list.insert(f, Some(target.clone()));
                    }
                }
            }
            for f in common {
                select_list.insert(f, None);
            }
            result.insert(crate_id, select_list);
        }
        Ok(result)
    }
}

/// Parses the output of `cargo tree --format=|{p}|{f}|`. Other flags may be
/// passed to `cargo tree` as well, but this format is critical.
fn parse_features_from_cargo_tree_output<I, S, E>(
    lines: I,
) -> Result<BTreeMap<CrateId, BTreeSet<String>>>
where
    I: Iterator<Item = std::result::Result<S, E>>,
    S: AsRef<str>,
    E: std::error::Error + Sync + Send + 'static,
{
    let mut crate_features = BTreeMap::<CrateId, BTreeSet<String>>::new();
    for line in lines {
        let line = line?;
        let line = line.as_ref();
        if line.is_empty() {
            continue;
        }
        let parts = line.split('|').collect::<Vec<_>>();
        if parts.len() != 4 {
            bail!("Unexpected line '{}'", line);
        }
        // We expect the crate id (parts[1]) to be either
        // "<crate name> v<crate version>" or
        // "<crate name> v<crate version> (<path>)"
        // "<crate name> v<crate version> (proc-macro) (<path>)"
        // https://github.com/rust-lang/cargo/blob/19f952f160d4f750d1e12fad2bf45e995719673d/src/cargo/ops/tree/mod.rs#L281
        let crate_id_parts = parts[1].split(' ').collect::<Vec<_>>();
        if crate_id_parts.len() < 2 && crate_id_parts.len() > 4 {
            bail!(
                "Unexpected crate id format '{}' when parsing 'cargo tree' output.",
                parts[1]
            );
        }
        let crate_id = CrateId::new(
            crate_id_parts[0].to_owned(),
            crate_id_parts[1]
                .strip_prefix('v')
                .ok_or_else(|| {
                    anyhow!(
                        "Unexpected crate version '{}' when parsing 'cargo tree' output.",
                        crate_id_parts[1]
                    )
                })?
                .to_owned(),
        );
        let mut features = if parts[2].is_empty() {
            BTreeSet::new()
        } else {
            parts[2].split(',').map(str::to_owned).collect()
        };
        crate_features
            .entry(crate_id)
            .or_default()
            .append(&mut features);
    }
    Ok(crate_features)
}

/// A helper function for writing Cargo metadata to a file.
pub fn write_metadata(path: &Path, metadata: &cargo_metadata::Metadata) -> Result<()> {
    let content =
        serde_json::to_string_pretty(metadata).context("Failed to serialize Cargo Metadata")?;

    fs::write(path, content).context("Failed to write metadata to disk")
}

/// A helper function for deserializing Cargo metadata and lockfiles
pub fn load_metadata(
    metadata_path: &Path,
) -> Result<(cargo_metadata::Metadata, cargo_lock::Lockfile)> {
    // Locate the Cargo.lock file related to the metadata file.
    let lockfile_path = metadata_path
        .parent()
        .expect("metadata files should always have parents")
        .join("Cargo.lock");
    if !lockfile_path.exists() {
        bail!(
            "The metadata file at {} is not next to a `Cargo.lock` file.",
            metadata_path.display()
        )
    }

    let content = fs::read_to_string(metadata_path)
        .with_context(|| format!("Failed to load Cargo Metadata: {}", metadata_path.display()))?;

    let metadata =
        serde_json::from_str(&content).context("Unable to deserialize Cargo metadata")?;

    let lockfile = cargo_lock::Lockfile::load(&lockfile_path)
        .with_context(|| format!("Failed to load lockfile: {}", lockfile_path.display()))?;

    Ok((metadata, lockfile))
}

#[cfg(test)]
mod test {
    use super::*;

    #[test]
    fn deserialize_cargo_update_request_for_eager() {
        for value in ["all", "full", "eager"] {
            let request = CargoUpdateRequest::from_str(value).unwrap();

            assert_eq!(request, CargoUpdateRequest::Eager);
        }
    }

    #[test]
    fn deserialize_cargo_update_request_for_workspace() {
        for value in ["1", "true", "yes", "on", "workspace", "minimal"] {
            let request = CargoUpdateRequest::from_str(value).unwrap();

            assert_eq!(request, CargoUpdateRequest::Workspace);
        }
    }

    #[test]
    fn deserialize_cargo_update_request_for_package() {
        let request = CargoUpdateRequest::from_str("cargo-bazel").unwrap();

        assert_eq!(
            request,
            CargoUpdateRequest::Package {
                name: "cargo-bazel".to_owned(),
                version: None
            }
        );
    }

    #[test]
    fn deserialize_cargo_update_request_for_precise() {
        let request = CargoUpdateRequest::from_str("cargo-bazel@1.2.3").unwrap();

        assert_eq!(
            request,
            CargoUpdateRequest::Package {
                name: "cargo-bazel".to_owned(),
                version: Some("1.2.3".to_owned())
            }
        );
    }

    #[test]
    fn parse_features_from_cargo_tree_output_prefix_none() {
        assert_eq!(
            parse_features_from_cargo_tree_output(
                vec![
                    Ok::<&str, std::io::Error>(""), // Blank lines are ignored.
                    Ok("|multi_cfg_dep v0.1.0 (/private/tmp/ct)||"),
                    Ok("|chrono v0.4.24|default,std|"),
                    Ok("|cpufeatures v0.2.1||"),
                    Ok("|libc v0.2.117|default,std|"),
                    Ok("|serde_derive v1.0.152 (proc-macro) (*)||"),
                    Ok("|chrono v0.4.24|default,std,serde|"),
                ]
                .into_iter()
            )
            .unwrap(),
            BTreeMap::from([
                (
                    CrateId {
                        name: "multi_cfg_dep".to_owned(),
                        version: "0.1.0".to_owned()
                    },
                    BTreeSet::from([])
                ),
                (
                    CrateId {
                        name: "cpufeatures".to_owned(),
                        version: "0.2.1".to_owned()
                    },
                    BTreeSet::from([])
                ),
                (
                    CrateId {
                        name: "libc".to_owned(),
                        version: "0.2.117".to_owned()
                    },
                    BTreeSet::from(["default".to_owned(), "std".to_owned()])
                ),
                (
                    CrateId {
                        name: "serde_derive".to_owned(),
                        version: "1.0.152".to_owned()
                    },
                    BTreeSet::from([])
                ),
                (
                    CrateId {
                        name: "chrono".to_owned(),
                        version: "0.4.24".to_owned()
                    },
                    BTreeSet::from(["default".to_owned(), "std".to_owned(), "serde".to_owned()])
                ),
            ])
        );
    }
}
