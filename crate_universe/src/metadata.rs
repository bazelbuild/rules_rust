//! Tools for gathering various kinds of metadata (Cargo.lock, Cargo metadata, Crate Index info).

mod dependency;
mod metadata_annotation;

use std::collections::{BTreeMap, BTreeSet, HashMap};
use std::env;
use std::ffi::OsString;
use std::fs;
use std::io::BufRead;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::str::FromStr;
use std::sync::{Arc, Mutex};

use anyhow::{anyhow, bail, Context, Result};
use cargo_lock::Lockfile as CargoLockfile;
use cargo_metadata::{Metadata as CargoMetadata, MetadataCommand};
use semver::Version;
use serde::{Deserialize, Serialize};
use tracing::debug;
use url::Url;

use crate::config::CrateId;
use crate::lockfile::Digest;
use crate::select::{Select, SelectableScalar};
use crate::utils::symlink::symlink;
use crate::utils::target_triple::TargetTriple;

pub(crate) use self::dependency::*;
pub(crate) use self::metadata_annotation::*;

// TODO: This should also return a set of [crate-index::IndexConfig]s for packages in metadata.packages
/// A Trait for generating metadata (`cargo metadata` output and a lock file) from a Cargo manifest.
pub(crate) trait MetadataGenerator {
    fn generate<T: AsRef<Path>>(&self, manifest_path: T) -> Result<(CargoMetadata, CargoLockfile)>;
}

/// Generates Cargo metadata and a lockfile from a provided manifest.
pub(crate) struct Generator {
    /// The path to a `cargo` binary
    cargo_bin: Cargo,

    /// The path to a `rustc` binary
    rustc_bin: PathBuf,
}

impl Generator {
    pub(crate) fn new() -> Self {
        let rustc_bin = PathBuf::from(env::var("RUSTC").unwrap_or_else(|_| "rustc".to_string()));
        Generator {
            cargo_bin: Cargo::new(
                PathBuf::from(env::var("CARGO").unwrap_or_else(|_| "cargo".to_string())),
                rustc_bin.clone(),
            ),
            rustc_bin,
        }
    }

    pub(crate) fn with_cargo(mut self, cargo_bin: Cargo) -> Self {
        self.cargo_bin = cargo_bin;
        self
    }

    pub(crate) fn with_rustc(mut self, rustc_bin: PathBuf) -> Self {
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
            .metadata_command_with_options(manifest_path.as_ref(), vec!["--locked".to_owned()])?
            .exec()?;

        Ok((metadata, lockfile))
    }
}

/// Cargo encapsulates a path to a `cargo` binary.
/// Any invocations of `cargo` (either as a `std::process::Command` or via `cargo_metadata`) should
/// go via this wrapper to ensure that any environment variables needed are set appropriately.
#[derive(Debug, Clone)]
pub(crate) struct Cargo {
    path: PathBuf,
    rustc_path: PathBuf,
    full_version: Arc<Mutex<Option<String>>>,
    cargo_home: Option<PathBuf>,
}

impl Cargo {
    pub(crate) fn new(path: PathBuf, rustc: PathBuf) -> Cargo {
        Cargo {
            path,
            rustc_path: rustc,
            full_version: Arc::new(Mutex::new(None)),
            cargo_home: None,
        }
    }

    #[cfg(test)]
    pub(crate) fn with_cargo_home(mut self, path: PathBuf) -> Cargo {
        self.cargo_home = Some(path);
        self
    }

    /// Returns a new `Command` for running this cargo.
    pub(crate) fn command(&self) -> Result<Command> {
        let mut command = Command::new(&self.path);
        command.envs(self.env()?);
        if self.is_nightly()? {
            command.arg("-Zbindeps");
        }
        Ok(command)
    }

    /// Returns a new `MetadataCommand` using this cargo.
    /// `manifest_path`, `current_dir`, and `other_options` should not be called on the resturned MetadataCommand - instead pass them as the relevant args.
    pub(crate) fn metadata_command_with_options(
        &self,
        manifest_path: &Path,
        other_options: Vec<String>,
    ) -> Result<MetadataCommand> {
        let mut command = MetadataCommand::new();
        command.cargo_path(&self.path);
        for (k, v) in self.env()? {
            command.env(k, v);
        }

        command.manifest_path(manifest_path);
        // Cargo detects config files based on `pwd` when running so
        // to ensure user provided Cargo config files are used, it's
        // critical to set the working directory to the manifest dir.
        let manifest_dir = manifest_path
            .parent()
            .ok_or_else(|| anyhow::anyhow!("manifest_path {:?} must have parent", manifest_path))?;
        command.current_dir(manifest_dir);

        let mut other_options = other_options;
        if self.is_nightly()? {
            other_options.push("-Zbindeps".to_owned());
        }
        command.other_options(other_options);
        Ok(command)
    }

    /// Returns the output of running `cargo version`, trimming any leading or trailing whitespace.
    /// This function performs normalisation to work around `<https://github.com/rust-lang/cargo/issues/10547>`
    pub(crate) fn full_version(&self) -> Result<String> {
        let mut full_version = self.full_version.lock().unwrap();
        if full_version.is_none() {
            let observed_version = Digest::bin_version(&self.path)?;
            *full_version = Some(observed_version);
        }
        Ok(full_version.clone().unwrap())
    }

    pub(crate) fn is_nightly(&self) -> Result<bool> {
        let full_version = self.full_version()?;
        let version_str = full_version.split(' ').nth(1);
        if let Some(version_str) = version_str {
            let version = Version::parse(version_str).context("Failed to parse cargo version")?;
            return Ok(version.pre.as_str() == "nightly");
        }
        bail!("Couldn't parse cargo version");
    }

    pub(crate) fn use_sparse_registries_for_crates_io(&self) -> Result<bool> {
        let full_version = self.full_version()?;
        let version_str = full_version.split(' ').nth(1);
        if let Some(version_str) = version_str {
            let version = Version::parse(version_str).context("Failed to parse cargo version")?;
            return Ok(version.major >= 1 && version.minor >= 68);
        }
        bail!("Couldn't parse cargo version");
    }

    /// Determine if Cargo is expected to be using the new package_id spec. For
    /// details see <https://github.com/rust-lang/cargo/pull/13311>
    #[cfg(test)]
    pub(crate) fn uses_new_package_id_format(&self) -> Result<bool> {
        let full_version = self.full_version()?;
        let version_str = full_version.split(' ').nth(1);
        if let Some(version_str) = version_str {
            let version = Version::parse(version_str).context("Failed to parse cargo version")?;
            return Ok(version.major >= 1 && version.minor >= 77);
        }
        bail!("Couldn't parse cargo version");
    }

    fn env(&self) -> Result<BTreeMap<String, OsString>> {
        let mut map = BTreeMap::new();

        map.insert("RUSTC".into(), self.rustc_path.as_os_str().to_owned());

        if self.use_sparse_registries_for_crates_io()? {
            map.insert(
                "CARGO_REGISTRIES_CRATES_IO_PROTOCOL".into(),
                "sparse".into(),
            );
        }

        if let Some(cargo_home) = &self.cargo_home {
            map.insert("CARGO_HOME".into(), cargo_home.as_os_str().to_owned());
        }

        Ok(map)
    }
}

/// A configuration describing how to invoke [cargo update](https://doc.rust-lang.org/cargo/commands/cargo-update.html).
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

        let mut split = s.splitn(2, '=');
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
    pub(crate) fn update(&self, manifest: &Path, cargo_bin: &Cargo) -> Result<()> {
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

pub(crate) struct LockGenerator {
    /// Interface to cargo.
    cargo_bin: Cargo,
}

impl LockGenerator {
    pub(crate) fn new(cargo_bin: Cargo) -> Self {
        Self { cargo_bin }
    }

    #[tracing::instrument(name = "LockGenerator::generate", skip_all)]
    pub(crate) fn generate(
        &self,
        manifest_path: &Path,
        existing_lock: &Option<PathBuf>,
        update_request: &Option<CargoUpdateRequest>,
    ) -> Result<cargo_lock::Lockfile> {
        debug!("Generating Cargo Lockfile for {}", manifest_path.display());

        let manifest_dir = manifest_path.parent().unwrap();
        let generated_lockfile_path = manifest_dir.join("Cargo.lock");

        if let Some(lock) = existing_lock {
            debug!("Using existing lock {}", lock.display());
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
                request.update(manifest_path, &self.cargo_bin)?;
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
                .arg("--manifest-path")
                .arg(manifest_path)
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
            debug!("Generating new lockfile");
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
pub(crate) struct VendorGenerator {
    /// The path to a `cargo` binary
    cargo_bin: Cargo,

    /// The path to a `rustc` binary
    rustc_bin: PathBuf,
}

impl VendorGenerator {
    pub(crate) fn new(cargo_bin: Cargo, rustc_bin: PathBuf) -> Self {
        Self {
            cargo_bin,
            rustc_bin,
        }
    }
    #[tracing::instrument(name = "VendorGenerator::generate", skip_all)]
    pub(crate) fn generate(&self, manifest_path: &Path, output_dir: &Path) -> Result<()> {
        debug!(
            "Vendoring {} to {}",
            manifest_path.display(),
            output_dir.display()
        );
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

        debug!("Done");
        Ok(())
    }
}

/// Feature resolver info about a given crate.
#[derive(Debug, Default, Clone, Eq, PartialEq, Serialize, Deserialize)]
pub(crate) struct CargoTreeEntry {
    /// The set of features active on a given crate.
    #[serde(default, skip_serializing_if = "BTreeSet::is_empty")]
    pub features: BTreeSet<String>,

    /// The dependencies of a given crate based on feature resolution.
    #[serde(default, skip_serializing_if = "BTreeSet::is_empty")]
    pub deps: BTreeSet<CrateId>,
}

impl CargoTreeEntry {
    pub fn new() -> Self {
        Self {
            features: BTreeSet::new(),
            deps: BTreeSet::new(),
        }
    }

    pub fn is_empty(&self) -> bool {
        self.features.is_empty() && self.deps.is_empty()
    }
}

impl SelectableScalar for CargoTreeEntry {}

/// Feature and dependency metadata generated from [TreeResolver].
pub(crate) type TreeResolverMetadata = BTreeMap<CrateId, Select<CargoTreeEntry>>;

/// Generates metadata about a Cargo workspace tree which supplements the inaccuracies in
/// standard [Cargo metadata](https://doc.rust-lang.org/cargo/commands/cargo-metadata.html)
/// due lack of [Feature resolver 2](https://doc.rust-lang.org/cargo/reference/resolver.html#feature-resolver-version-2)
/// support. This generator can be removed if the following is resolved:
/// <https://github.com/rust-lang/cargo/issues/9863>
pub(crate) struct TreeResolver {
    /// The path to a `cargo` binary
    cargo_bin: Cargo,
}

impl TreeResolver {
    pub(crate) fn new(cargo_bin: Cargo) -> Self {
        Self { cargo_bin }
    }

    /// Computes the set of enabled features for each target triplet for each crate.
    #[tracing::instrument(name = "TreeResolver::generate", skip_all)]
    pub(crate) fn generate(
        &self,
        pristine_manifest_path: &Path,
        target_triples: &BTreeSet<TargetTriple>,
    ) -> Result<TreeResolverMetadata> {
        debug!(
            "Generating features for manifest {}",
            pristine_manifest_path.display()
        );

        let (manifest_path_with_transitive_proc_macros, tempdir) = self
            .copy_project_with_explicit_deps_on_all_transitive_proc_macros(pristine_manifest_path)
            .context("Failed to copy project with proc macro deps made direct")?;

        let mut target_triple_to_child = BTreeMap::new();
        debug!("Spawning processes for {:?}", target_triples);
        for target_triple in target_triples {
            // We use `cargo tree` here because `cargo metadata` doesn't report
            // back target-specific features (enabled with `resolver = "2"`).
            // This is unfortunately a bit of a hack. See:
            // - https://github.com/rust-lang/cargo/issues/9863
            // - https://github.com/bazelbuild/rules_rust/issues/1662
            let output = self
                .cargo_bin
                .command()?
                .current_dir(tempdir.path())
                .arg("tree")
                .arg("--manifest-path")
                .arg(&manifest_path_with_transitive_proc_macros)
                .arg("--edges")
                .arg("normal,build,dev")
                .arg("--prefix=depth")
                // https://doc.rust-lang.org/cargo/commands/cargo-tree.html#tree-formatting-options
                .arg("--format=|{p}|{f}|")
                .arg("--color=never")
                .arg("--workspace")
                .arg("--target")
                .arg(target_triple.to_cargo())
                .stdout(std::process::Stdio::piped())
                .stderr(std::process::Stdio::piped())
                .spawn()
                .with_context(|| {
                    format!(
                        "Error spawning cargo in child process to compute features for target '{}', manifest path '{}'",
                        target_triple,
                        manifest_path_with_transitive_proc_macros.display()
                    )
                })?;
            target_triple_to_child.insert(target_triple, output);
        }
        let mut metadata: BTreeMap<CrateId, BTreeMap<TargetTriple, CargoTreeEntry>> =
            BTreeMap::new();
        for (target_triple, child) in target_triple_to_child.into_iter() {
            let output = child
                .wait_with_output()
                .with_context(|| {
                    format!(
                        "Error running cargo in child process to compute features for target '{}', manifest path '{}'",
                        target_triple,
                        manifest_path_with_transitive_proc_macros.display()
                    )
                })?;
            if !output.status.success() {
                eprintln!("{}", String::from_utf8_lossy(&output.stdout));
                eprintln!("{}", String::from_utf8_lossy(&output.stderr));
                bail!(format!("Failed to run cargo tree: {}", output.status))
            }
            debug!("Process complete for {}", target_triple);
            for (crate_id, tree_data) in
                parse_features_from_cargo_tree_output(output.stdout.lines())?
            {
                debug!(
                    "\tFor {}\n\t\tfeatures: {:?}\n\t\tdeps: {:?}",
                    crate_id, tree_data.features, tree_data.deps
                );
                metadata
                    .entry(crate_id.clone())
                    .or_default()
                    .insert(target_triple.clone(), tree_data);
            }
        }
        let mut result = TreeResolverMetadata::new();
        for (crate_id, tree_data) in metadata.into_iter() {
            let common = CargoTreeEntry {
                features: tree_data
                    .iter()
                    .fold(
                        None,
                        |common: Option<BTreeSet<String>>, (_, data)| match common {
                            Some(common) => {
                                Some(common.intersection(&data.features).cloned().collect())
                            }
                            None => Some(data.features.clone()),
                        },
                    )
                    .unwrap_or_default(),
                deps: tree_data
                    .iter()
                    .fold(
                        None,
                        |common: Option<BTreeSet<CrateId>>, (_, data)| match common {
                            Some(common) => {
                                Some(common.intersection(&data.deps).cloned().collect())
                            }
                            None => Some(data.deps.clone()),
                        },
                    )
                    .unwrap_or_default(),
            };
            let mut select: Select<CargoTreeEntry> = Select::default();
            for (target_triple, data) in tree_data {
                let mut entry = CargoTreeEntry::new();
                entry.features.extend(
                    data.features
                        .into_iter()
                        .filter(|f| !common.features.contains(f)),
                );
                entry
                    .deps
                    .extend(data.deps.into_iter().filter(|d| !common.deps.contains(d)));
                if !entry.is_empty() {
                    select.insert(entry, Some(target_triple.to_bazel()));
                }
            }
            if !common.is_empty() {
                select.insert(common, None);
            }
            result.insert(crate_id, select);
        }
        Ok(result)
    }

    // Artificially inject all proc macros as dependency roots.
    // Proc macros are built in the exec rather than target configuration.
    // If we do cross-compilation, these will be different, and it will be important that we have resolved features and optional dependencies for the exec platform.
    // If we don't treat proc macros as roots for the purposes of resolving, we may end up with incorrect platform-specific features.
    //
    // Example:
    // If crate foo only uses a proc macro Linux,
    // and that proc-macro depends on syn and requires the feature extra-traits,
    // when we resolve on macOS we'll see we don't need the extra-traits feature of syn because the proc macro isn't used.
    // But if we're cross-compiling for Linux from macOS, we'll build a syn, but because we're building it for macOS (because proc macros are exec-cfg dependencies),
    // we'll build syn but _without_ the extra-traits feature (because our resolve told us it was Linux only).
    //
    // By artificially injecting all proc macros as root dependencies,
    // it means we are forced to resolve the dependencies and features for those proc-macros on all platforms we care about,
    // even if they wouldn't be used in some platform when cfg == exec.
    //
    // This is tested by the "keyring" example in examples/musl_cross_compiling - the keyring crate uses proc-macros only on Linux,
    // and if we don't have this fake root injection, cross-compiling from Darwin to Linux won't work because features don't get correctly resolved for the exec=darwin case.
    fn copy_project_with_explicit_deps_on_all_transitive_proc_macros(
        &self,
        pristine_manifest_path: &Path,
    ) -> Result<(PathBuf, tempfile::TempDir)> {
        let pristine_root = pristine_manifest_path.parent().unwrap();
        let working_directory = tempfile::tempdir().context("Failed to make tempdir")?;
        for file in std::fs::read_dir(pristine_root).context("Failed to read dir")? {
            let source_path = file?.path();
            let file_name = source_path.file_name().unwrap();
            if file_name != "Cargo.toml" && file_name != "Cargo.lock" {
                let destination = working_directory.path().join(file_name);
                symlink(&source_path, &destination).with_context(|| {
                    format!(
                        "Failed to create symlink {:?} pointing at {:?}",
                        destination, source_path
                    )
                })?;
            }
        }
        std::fs::copy(
            pristine_root.join("Cargo.lock"),
            working_directory.path().join("Cargo.lock"),
        )
        .with_context(|| {
            format!(
                "Failed to copy Cargo.lock from {:?} to {:?}",
                pristine_root,
                working_directory.path()
            )
        })?;

        let cargo_metadata = self
            .cargo_bin
            .metadata_command_with_options(pristine_manifest_path, vec!["--locked".to_owned()])?
            .manifest_path(pristine_manifest_path)
            .exec()
            .context("Failed to run cargo metadata to list transitive proc macros")?;
        let proc_macros = cargo_metadata
            .packages
            .iter()
            .filter(|p| {
                p.targets
                    .iter()
                    .any(|t| t.kind.iter().any(|k| k == "proc-macro"))
            })
            // Filter out any in-workspace proc macros, populate dependency details for non-in-workspace proc macros.
            .filter_map(|pm| {
                if let Some(source) = pm.source.as_ref() {
                    let mut detail = DependencyDetailWithOrd(cargo_toml::DependencyDetail {
                        package: Some(pm.name.clone()),
                        // Don't forcibly enable default features - if some other dependency enables them, they will still be enabled.
                        default_features: false,
                        ..cargo_toml::DependencyDetail::default()
                    });

                    let source = match Source::parse(&source.repr, pm.version.to_string()) {
                        Ok(source) => source,
                        Err(err) => {
                            return Some(Err(err));
                        }
                    };
                    source.populate_details(&mut detail.0);

                    Some(Ok((pm.name.clone(), detail)))
                } else {
                    None
                }
            })
            .collect::<Result<BTreeSet<_>>>()?;

        let mut manifest =
            cargo_toml::Manifest::from_path(pristine_manifest_path).with_context(|| {
                format!(
                    "Failed to parse Cargo.toml file at {:?}",
                    pristine_manifest_path
                )
            })?;

        // To add dependencies to a virtual workspace, we need to add them to a package inside the workspace,
        // we can't just add them to the workspace directly.
        if !proc_macros.is_empty() && manifest.package.is_none() {
            if let Some(ref mut workspace) = &mut manifest.workspace {
                if !workspace.members.contains(&".".to_owned()) {
                    workspace.members.push(".".to_owned());
                }
                manifest.package = Some(cargo_toml::Package::new(
                    "rules_rust_fake_proc_macro_root",
                    "0.0.0",
                ));
            }
            if manifest.lib.is_none() && manifest.bin.is_empty() {
                manifest.bin.push(cargo_toml::Product {
                    name: Some("rules_rust_fake_proc_macro_root_bin".to_owned()),
                    path: Some("/dev/null".to_owned()),
                    ..cargo_toml::Product::default()
                })
            }
        }

        let mut count_map: HashMap<_, u64> = HashMap::new();
        for (dep_name, detail) in proc_macros {
            let count = count_map.entry(dep_name.clone()).or_default();
            manifest.dependencies.insert(
                format!("rules_rust_fake_proc_macro_root_{}_{}", dep_name, count),
                cargo_toml::Dependency::Detailed(Box::new(detail.0)),
            );
            *count += 1;
        }
        let manifest_path_with_transitive_proc_macros = working_directory.path().join("Cargo.toml");
        crate::splicing::write_manifest(&manifest_path_with_transitive_proc_macros, &manifest)?;
        Ok((manifest_path_with_transitive_proc_macros, working_directory))
    }
}

// cargo_toml::DependencyDetail doesn't implement PartialOrd/Ord so can't be put in a sorted collection.
// Wrap it so we can sort things for stable orderings.
#[derive(Debug, PartialEq)]
struct DependencyDetailWithOrd(cargo_toml::DependencyDetail);

impl PartialOrd for DependencyDetailWithOrd {
    fn partial_cmp(&self, other: &Self) -> Option<std::cmp::Ordering> {
        Some(self.cmp(other))
    }
}

impl Ord for DependencyDetailWithOrd {
    fn cmp(&self, other: &Self) -> std::cmp::Ordering {
        let cargo_toml::DependencyDetail {
            version,
            registry,
            registry_index,
            path,
            inherited,
            git,
            branch,
            tag,
            rev,
            features,
            optional,
            default_features,
            package,
            unstable: _,
        } = &self.0;

        version
            .cmp(&other.0.version)
            .then(registry.cmp(&other.0.registry))
            .then(registry_index.cmp(&other.0.registry_index))
            .then(path.cmp(&other.0.path))
            .then(inherited.cmp(&other.0.inherited))
            .then(git.cmp(&other.0.git))
            .then(branch.cmp(&other.0.branch))
            .then(tag.cmp(&other.0.tag))
            .then(rev.cmp(&other.0.rev))
            .then(features.cmp(&other.0.features))
            .then(optional.cmp(&other.0.optional))
            .then(default_features.cmp(&other.0.default_features))
            .then(package.cmp(&other.0.package))
    }
}

impl Eq for DependencyDetailWithOrd {}

#[derive(Debug, PartialEq, Eq)]
enum Source {
    Registry {
        registry: String,
        version: String,
    },
    Git {
        git: String,
        rev: Option<String>,
        branch: Option<String>,
        tag: Option<String>,
    },
}

impl Source {
    fn parse(string: &str, version: String) -> Result<Source> {
        let url: Url = Url::parse(string)?;
        let original_scheme = url.scheme().to_owned();
        let scheme_parts: Vec<_> = original_scheme.split('+').collect();
        match &scheme_parts[..] {
            // e.g. registry+https://github.com/rust-lang/crates.io-index
            ["registry", scheme] => {
                let new_url = set_url_scheme_despite_the_url_crate_not_wanting_us_to(&url, scheme)?;
                Ok(Self::Registry {
                    registry: new_url,
                    version,
                })
            }
            // e.g. git+https://github.com/serde-rs/serde.git?rev=9b868ef831c95f50dd4bde51a7eb52e3b9ee265a#9b868ef831c95f50dd4bde51a7eb52e3b9ee265a
            ["git", scheme] => {
                let mut query: HashMap<String, String> = url
                    .query_pairs()
                    .map(|(k, v)| (k.into_owned(), v.into_owned()))
                    .collect();

                let mut url = url;
                url.set_fragment(None);
                url.set_query(None);
                let new_url = set_url_scheme_despite_the_url_crate_not_wanting_us_to(&url, scheme)?;

                Ok(Self::Git {
                    git: new_url,
                    rev: query.remove("rev"),
                    branch: query.remove("branch"),
                    tag: query.remove("tag"),
                })
            }
            _ => {
                anyhow::bail!(
                    "Couldn't parse source {:?}: Didn't recognise scheme",
                    string
                );
            }
        }
    }

    fn populate_details(self, details: &mut cargo_toml::DependencyDetail) {
        match self {
            Self::Registry { registry, version } => {
                details.registry_index = Some(registry);
                details.version = Some(version);
            }
            Self::Git {
                git,
                rev,
                branch,
                tag,
            } => {
                details.git = Some(git);
                details.rev = rev;
                details.branch = branch;
                details.tag = tag;
            }
        }
    }
}

fn set_url_scheme_despite_the_url_crate_not_wanting_us_to(
    url: &Url,
    new_scheme: &str,
) -> Result<String> {
    let (_old_scheme, new_url_without_scheme) = url.as_str().split_once(':').ok_or_else(|| {
        anyhow::anyhow!(
            "Cannot set schme of URL which doesn't contain \":\": {:?}",
            url
        )
    })?;
    Ok(format!("{new_scheme}:{new_url_without_scheme}"))
}

/// Parses the output of `cargo tree --format=|{p}|{f}|`. Other flags may be
/// passed to `cargo tree` as well, but this format is critical.
fn parse_features_from_cargo_tree_output<I, S, E>(
    lines: I,
) -> Result<BTreeMap<CrateId, CargoTreeEntry>>
where
    I: Iterator<Item = std::result::Result<S, E>>,
    S: AsRef<str>,
    E: std::error::Error + Sync + Send + 'static,
{
    let mut tree_data = BTreeMap::<CrateId, CargoTreeEntry>::new();
    let mut parents: Vec<CrateId> = Vec::new();
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
        let version_str = crate_id_parts[1].strip_prefix('v').ok_or_else(|| {
            anyhow!(
                "Unexpected crate version '{}' when parsing 'cargo tree' output.",
                crate_id_parts[1]
            )
        })?;
        let version = Version::parse(version_str).context("Failed to parse version")?;
        let crate_id = CrateId::new(crate_id_parts[0].to_owned(), version);

        // Update bookkeeping for dependency tracking.
        let depth = parts[0]
            .parse::<usize>()
            .with_context(|| format!("Unexpected numeric value from cargo tree: {:?}", parts))?;
        if (depth + 1) <= parents.len() {
            // Drain parents until we get down to the right depth
            let range = parents.len() - (depth + 1);
            for _ in 0..range {
                parents.pop();
            }

            // If the current parent does not have the same Crate ID, then
            // it's likely we have moved to a different crate. This can happen
            // in the following case
            // ```
            // ├── proc-macro2 v1.0.81
            // │   └── unicode-ident v1.0.12
            // ├── quote v1.0.36
            // │   └── proc-macro2 v1.0.81 (*)
            // ```
            if parents.last() != Some(&crate_id) {
                parents.pop();
                parents.push(crate_id.clone());
            }
        } else {
            // Start tracking the current crate as the new parent for any
            // crates that represent a new depth in the dep tree.
            parents.push(crate_id.clone());
        }

        // Attribute any dependency that is not the root to it's parent.
        if depth > 0 {
            // Access the last item in the list of parents.
            if let Some(parent) = parents.iter().rev().nth(1) {
                tree_data
                    .entry(parent.clone())
                    .or_default()
                    .deps
                    .insert(crate_id.clone());
            }
        }

        let mut features = if parts[2].is_empty() {
            BTreeSet::new()
        } else {
            parts[2].split(',').map(str::to_owned).collect()
        };
        tree_data
            .entry(crate_id)
            .or_default()
            .features
            .append(&mut features);
    }
    Ok(tree_data)
}

/// A helper function for writing Cargo metadata to a file.
pub(crate) fn write_metadata(path: &Path, metadata: &cargo_metadata::Metadata) -> Result<()> {
    let content =
        serde_json::to_string_pretty(metadata).context("Failed to serialize Cargo Metadata")?;

    fs::write(path, content).context("Failed to write metadata to disk")
}

/// A helper function for deserializing Cargo metadata and lockfiles
pub(crate) fn load_metadata(
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
                name: "cargo-bazel@1.2.3".to_owned(),
                version: None
            }
        );
    }

    #[test]
    fn deserialize_cargo_update_request_for_precise_pin() {
        let request = CargoUpdateRequest::from_str("cargo-bazel@1.2.3=4.5.6").unwrap();

        assert_eq!(
            request,
            CargoUpdateRequest::Package {
                name: "cargo-bazel@1.2.3".to_owned(),
                version: Some("4.5.6".to_owned()),
            }
        );
    }

    #[test]
    fn parse_features_from_cargo_tree_output_prefix_none() {
        let autocfg_id = CrateId {
            name: "autocfg".to_owned(),
            version: Version::new(1, 2, 0),
        };
        let chrono_id = CrateId {
            name: "chrono".to_owned(),
            version: Version::new(0, 4, 24),
        };
        let core_foundation_sys_id = CrateId {
            name: "core-foundation-sys".to_owned(),
            version: Version::new(0, 8, 6),
        };
        let cpufeatures_id = CrateId {
            name: "cpufeatures".to_owned(),
            version: Version::new(0, 2, 7),
        };
        let iana_time_zone_id = CrateId {
            name: "iana-time-zone".to_owned(),
            version: Version::new(0, 1, 60),
        };
        let libc_id = CrateId {
            name: "libc".to_owned(),
            version: Version::new(0, 2, 153),
        };
        let num_integer_id = CrateId {
            name: "num-integer".to_owned(),
            version: Version::new(0, 1, 46),
        };
        let num_traits_id = CrateId {
            name: "num-traits".to_owned(),
            version: Version::new(0, 2, 18),
        };
        let proc_macro2_id = CrateId {
            name: "proc-macro2".to_owned(),
            version: Version::new(1, 0, 81),
        };
        let quote_id = CrateId {
            name: "quote".to_owned(),
            version: Version::new(1, 0, 36),
        };
        let serde_derive_id = CrateId {
            name: "serde_derive".to_owned(),
            version: Version::new(1, 0, 152),
        };
        let syn_id = CrateId {
            name: "syn".to_owned(),
            version: Version::new(1, 0, 109),
        };
        let time_id = CrateId {
            name: "time".to_owned(),
            version: Version::new(0, 1, 45),
        };
        let tree_data_id = CrateId {
            name: "tree-data".to_owned(),
            version: Version::new(0, 1, 0),
        };
        let unicode_ident_id = CrateId {
            name: "unicode-ident".to_owned(),
            version: Version::new(1, 0, 12),
        };

        // |tree-data v0.1.0 (/rules_rust/crate_universe/test_data/metadata/tree_data)||
        // ├── |chrono v0.4.24|clock,default,iana-time-zone,js-sys,oldtime,std,time,wasm-bindgen,wasmbind,winapi|
        // │   ├── |iana-time-zone v0.1.60|fallback|
        // │   │   └── |core-foundation-sys v0.8.6|default,link|
        // │   ├── |num-integer v0.1.46||
        // │   │   └── |num-traits v0.2.18|i128|
        // │   │       [build-dependencies]
        // │   │       └── |autocfg v1.2.0||
        // │   ├── |num-traits v0.2.18|i128| (*)
        // │   └── |time v0.1.45||
        // │       └── |libc v0.2.153|default,std|
        // ├── |cpufeatures v0.2.7||
        // │   └── |libc v0.2.153|default,std|
        // └── |serde_derive v1.0.152 (proc-macro)|default|
        //     ├── |proc-macro2 v1.0.81|default,proc-macro|
        //     │   └── |unicode-ident v1.0.12||
        //     ├── |quote v1.0.36|default,proc-macro|
        //     │   └── |proc-macro2 v1.0.81|default,proc-macro| (*)
        //     └── |syn v1.0.109|clone-impls,default,derive,parsing,printing,proc-macro,quote|
        //         ├── |proc-macro2 v1.0.81|default,proc-macro| (*)
        //         ├── |quote v1.0.36|default,proc-macro| (*)
        //         └── |unicode-ident v1.0.12||
        let output = parse_features_from_cargo_tree_output(
            vec![
                Ok::<&str, std::io::Error>(""), // Blank lines are ignored.
                Ok("0|tree-data v0.1.0 (/rules_rust/crate_universe/test_data/metadata/tree_data)||"),
                Ok("1|chrono v0.4.24|clock,default,iana-time-zone,js-sys,oldtime,std,time,wasm-bindgen,wasmbind,winapi|"),
                Ok("2|iana-time-zone v0.1.60|fallback|"),
                Ok("3|core-foundation-sys v0.8.6|default,link|"),
                Ok("2|num-integer v0.1.46||"),
                Ok("3|num-traits v0.2.18|i128|"),
                Ok("4|autocfg v1.2.0||"),
                Ok("2|num-traits v0.2.18|i128| (*)"),
                Ok("2|time v0.1.45||"),
                Ok("3|libc v0.2.153|default,std|"),
                Ok("1|cpufeatures v0.2.7||"),
                Ok("2|libc v0.2.153|default,std|"),
                Ok("1|serde_derive v1.0.152 (proc-macro)|default|"),
                Ok("2|proc-macro2 v1.0.81|default,proc-macro|"),
                Ok("3|unicode-ident v1.0.12||"),
                Ok("2|quote v1.0.36|default,proc-macro|"),
                Ok("3|proc-macro2 v1.0.81|default,proc-macro| (*)"),
                Ok("2|syn v1.0.109|clone-impls,default,derive,parsing,printing,proc-macro,quote|"),
                Ok("3|proc-macro2 v1.0.81|default,proc-macro| (*)"),
                Ok("3|quote v1.0.36|default,proc-macro| (*)"),
                Ok("3|unicode-ident v1.0.12||"),
            ]
            .into_iter()
        )
        .unwrap();
        assert_eq!(
            BTreeMap::from([
                (
                    autocfg_id.clone(),
                    CargoTreeEntry {
                        features: BTreeSet::new(),
                        deps: BTreeSet::new(),
                    },
                ),
                (
                    chrono_id.clone(),
                    CargoTreeEntry {
                        features: BTreeSet::from([
                            "clock".to_owned(),
                            "default".to_owned(),
                            "iana-time-zone".to_owned(),
                            "js-sys".to_owned(),
                            "oldtime".to_owned(),
                            "std".to_owned(),
                            "time".to_owned(),
                            "wasm-bindgen".to_owned(),
                            "wasmbind".to_owned(),
                            "winapi".to_owned(),
                        ]),
                        deps: BTreeSet::from([
                            iana_time_zone_id.clone(),
                            num_integer_id.clone(),
                            num_traits_id.clone(),
                            time_id.clone(),
                        ]),
                    }
                ),
                (
                    core_foundation_sys_id.clone(),
                    CargoTreeEntry {
                        features: BTreeSet::from(["default".to_owned(), "link".to_owned()]),
                        deps: BTreeSet::new(),
                    }
                ),
                (
                    cpufeatures_id.clone(),
                    CargoTreeEntry {
                        features: BTreeSet::new(),
                        deps: BTreeSet::from([libc_id.clone()]),
                    },
                ),
                (
                    iana_time_zone_id,
                    CargoTreeEntry {
                        features: BTreeSet::from(["fallback".to_owned()]),
                        deps: BTreeSet::from([core_foundation_sys_id]),
                    }
                ),
                (
                    libc_id.clone(),
                    CargoTreeEntry {
                        features: BTreeSet::from(["default".to_owned(), "std".to_owned()]),
                        deps: BTreeSet::new(),
                    }
                ),
                (
                    num_integer_id,
                    CargoTreeEntry {
                        features: BTreeSet::new(),
                        deps: BTreeSet::from([num_traits_id.clone()]),
                    },
                ),
                (
                    num_traits_id,
                    CargoTreeEntry {
                        features: BTreeSet::from(["i128".to_owned()]),
                        deps: BTreeSet::from([autocfg_id]),
                    }
                ),
                (
                    proc_macro2_id.clone(),
                    CargoTreeEntry {
                        features: BTreeSet::from(["default".to_owned(), "proc-macro".to_owned()]),
                        deps: BTreeSet::from([unicode_ident_id.clone()])
                    }
                ),
                (
                    quote_id.clone(),
                    CargoTreeEntry {
                        features: BTreeSet::from(["default".to_owned(), "proc-macro".to_owned()]),
                        deps: BTreeSet::from([proc_macro2_id.clone()]),
                    }
                ),
                (
                    serde_derive_id.clone(),
                    CargoTreeEntry {
                        features: BTreeSet::from(["default".to_owned()]),
                        deps: BTreeSet::from([
                            proc_macro2_id.clone(),
                            quote_id.clone(),
                            syn_id.clone()
                        ]),
                    }
                ),
                (
                    syn_id,
                    CargoTreeEntry {
                        features: BTreeSet::from([
                            "clone-impls".to_owned(),
                            "default".to_owned(),
                            "derive".to_owned(),
                            "parsing".to_owned(),
                            "printing".to_owned(),
                            "proc-macro".to_owned(),
                            "quote".to_owned(),
                        ]),
                        deps: BTreeSet::from([proc_macro2_id, quote_id, unicode_ident_id.clone(),]),
                    }
                ),
                (
                    time_id,
                    CargoTreeEntry {
                        features: BTreeSet::new(),
                        deps: BTreeSet::from([libc_id]),
                    }
                ),
                (
                    tree_data_id,
                    CargoTreeEntry {
                        features: BTreeSet::new(),
                        deps: BTreeSet::from([chrono_id, cpufeatures_id, serde_derive_id,]),
                    }
                ),
                (
                    unicode_ident_id,
                    CargoTreeEntry {
                        features: BTreeSet::new(),
                        deps: BTreeSet::new()
                    }
                )
            ]),
            output,
        );
    }

    #[test]
    fn serde_cargo_tree_entry() {
        {
            let entry: CargoTreeEntry = serde_json::from_str("{}").unwrap();
            assert_eq!(CargoTreeEntry::new(), entry);
        }
        {
            let entry: CargoTreeEntry =
                serde_json::from_str(r#"{"features": ["default"]}"#).unwrap();
            assert_eq!(
                CargoTreeEntry {
                    features: BTreeSet::from(["default".to_owned()]),
                    deps: BTreeSet::new(),
                },
                entry
            );
        }
        {
            let entry: CargoTreeEntry =
                serde_json::from_str(r#"{"deps": ["common 1.2.3"]}"#).unwrap();
            assert_eq!(
                CargoTreeEntry {
                    features: BTreeSet::new(),
                    deps: BTreeSet::from([CrateId::new(
                        "common".to_owned(),
                        Version::new(1, 2, 3)
                    )]),
                },
                entry
            );
        }
        {
            let entry: CargoTreeEntry =
                serde_json::from_str(r#"{"features": ["default"], "deps": ["common 1.2.3"]}"#)
                    .unwrap();
            assert_eq!(
                CargoTreeEntry {
                    features: BTreeSet::from(["default".to_owned()]),
                    deps: BTreeSet::from([CrateId::new(
                        "common".to_owned(),
                        Version::new(1, 2, 3)
                    )]),
                },
                entry
            );
        }
    }

    #[test]
    fn parse_registry_source() {
        let source = Source::parse(
            "registry+https://github.com/rust-lang/crates.io-index",
            "1.0.1".to_owned(),
        )
        .unwrap();
        assert_eq!(
            source,
            Source::Registry {
                registry: "https://github.com/rust-lang/crates.io-index".to_owned(),
                version: "1.0.1".to_owned()
            }
        );
    }

    #[test]
    fn parse_git_source() {
        let source = Source::parse("git+https://github.com/serde-rs/serde.git?rev=9b868ef831c95f50dd4bde51a7eb52e3b9ee265a#9b868ef831c95f50dd4bde51a7eb52e3b9ee265a", "unused".to_owned()).unwrap();
        assert_eq!(
            source,
            Source::Git {
                git: "https://github.com/serde-rs/serde.git".to_owned(),
                rev: Some("9b868ef831c95f50dd4bde51a7eb52e3b9ee265a".to_owned()),
                branch: None,
                tag: None,
            }
        );
    }
}
