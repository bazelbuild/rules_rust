//! Utility for creating valid Cargo workspaces

use std::collections::{BTreeSet, HashMap};
use std::fs;
use std::path::{Path, PathBuf};

use anyhow::{bail, Context, Result};
use cargo_metadata::MetadataCommand;
use cargo_toml::{Dependency, Manifest};
use normpath::PathExt;

use crate::config::CrateId;
use crate::splicing::{SplicedManifest, SplicingManifest};
use crate::utils::starlark::Label;

use super::{read_manifest, DirectPackageManifest, WorkspaceMetadata};

/// The core splicer implementation. Each style of Bazel workspace should be represented
/// here and a splicing implementation defined.
pub enum SplicerKind<'a> {
    /// Splice a manifest which is represented by a Cargo workspace
    Workspace {
        path: &'a PathBuf,
        manifest: &'a Manifest,
        splicing_manifest: &'a SplicingManifest,
    },
    /// Splice a manifest for a single package. This includes cases where
    /// were defined directly in Bazel.
    Package {
        path: &'a PathBuf,
        manifest: &'a Manifest,
        splicing_manifest: &'a SplicingManifest,
    },
    /// Splice a manifest from multiple disjoint Cargo manifests.
    MultiPackage {
        manifests: &'a HashMap<PathBuf, Manifest>,
        splicing_manifest: &'a SplicingManifest,
    },
}

/// A list of files or directories to ignore when when symlinking
const IGNORE_LIST: &[&str] = &[".git", "bazel-*", ".svn"];

impl<'a> SplicerKind<'a> {
    pub fn new(
        manifests: &'a HashMap<PathBuf, Manifest>,
        splicing_manifest: &'a SplicingManifest,
        cargo: &Path,
    ) -> Result<Self> {
        // First check for any workspaces in the provided manifests
        let workspace_owned: HashMap<&PathBuf, &Manifest> = manifests
            .iter()
            .filter(|(_, manifest)| is_workspace_owned(manifest))
            .collect();

        let mut root_workspace_pair: Option<(&PathBuf, &Manifest)> = None;

        if !workspace_owned.is_empty() {
            // Filter for the root workspace manifest info
            let (mut workspace_roots, workspace_packages): (
                HashMap<&PathBuf, &Manifest>,
                HashMap<&PathBuf, &Manifest>,
            ) = workspace_owned
                .clone()
                .into_iter()
                .partition(|(_, manifest)| is_workspace_root(manifest));

            if workspace_roots.len() > 1 {
                bail!("When splicing manifests, there can only be 1 root workspace manifest");
            }

            // This is an error case - we've detected some manifests are in a workspace, but can't
            // find it.
            // This block is just for trying to give as useful an error message as possible in this
            // case.
            if workspace_roots.is_empty() {
                let sorted_manifests: BTreeSet<_> = manifests.keys().collect();
                for manifest_path in sorted_manifests {
                    let metadata_result = MetadataCommand::new()
                        .cargo_path(cargo)
                        .current_dir(manifest_path.parent().unwrap())
                        .manifest_path(manifest_path)
                        .no_deps()
                        .exec();
                    if let Ok(metadata) = metadata_result {
                        let label = Label::from_absolute_path(
                            metadata.workspace_root.join("Cargo.toml").as_std_path(),
                        );
                        if let Ok(label) = label {
                            bail!("Missing root workspace manifest. Please add the following label to the `manifests` key: \"{}\"", label);
                        }
                    }
                }
                bail!("Missing root workspace manifest. Please add the label of the workspace root to the `manifests` key");
            }

            // Ensure all workspace owned manifests are members of the one workspace root
            // UNWRAP: Safe because we've checked workspace_roots isn't empty.
            let (root_manifest_path, root_manifest) = workspace_roots.drain().last().unwrap();
            let external_workspace_members: BTreeSet<String> = workspace_packages
                .into_iter()
                .filter(|(manifest_path, _)| {
                    !is_workspace_member(root_manifest, root_manifest_path, manifest_path)
                })
                .map(|(path, _)| path.to_string_lossy().to_string())
                .collect();

            if !external_workspace_members.is_empty() {
                bail!("A package was provided that appears to be a part of another workspace.\nworkspace root: '{}'\nexternal packages: {:#?}", root_manifest_path.display(), external_workspace_members)
            }

            // UNWRAP: Safe because a Cargo.toml file must have a parent directory.
            let root_manifest_dir = root_manifest_path.parent().unwrap();
            let missing_manifests = Self::find_missing_manifests(
                root_manifest,
                root_manifest_dir,
                &manifests
                    .keys()
                    .map(|p| {
                        p.normalize()
                            .with_context(|| format!("Failed to normalize path {:?}", p))
                    })
                    .collect::<Result<_, _>>()?,
            )
            .context("Identifying missing manifests")?;
            if !missing_manifests.is_empty() {
                bail!("Some manifests are not being tracked. Please add the following labels to the `manifests` key: {:#?}", missing_manifests);
            }

            root_workspace_pair = Some((root_manifest_path, root_manifest));
        }

        if let Some((path, manifest)) = root_workspace_pair {
            Ok(Self::Workspace {
                path,
                manifest,
                splicing_manifest,
            })
        } else if manifests.len() == 1 {
            let (path, manifest) = manifests.iter().last().unwrap();
            Ok(Self::Package {
                path,
                manifest,
                splicing_manifest,
            })
        } else {
            Ok(Self::MultiPackage {
                manifests,
                splicing_manifest,
            })
        }
    }

    fn find_missing_manifests(
        root_manifest: &Manifest,
        root_manifest_dir: &Path,
        known_manifest_paths: &BTreeSet<normpath::BasePathBuf>,
    ) -> Result<BTreeSet<String>> {
        let workspace_manifest_paths = root_manifest
            .workspace
            .as_ref()
            .unwrap()
            .members
            .iter()
            .map(|member| {
                let path = root_manifest_dir.join(member).join("Cargo.toml");
                path.normalize()
                    .with_context(|| format!("Failed to normalize path {:?}", path))
            })
            .collect::<Result<BTreeSet<normpath::BasePathBuf>, _>>()?;

        // Ensure all workspace members are present for the given workspace
        workspace_manifest_paths
            .into_iter()
            .filter(|workspace_manifest_path| {
                !known_manifest_paths.contains(workspace_manifest_path)
            })
            .map(|workspace_manifest_path| {
                let label = Label::from_absolute_path(workspace_manifest_path.as_path())
                    .with_context(|| {
                        format!(
                            "Failed to identify label for path {:?}",
                            workspace_manifest_path
                        )
                    })?;
                Ok(label.to_string())
            })
            .collect()
    }

    /// Performs splicing based on the current variant.
    pub fn splice(&self, workspace_dir: &Path) -> Result<SplicedManifest> {
        match self {
            SplicerKind::Workspace {
                path,
                manifest,
                splicing_manifest,
            } => Self::splice_workspace(workspace_dir, path, manifest, splicing_manifest),
            SplicerKind::Package {
                path,
                manifest,
                splicing_manifest,
            } => Self::splice_package(workspace_dir, path, manifest, splicing_manifest),
            SplicerKind::MultiPackage {
                manifests,
                splicing_manifest,
            } => Self::splice_multi_package(workspace_dir, manifests, splicing_manifest),
        }
    }

    /// Implementation for splicing Cargo workspaces
    fn splice_workspace(
        workspace_dir: &Path,
        path: &&PathBuf,
        manifest: &&Manifest,
        splicing_manifest: &&SplicingManifest,
    ) -> Result<SplicedManifest> {
        let mut manifest = (*manifest).clone();
        let manifest_dir = path
            .parent()
            .expect("Every manifest should havee a parent directory");

        // Link the sources of the root manifest into the new workspace
        symlink_roots(manifest_dir, workspace_dir, Some(IGNORE_LIST))?;

        // Optionally install the cargo config after contents have been symlinked
        Self::setup_cargo_config(&splicing_manifest.cargo_config, workspace_dir)?;

        // Add any additional depeendencies to the root package
        Self::inject_direct_packages(&mut manifest, &splicing_manifest.direct_packages)?;

        let root_manifest_path = workspace_dir.join("Cargo.toml");
        let member_manifests = HashMap::from([(*path, String::new())]);

        // Write the generated metadata to the manifest
        let workspace_metadata = WorkspaceMetadata::new(splicing_manifest, member_manifests)?;
        workspace_metadata.inject_into(&mut manifest)?;

        // Write the root manifest
        write_root_manifest(&root_manifest_path, manifest)?;

        Ok(SplicedManifest::Workspace(root_manifest_path))
    }

    /// Implementation for splicing individual Cargo packages
    fn splice_package(
        workspace_dir: &Path,
        path: &&PathBuf,
        manifest: &&Manifest,
        splicing_manifest: &&SplicingManifest,
    ) -> Result<SplicedManifest> {
        let manifest_dir = path
            .parent()
            .expect("Every manifest should havee a parent directory");

        // Link the sources of the root manifest into the new workspace
        symlink_roots(manifest_dir, workspace_dir, Some(IGNORE_LIST))?;

        // Optionally install the cargo config after contents have been symlinked
        Self::setup_cargo_config(&splicing_manifest.cargo_config, workspace_dir)?;

        // Ensure the root package manifest has a populated `workspace` member
        let mut manifest = (*manifest).clone();
        if manifest.workspace.is_none() {
            manifest.workspace =
                default_cargo_workspace_manifest(&splicing_manifest.resolver_version).workspace
        }

        // Add any additional depeendencies to the root package
        Self::inject_direct_packages(&mut manifest, &splicing_manifest.direct_packages)?;

        let root_manifest_path = workspace_dir.join("Cargo.toml");
        let member_manifests = HashMap::from([(*path, String::new())]);

        // Write the generated metadata to the manifest
        let workspace_metadata = WorkspaceMetadata::new(splicing_manifest, member_manifests)?;
        workspace_metadata.inject_into(&mut manifest)?;

        // Write the root manifest
        write_root_manifest(&root_manifest_path, manifest)?;

        Ok(SplicedManifest::Package(root_manifest_path))
    }

    /// Implementation for splicing together multiple Cargo packages/workspaces
    fn splice_multi_package(
        workspace_dir: &Path,
        manifests: &&HashMap<PathBuf, Manifest>,
        splicing_manifest: &&SplicingManifest,
    ) -> Result<SplicedManifest> {
        let mut manifest = default_cargo_workspace_manifest(&splicing_manifest.resolver_version);

        // Optionally install a cargo config file into the workspace root.
        Self::setup_cargo_config(&splicing_manifest.cargo_config, workspace_dir)?;

        let installations =
            Self::inject_workspace_members(&mut manifest, manifests, workspace_dir)?;

        // Write the generated metadata to the manifest
        let workspace_metadata = WorkspaceMetadata::new(splicing_manifest, installations)?;
        workspace_metadata.inject_into(&mut manifest)?;

        // Add any additional depeendencies to the root package
        Self::inject_direct_packages(&mut manifest, &splicing_manifest.direct_packages)?;

        // Write the root manifest
        let root_manifest_path = workspace_dir.join("Cargo.toml");
        write_root_manifest(&root_manifest_path, manifest)?;

        Ok(SplicedManifest::MultiPackage(root_manifest_path))
    }

    /// A helper for installing Cargo config files into the spliced workspace while also
    /// ensuring no other linked config file is available
    fn setup_cargo_config(cargo_config_path: &Option<PathBuf>, workspace_dir: &Path) -> Result<()> {
        // If the `.cargo` dir is a symlink, we'll need to relink it and ensure
        // a Cargo config file is omitted
        let dot_cargo_dir = workspace_dir.join(".cargo");
        if dot_cargo_dir.exists() {
            let is_symlink = dot_cargo_dir
                .symlink_metadata()
                .map(|m| m.file_type().is_symlink())
                .unwrap_or(false);
            if is_symlink {
                let real_path = dot_cargo_dir.canonicalize()?;
                remove_symlink(&dot_cargo_dir).with_context(|| {
                    format!(
                        "Failed to remove existing symlink {}",
                        dot_cargo_dir.display()
                    )
                })?;
                fs::create_dir(&dot_cargo_dir)?;
                symlink_roots(&real_path, &dot_cargo_dir, Some(&["config", "config.toml"]))?;
            } else {
                for config in vec![
                    dot_cargo_dir.join("config"),
                    dot_cargo_dir.join("config.toml"),
                ] {
                    if config.exists() {
                        remove_symlink(&config).with_context(|| {
                            format!(
                                "Failed to delete existing cargo config: {}",
                                config.display()
                            )
                        })?;
                    }
                }
            }
        }

        // Make sure no other config files exist
        for config in vec![
            workspace_dir.join("config"),
            workspace_dir.join("config.toml"),
            dot_cargo_dir.join("config"),
            dot_cargo_dir.join("config.toml"),
        ] {
            if config.exists() {
                remove_symlink(&config).with_context(|| {
                    format!(
                        "Failed to delete existing cargo config: {}",
                        config.display()
                    )
                })?;
            }
        }

        // Ensure no parent directory also has a cargo config
        let mut current_parent = workspace_dir.parent();
        while let Some(parent) = current_parent {
            let dot_cargo_dir = parent.join(".cargo");
            for config in vec![
                dot_cargo_dir.join("config.toml"),
                dot_cargo_dir.join("config"),
            ] {
                if config.exists() {
                    bail!(
                        "A Cargo config file was found in a parent directory to the current workspace. This is not allowed because these settings will leak into your Bazel build but will not be reproducible on other machines.\nWorkspace = {}\nCargo config = {}",
                        workspace_dir.display(),
                        config.display(),
                    )
                }
            }
            current_parent = parent.parent()
        }

        // Install the new config file after having removed all others
        if let Some(cargo_config_path) = cargo_config_path {
            if !dot_cargo_dir.exists() {
                fs::create_dir_all(&dot_cargo_dir)?;
            }

            fs::copy(cargo_config_path, &dot_cargo_dir.join("config.toml"))?;
        }

        Ok(())
    }

    /// Update the newly generated manifest to include additional packages as
    /// Cargo workspace members.
    fn inject_workspace_members<'b>(
        root_manifest: &mut Manifest,
        manifests: &'b HashMap<PathBuf, Manifest>,
        workspace_dir: &Path,
    ) -> Result<HashMap<&'b PathBuf, String>> {
        manifests
            .iter()
            .map(|(path, manifest)| {
                let package_name = &manifest
                    .package
                    .as_ref()
                    .expect("Each manifest should have a root package")
                    .name;

                root_manifest
                    .workspace
                    .as_mut()
                    .expect("The root manifest is expected to always have a workspace")
                    .members
                    .push(package_name.clone());

                let manifest_dir = path
                    .parent()
                    .expect("Every manifest should havee a parent directory");

                let dest_package_dir = workspace_dir.join(package_name);

                match symlink_roots(manifest_dir, &dest_package_dir, Some(IGNORE_LIST)) {
                    Ok(_) => Ok((path, package_name.clone())),
                    Err(e) => Err(e),
                }
            })
            .collect()
    }

    fn inject_direct_packages(
        manifest: &mut Manifest,
        direct_packages_manifest: &DirectPackageManifest,
    ) -> Result<()> {
        // Ensure there's a root package to satisfy Cargo requirements
        if manifest.package.is_none() {
            let new_manifest = default_cargo_package_manifest();
            manifest.package = new_manifest.package;
            if manifest.lib.is_none() {
                manifest.lib = new_manifest.lib;
            }
        }

        // Check for any duplicates
        let duplicates: Vec<&String> = manifest
            .dependencies
            .keys()
            .filter(|k| direct_packages_manifest.contains_key(*k))
            .collect();
        if !duplicates.is_empty() {
            bail!(
                "Duplications detected between manifest dependencies and direct dependencies: {:?}",
                duplicates
            )
        }

        // Add the dependencies
        for (name, details) in direct_packages_manifest.iter() {
            manifest.dependencies.insert(
                name.clone(),
                cargo_toml::Dependency::Detailed(details.clone()),
            );
        }

        Ok(())
    }
}

pub struct Splicer {
    workspace_dir: PathBuf,
    manifests: HashMap<PathBuf, Manifest>,
    splicing_manifest: SplicingManifest,
}

impl Splicer {
    pub fn new(workspace_dir: PathBuf, splicing_manifest: SplicingManifest) -> Result<Self> {
        // Load all manifests
        let manifests = splicing_manifest
            .manifests
            .iter()
            .map(|(path, _)| {
                let m = read_manifest(path)
                    .with_context(|| format!("Failed to read manifest at {}", path.display()))?;
                Ok((path.clone(), m))
            })
            .collect::<Result<HashMap<PathBuf, Manifest>>>()?;

        Ok(Self {
            workspace_dir,
            manifests,
            splicing_manifest,
        })
    }

    /// Build a new workspace root
    pub fn splice_workspace(&self, cargo: &Path) -> Result<SplicedManifest> {
        SplicerKind::new(&self.manifests, &self.splicing_manifest, cargo)?
            .splice(&self.workspace_dir)
    }
}

const DEFAULT_SPLICING_PACKAGE_NAME: &str = "direct-cargo-bazel-deps";
const DEFAULT_SPLICING_PACKAGE_VERSION: &str = "0.0.1";

pub fn default_cargo_package_manifest() -> cargo_toml::Manifest {
    // A manifest is generated with a fake workspace member so the [cargo_toml::Manifest::Workspace]
    // member is deseralized and is not `None`.
    cargo_toml::Manifest::from_str(
        &toml::toml! {
            [package]
            name = DEFAULT_SPLICING_PACKAGE_NAME
            version = DEFAULT_SPLICING_PACKAGE_VERSION
            edition = "2018"

            // A fake target used to satisfy requirements of Cargo.
            [lib]
            name = "direct_cargo_bazel_deps"
            path = ".direct_cargo_bazel_deps.rs"
        }
        .to_string(),
    )
    .unwrap()
}

pub fn default_splicing_package_crate_id() -> CrateId {
    CrateId::new(
        DEFAULT_SPLICING_PACKAGE_NAME.to_string(),
        DEFAULT_SPLICING_PACKAGE_VERSION.to_string(),
    )
}

pub fn default_cargo_workspace_manifest(
    resolver_version: &cargo_toml::Resolver,
) -> cargo_toml::Manifest {
    // A manifest is generated with a fake workspace member so the [cargo_toml::Manifest::Workspace]
    // member is deseralized and is not `None`.
    let mut manifest = cargo_toml::Manifest::from_str(&textwrap::dedent(&format!(
        r#"
            [workspace]
            resolver = "{}"
        "#,
        resolver_version,
    )))
    .unwrap();

    // Drop the temp workspace member
    manifest.workspace.as_mut().unwrap().members.pop();

    manifest
}

/// Determine whtether or not the manifest is a workspace root
pub fn is_workspace_root(manifest: &Manifest) -> bool {
    // Anything with any workspace data is considered a workspace
    manifest.workspace.is_some()
}

/// Evaluates whether or not a manifest is considered a "workspace" manifest.
/// See [Cargo workspaces](https://doc.rust-lang.org/cargo/reference/workspaces.html).
pub fn is_workspace_owned(manifest: &Manifest) -> bool {
    if is_workspace_root(manifest) {
        return true;
    }

    // Additionally, anything that contains path dependencies is also considered a workspace
    manifest.dependencies.iter().any(|(_, dep)| match dep {
        Dependency::Detailed(dep) => dep.path.is_some(),
        _ => false,
    })
}

/// Determines whether or not a particular manifest is a workspace member to a given root manifest
pub fn is_workspace_member(
    root_manifest: &Manifest,
    root_manifest_path: &Path,
    manifest_path: &Path,
) -> bool {
    let members = match root_manifest.workspace.as_ref() {
        Some(workspace) => &workspace.members,
        None => return false,
    };

    let root_parent = root_manifest_path
        .parent()
        .expect("All manifest paths should have a parent");
    let manifest_abs_path = root_parent.join(manifest_path);

    members.iter().any(|member| {
        let member_manifest_path = root_parent.join(member).join("Cargo.toml");
        member_manifest_path == manifest_abs_path
    })
}

pub fn write_root_manifest(path: &Path, manifest: cargo_toml::Manifest) -> Result<()> {
    // Remove the file in case one exists already, preventing symlinked files
    // from having their contents overwritten.
    if path.exists() {
        fs::remove_file(path)?;
    }

    // Ensure the directory exists
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }

    // TODO(https://gitlab.com/crates.rs/cargo_toml/-/issues/3)
    let value = toml::Value::try_from(&manifest)?;
    fs::write(path, toml::to_string(&value)?)
        .context(format!("Failed to write manifest to {}", path.display()))
}

/// Create a symlink file on unix systems
#[cfg(target_family = "unix")]
fn symlink(src: &Path, dest: &Path) -> Result<(), std::io::Error> {
    std::os::unix::fs::symlink(src, dest)
}

/// Create a symlink file on windows systems
#[cfg(target_family = "windows")]
fn symlink(src: &Path, dest: &Path) -> Result<(), std::io::Error> {
    if src.is_dir() {
        std::os::windows::fs::symlink_dir(src, dest)
    } else {
        std::os::windows::fs::symlink_file(src, dest)
    }
}

/// Create a symlink file on unix systems
#[cfg(target_family = "unix")]
fn remove_symlink(path: &Path) -> Result<(), std::io::Error> {
    fs::remove_file(path)
}

/// Create a symlink file on windows systems
#[cfg(target_family = "windows")]
fn remove_symlink(path: &Path) -> Result<(), std::io::Error> {
    if path.is_dir() {
        fs::remove_dir(path)
    } else {
        fs::remove_file(path)
    }
}

/// Symlinks the root contents of a source directory into a destination directory
pub fn symlink_roots(source: &Path, dest: &Path, ignore_list: Option<&[&str]>) -> Result<()> {
    // Ensure the source exists and is a directory
    if !source.is_dir() {
        bail!("Source path is not a directory: {}", source.display());
    }

    // Only check if the dest is a directory if it already exists
    if dest.exists() && !dest.is_dir() {
        bail!("Dest path is not a directory: {}", dest.display());
    }

    fs::create_dir_all(dest)?;

    // Link each directory entry from the source dir to the dest
    for entry in (source.read_dir()?).flatten() {
        let basename = entry.file_name();

        // Ignore certain directories that may lead to confusion
        if let Some(base_str) = basename.to_str() {
            if let Some(list) = ignore_list {
                for item in list.iter() {
                    // Handle optional glob patterns here. This allows us to ignore `bazel-*` patterns.
                    if item.ends_with('*') && base_str.starts_with(item.trim_end_matches('*')) {
                        continue;
                    }

                    // Finally, simply compare the string
                    if *item == base_str {
                        continue;
                    }
                }
            }
        }

        let link_src = source.join(&basename);
        let link_dest = dest.join(&basename);
        symlink(&link_src, &link_dest).context(format!(
            "Failed to create symlink: {} -> {}",
            link_src.display(),
            link_dest.display()
        ))?;
    }

    Ok(())
}

#[cfg(test)]
mod test {
    use super::*;

    use std::fs;
    use std::fs::File;
    use std::str::FromStr;

    use cargo_metadata::{MetadataCommand, PackageId};
    use maplit::btreeset;

    use crate::utils::starlark::Label;

    /// Clone and compare two items after calling `.sort()` on them.
    macro_rules! assert_sort_eq {
        ($left:expr, $right:expr $(,)?) => {
            let mut left = $left.clone();
            left.sort();
            let mut right = $right.clone();
            right.sort();
            assert_eq!(left, right);
        };
    }

    /// Get cargo and rustc binaries the Bazel way
    #[cfg(not(feature = "cargo"))]
    fn get_cargo_and_rustc_paths() -> (PathBuf, PathBuf) {
        let runfiles = runfiles::Runfiles::create().unwrap();
        let cargo_path = runfiles.rlocation(concat!("rules_rust/", env!("CARGO")));
        let rustc_path = runfiles.rlocation(concat!("rules_rust/", env!("RUSTC")));

        (cargo_path, rustc_path)
    }

    /// Get cargo and rustc binaries the Cargo way
    #[cfg(feature = "cargo")]
    fn get_cargo_and_rustc_paths() -> (PathBuf, PathBuf) {
        (PathBuf::from("cargo"), PathBuf::from("rustc"))
    }

    fn cargo() -> PathBuf {
        get_cargo_and_rustc_paths().0
    }

    fn generate_metadata(manifest_path: &Path) -> cargo_metadata::Metadata {
        let manifest_dir = manifest_path.parent().unwrap_or_else(|| {
            panic!(
                "The given manifest has no parent directory: {}",
                manifest_path.display()
            )
        });

        let (cargo_path, rustc_path) = get_cargo_and_rustc_paths();

        let output = MetadataCommand::new()
            .cargo_path(cargo_path)
            // Cargo detects config files based on `pwd` when running so
            // to ensure user provided Cargo config files are used, it's
            // critical to set the working directory to the manifest dir.
            .current_dir(manifest_dir)
            .manifest_path(manifest_path)
            .other_options(["--offline".to_owned()])
            .cargo_command()
            .env("RUSTC", rustc_path)
            .output()
            .unwrap();

        if !output.status.success() {
            eprintln!("{}", String::from_utf8_lossy(&output.stderr));
            assert!(output.status.success());
        }

        let stdout = String::from_utf8(output.stdout).unwrap();

        assert!(stdout
            .lines()
            .find(|line| line.starts_with('{'))
            .ok_or(cargo_metadata::Error::NoJson)
            .is_ok());

        MetadataCommand::parse(stdout).unwrap()
    }

    fn mock_cargo_toml(path: &Path, name: &str) -> cargo_toml::Manifest {
        mock_cargo_toml_with_dependencies(path, name, &[])
    }

    fn mock_cargo_toml_with_dependencies(
        path: &Path,
        name: &str,
        deps: &[&str],
    ) -> cargo_toml::Manifest {
        let manifest = cargo_toml::Manifest::from_str(&textwrap::dedent(&format!(
            r#"
            [package]
            name = "{name}"
            version = "0.0.1"

            [lib]
            path = "lib.rs"

            [dependencies]
            {dependencies}
            "#,
            name = name,
            dependencies = deps.join("\n")
        )))
        .unwrap();

        fs::create_dir_all(path.parent().unwrap()).unwrap();
        fs::write(path, toml::to_string(&manifest).unwrap()).unwrap();

        manifest
    }

    fn mock_workspace_metadata(
        include_extra_member: bool,
        workspace_prefix: Option<&str>,
    ) -> serde_json::Value {
        let mut obj = if include_extra_member {
            serde_json::json!({
                "cargo-bazel": {
                    "package_prefixes": {},
                    "sources": {
                        "extra_pkg 0.0.1": {
                            "sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
                            "url": "https://crates.io/"
                        }
                    }
                }
            })
        } else {
            serde_json::json!({
                "cargo-bazel": {
                    "package_prefixes": {},
                    "sources": {}
                }
            })
        };
        if let Some(workspace_prefix) = workspace_prefix {
            obj.as_object_mut().unwrap()["cargo-bazel"]
                .as_object_mut()
                .unwrap()
                .insert("workspace_prefix".to_owned(), workspace_prefix.into());
        }
        obj
    }

    fn mock_splicing_manifest_with_workspace() -> (SplicingManifest, tempfile::TempDir) {
        let mut splicing_manifest = SplicingManifest::default();
        let cache_dir = tempfile::tempdir().unwrap();

        // Write workspace members
        for pkg in &["sub_pkg_a", "sub_pkg_b"] {
            let manifest_path = cache_dir
                .as_ref()
                .join("root_pkg")
                .join(pkg)
                .join("Cargo.toml");
            let deps = if pkg == &"sub_pkg_b" {
                vec![r#"sub_pkg_a = { path = "../sub_pkg_a" }"#]
            } else {
                vec![]
            };
            mock_cargo_toml_with_dependencies(&manifest_path, pkg, &deps);

            splicing_manifest.manifests.insert(
                manifest_path,
                Label::from_str(&format!("//{}:Cargo.toml", pkg)).unwrap(),
            );
        }

        // Create the root package with a workspace definition
        let manifest: cargo_toml::Manifest = toml::toml! {
            [workspace]
            members = [
                "sub_pkg_a",
                "sub_pkg_b",
            ]
            [package]
            name = "root_pkg"
            version = "0.0.1"

            [lib]
            path = "lib.rs"
        }
        .try_into()
        .unwrap();

        let workspace_root = cache_dir.as_ref();
        {
            File::create(workspace_root.join("WORKSPACE.bazel")).unwrap();
        }
        let root_pkg = workspace_root.join("root_pkg");
        let manifest_path = root_pkg.join("Cargo.toml");
        fs::create_dir_all(&manifest_path.parent().unwrap()).unwrap();
        fs::write(&manifest_path, toml::to_string(&manifest).unwrap()).unwrap();
        {
            File::create(root_pkg.join("BUILD.bazel")).unwrap();
        }

        let sub_pkg_a = root_pkg.join("sub_pkg_a");
        let sub_pkg_b = root_pkg.join("sub_pkg_b");
        {
            fs::create_dir_all(&sub_pkg_a).unwrap();
            File::create(sub_pkg_a.join("BUILD.bazel")).unwrap();

            fs::create_dir_all(&sub_pkg_b).unwrap();
            File::create(sub_pkg_b.join("BUILD.bazel")).unwrap();
        }

        splicing_manifest.manifests.insert(
            manifest_path,
            Label::from_str("//root_pkg:Cargo.toml").unwrap(),
        );

        (splicing_manifest, cache_dir)
    }

    fn mock_splicing_manifest_with_workspace_in_root() -> (SplicingManifest, tempfile::TempDir) {
        let mut splicing_manifest = SplicingManifest::default();
        let cache_dir = tempfile::tempdir().unwrap();

        // Write workspace members
        for pkg in &["sub_pkg_a", "sub_pkg_b"] {
            let manifest_path = cache_dir.as_ref().join(pkg).join("Cargo.toml");
            mock_cargo_toml(&manifest_path, pkg);

            splicing_manifest.manifests.insert(
                manifest_path,
                Label::from_str(&format!("//{}:Cargo.toml", pkg)).unwrap(),
            );
        }

        // Create the root package with a workspace definition
        let manifest: cargo_toml::Manifest = toml::toml! {
            [workspace]
            members = [
                "sub_pkg_a",
                "sub_pkg_b",
            ]
            [package]
            name = "root_pkg"
            version = "0.0.1"

            [lib]
            path = "lib.rs"
        }
        .try_into()
        .unwrap();

        let workspace_root = cache_dir.as_ref();
        {
            File::create(workspace_root.join("WORKSPACE.bazel")).unwrap();
        }
        let manifest_path = workspace_root.join("Cargo.toml");
        fs::create_dir_all(&manifest_path.parent().unwrap()).unwrap();
        fs::write(&manifest_path, toml::to_string(&manifest).unwrap()).unwrap();

        let sub_pkg_a = workspace_root.join("sub_pkg_a");
        let sub_pkg_b = workspace_root.join("sub_pkg_b");
        {
            fs::create_dir_all(&sub_pkg_a).unwrap();
            File::create(sub_pkg_a.join("BUILD.bazel")).unwrap();

            fs::create_dir_all(&sub_pkg_b).unwrap();
            File::create(sub_pkg_b.join("BUILD.bazel")).unwrap();
        }

        splicing_manifest
            .manifests
            .insert(manifest_path, Label::from_str("//:Cargo.toml").unwrap());

        (splicing_manifest, cache_dir)
    }

    fn mock_splicing_manifest_with_package() -> (SplicingManifest, tempfile::TempDir) {
        let mut splicing_manifest = SplicingManifest::default();
        let cache_dir = tempfile::tempdir().unwrap();

        // Add an additional package
        let manifest_path = cache_dir.as_ref().join("root_pkg").join("Cargo.toml");
        mock_cargo_toml(&manifest_path, "root_pkg");
        splicing_manifest
            .manifests
            .insert(manifest_path, Label::from_str("//:Cargo.toml").unwrap());

        (splicing_manifest, cache_dir)
    }

    fn mock_splicing_manifest_with_multi_package() -> (SplicingManifest, tempfile::TempDir) {
        let mut splicing_manifest = SplicingManifest::default();
        let cache_dir = tempfile::tempdir().unwrap();

        // Add an additional package
        for pkg in &["pkg_a", "pkg_b", "pkg_c"] {
            let manifest_path = cache_dir.as_ref().join(pkg).join("Cargo.toml");
            mock_cargo_toml(&manifest_path, pkg);
            splicing_manifest
                .manifests
                .insert(manifest_path, Label::from_str("//:Cargo.toml").unwrap());
        }

        (splicing_manifest, cache_dir)
    }

    fn new_package_id(name: &str, workspace_root: &Path, is_root: bool) -> PackageId {
        let mut workspace_root = workspace_root.display().to_string();

        // On windows, make sure we normalize the path to match what Cargo would
        // otherwise use to populate metadata.
        if cfg!(target_os = "windows") {
            workspace_root = format!("/{}", workspace_root.replace('\\', "/"))
        };

        if is_root {
            PackageId {
                repr: format!("{} 0.0.1 (path+file://{})", name, workspace_root),
            }
        } else {
            PackageId {
                repr: format!("{} 0.0.1 (path+file://{}/{})", name, workspace_root, name,),
            }
        }
    }

    #[test]
    fn splice_workspace() {
        let (splicing_manifest, _cache_dir) = mock_splicing_manifest_with_workspace_in_root();

        // Splice the workspace
        let workspace_root = tempfile::tempdir().unwrap();
        let workspace_manifest =
            Splicer::new(workspace_root.as_ref().to_path_buf(), splicing_manifest)
                .unwrap()
                .splice_workspace(&cargo())
                .unwrap();

        // Ensure metadata is valid
        let metadata = generate_metadata(workspace_manifest.as_path_buf());
        assert_sort_eq!(
            metadata.workspace_members,
            vec![
                new_package_id("sub_pkg_a", workspace_root.as_ref(), false),
                new_package_id("sub_pkg_b", workspace_root.as_ref(), false),
                new_package_id("root_pkg", workspace_root.as_ref(), true),
            ]
        );

        // Ensure the workspace metadata annotations are populated
        assert_eq!(
            metadata.workspace_metadata,
            mock_workspace_metadata(false, None)
        );

        // Ensure lockfile was successfully spliced
        cargo_lock::Lockfile::load(workspace_root.as_ref().join("Cargo.lock")).unwrap();
    }

    #[test]
    fn splice_workspace_in_root() {
        let (splicing_manifest, _cache_dir) = mock_splicing_manifest_with_workspace_in_root();

        // Splice the workspace
        let workspace_root = tempfile::tempdir().unwrap();
        let workspace_manifest =
            Splicer::new(workspace_root.as_ref().to_path_buf(), splicing_manifest)
                .unwrap()
                .splice_workspace(&cargo())
                .unwrap();

        // Ensure metadata is valid
        let metadata = generate_metadata(workspace_manifest.as_path_buf());
        assert_sort_eq!(
            metadata.workspace_members,
            vec![
                new_package_id("sub_pkg_a", workspace_root.as_ref(), false),
                new_package_id("sub_pkg_b", workspace_root.as_ref(), false),
                new_package_id("root_pkg", workspace_root.as_ref(), true),
            ]
        );

        // Ensure the workspace metadata annotations are populated
        assert_eq!(
            metadata.workspace_metadata,
            mock_workspace_metadata(false, None)
        );

        // Ensure lockfile was successfully spliced
        cargo_lock::Lockfile::load(workspace_root.as_ref().join("Cargo.lock")).unwrap();
    }

    #[test]
    fn splice_workspace_report_missing_members() {
        let (mut splicing_manifest, _cache_dir) = mock_splicing_manifest_with_workspace();

        // Remove everything but the root manifest
        splicing_manifest
            .manifests
            .retain(|_, label| *label == Label::from_str("//root_pkg:Cargo.toml").unwrap());
        assert_eq!(splicing_manifest.manifests.len(), 1);

        // Splice the workspace
        let workspace_root = tempfile::tempdir().unwrap();
        let workspace_manifest =
            Splicer::new(workspace_root.as_ref().to_path_buf(), splicing_manifest)
                .unwrap()
                .splice_workspace(&cargo());

        assert!(workspace_manifest.is_err());

        // Ensure both the missing manifests are mentioned in the error string
        let err_str = format!("{:?}", &workspace_manifest);
        assert!(
            err_str.contains("Some manifests are not being tracked")
                && err_str.contains("//root_pkg/sub_pkg_a:Cargo.toml")
                && err_str.contains("//root_pkg/sub_pkg_b:Cargo.toml")
        );
    }

    #[test]
    fn splice_workspace_report_missing_root() {
        let (mut splicing_manifest, _cache_dir) = mock_splicing_manifest_with_workspace();

        // Remove everything but the root manifest
        splicing_manifest
            .manifests
            .retain(|_, label| *label != Label::from_str("//root_pkg:Cargo.toml").unwrap());
        assert_eq!(splicing_manifest.manifests.len(), 2);

        // Splice the workspace
        let workspace_root = tempfile::tempdir().unwrap();
        let workspace_manifest =
            Splicer::new(workspace_root.as_ref().to_path_buf(), splicing_manifest)
                .unwrap()
                .splice_workspace(&cargo());

        assert!(workspace_manifest.is_err());

        // Ensure both the missing manifests are mentioned in the error string
        let err_str = format!("{:?}", &workspace_manifest);
        assert!(
            err_str.contains("Missing root workspace manifest")
                && err_str.contains("//root_pkg:Cargo.toml")
        );
    }

    #[test]
    fn splice_workspace_report_external_workspace_members() {
        let (mut splicing_manifest, _cache_dir) = mock_splicing_manifest_with_workspace();

        // Add a new package from an existing external workspace
        let external_workspace_root = tempfile::tempdir().unwrap();
        let external_manifest = external_workspace_root
            .as_ref()
            .join("external_workspace_member")
            .join("Cargo.toml");
        fs::create_dir_all(external_manifest.parent().unwrap()).unwrap();
        fs::write(
            &external_manifest,
            &textwrap::dedent(
                r#"
                [package]
                name = "external_workspace_member"
                version = "0.0.1"

                [lib]
                path = "lib.rs"

                [dependencies]
                neighbor = { path = "../neighbor" }
                "#,
            ),
        )
        .unwrap();

        splicing_manifest.manifests.insert(
            external_manifest.clone(),
            Label::from_str("@remote_dep//external_workspace_member:Cargo.toml").unwrap(),
        );

        // Splice the workspace
        let workspace_root = tempfile::tempdir().unwrap();
        let workspace_manifest =
            Splicer::new(workspace_root.as_ref().to_path_buf(), splicing_manifest)
                .unwrap()
                .splice_workspace(&cargo());

        assert!(workspace_manifest.is_err());

        // Ensure both the external workspace member
        let err_str = format!("{:?}", &workspace_manifest);
        let bytes_str = format!("{:?}", external_manifest.to_string_lossy());
        assert!(
            err_str
                .contains("A package was provided that appears to be a part of another workspace.")
                && err_str.contains(&bytes_str)
        );
    }

    #[test]
    fn splice_package() {
        let (splicing_manifest, _cache_dir) = mock_splicing_manifest_with_package();

        // Splice the workspace
        let workspace_root = tempfile::tempdir().unwrap();
        let workspace_manifest =
            Splicer::new(workspace_root.as_ref().to_path_buf(), splicing_manifest)
                .unwrap()
                .splice_workspace(&cargo())
                .unwrap();

        // Ensure metadata is valid
        let metadata = generate_metadata(workspace_manifest.as_path_buf());
        assert_sort_eq!(
            metadata.workspace_members,
            vec![new_package_id("root_pkg", workspace_root.as_ref(), true)]
        );

        // Ensure the workspace metadata annotations are not populated
        assert_eq!(
            metadata.workspace_metadata,
            mock_workspace_metadata(false, None)
        );

        // Ensure lockfile was successfully spliced
        cargo_lock::Lockfile::load(workspace_root.as_ref().join("Cargo.lock")).unwrap();
    }

    #[test]
    fn splice_multi_package() {
        let (splicing_manifest, _cache_dir) = mock_splicing_manifest_with_multi_package();

        // Splice the workspace
        let workspace_root = tempfile::tempdir().unwrap();
        let workspace_manifest =
            Splicer::new(workspace_root.as_ref().to_path_buf(), splicing_manifest)
                .unwrap()
                .splice_workspace(&cargo())
                .unwrap();

        // Check the default resolver version
        let cargo_manifest = cargo_toml::Manifest::from_str(
            &fs::read_to_string(workspace_manifest.as_path_buf()).unwrap(),
        )
        .unwrap();
        assert!(cargo_manifest.workspace.is_some());
        assert_eq!(
            cargo_manifest.workspace.unwrap().resolver,
            Some(cargo_toml::Resolver::V1)
        );

        // Ensure metadata is valid
        let metadata = generate_metadata(workspace_manifest.as_path_buf());
        assert_sort_eq!(
            metadata.workspace_members,
            vec![
                new_package_id("pkg_a", workspace_root.as_ref(), false),
                new_package_id("pkg_b", workspace_root.as_ref(), false),
                new_package_id("pkg_c", workspace_root.as_ref(), false),
                // Multi package renderings always add a root package
                new_package_id("direct-cargo-bazel-deps", workspace_root.as_ref(), true),
            ]
        );

        // Ensure the workspace metadata annotations are populated
        assert_eq!(
            metadata.workspace_metadata,
            mock_workspace_metadata(false, None)
        );

        // Ensure lockfile was successfully spliced
        cargo_lock::Lockfile::load(workspace_root.as_ref().join("Cargo.lock")).unwrap();
    }

    #[test]
    fn splice_multi_package_with_resolver() {
        let (mut splicing_manifest, _cache_dir) = mock_splicing_manifest_with_multi_package();

        // Update the resolver version
        splicing_manifest.resolver_version = cargo_toml::Resolver::V2;

        // Splice the workspace
        let workspace_root = tempfile::tempdir().unwrap();
        let workspace_manifest =
            Splicer::new(workspace_root.as_ref().to_path_buf(), splicing_manifest)
                .unwrap()
                .splice_workspace(&cargo())
                .unwrap();

        // Check the specified resolver version
        let cargo_manifest = cargo_toml::Manifest::from_str(
            &fs::read_to_string(workspace_manifest.as_path_buf()).unwrap(),
        )
        .unwrap();
        assert!(cargo_manifest.workspace.is_some());
        assert_eq!(
            cargo_manifest.workspace.unwrap().resolver,
            Some(cargo_toml::Resolver::V2)
        );

        // Ensure metadata is valid
        let metadata = generate_metadata(workspace_manifest.as_path_buf());
        assert_sort_eq!(
            metadata.workspace_members,
            vec![
                new_package_id("pkg_a", workspace_root.as_ref(), false),
                new_package_id("pkg_b", workspace_root.as_ref(), false),
                new_package_id("pkg_c", workspace_root.as_ref(), false),
                // Multi package renderings always add a root package
                new_package_id("direct-cargo-bazel-deps", workspace_root.as_ref(), true),
            ]
        );

        // Ensure the workspace metadata annotations are populated
        assert_eq!(
            metadata.workspace_metadata,
            mock_workspace_metadata(false, None)
        );

        // Ensure lockfile was successfully spliced
        cargo_lock::Lockfile::load(workspace_root.as_ref().join("Cargo.lock")).unwrap();
    }

    #[test]
    fn cargo_config_setup() {
        let (mut splicing_manifest, _cache_dir) = mock_splicing_manifest_with_workspace_in_root();

        // Write a cargo config
        let temp_dir = tempfile::tempdir().unwrap();
        let external_config = temp_dir.as_ref().join("config.toml");
        fs::write(&external_config, "# Cargo configuration file").unwrap();
        splicing_manifest.cargo_config = Some(external_config);

        // Splice the workspace
        let workspace_root = tempfile::tempdir().unwrap();
        Splicer::new(workspace_root.as_ref().to_path_buf(), splicing_manifest)
            .unwrap()
            .splice_workspace(&cargo())
            .unwrap();

        let cargo_config = workspace_root.as_ref().join(".cargo").join("config.toml");
        assert!(cargo_config.exists());
        assert_eq!(
            fs::read_to_string(cargo_config).unwrap().trim(),
            "# Cargo configuration file"
        );
    }

    #[test]
    fn unregistered_cargo_config_replaced() {
        let (mut splicing_manifest, cache_dir) = mock_splicing_manifest_with_workspace_in_root();

        // Generate a cargo config that is not tracked by the splicing manifest
        fs::create_dir_all(cache_dir.as_ref().join(".cargo")).unwrap();
        fs::write(
            cache_dir.as_ref().join(".cargo").join("config.toml"),
            "# Untracked Cargo configuration file",
        )
        .unwrap();

        // Write a cargo config
        let temp_dir = tempfile::tempdir().unwrap();
        let external_config = temp_dir.as_ref().join("config.toml");
        fs::write(&external_config, "# Cargo configuration file").unwrap();
        splicing_manifest.cargo_config = Some(external_config);

        // Splice the workspace
        let workspace_root = tempfile::tempdir().unwrap();
        Splicer::new(workspace_root.as_ref().to_path_buf(), splicing_manifest)
            .unwrap()
            .splice_workspace(&cargo())
            .unwrap();

        let cargo_config = workspace_root.as_ref().join(".cargo").join("config.toml");
        assert!(cargo_config.exists());
        assert_eq!(
            fs::read_to_string(cargo_config).unwrap().trim(),
            "# Cargo configuration file"
        );
    }

    #[test]
    fn error_on_cargo_config_in_parent() {
        let (mut splicing_manifest, _cache_dir) = mock_splicing_manifest_with_workspace_in_root();

        // Write a cargo config
        let temp_dir = tempfile::tempdir().unwrap();
        let dot_cargo_dir = temp_dir.as_ref().join(".cargo");
        fs::create_dir_all(&dot_cargo_dir).unwrap();
        let external_config = dot_cargo_dir.join("config.toml");
        fs::write(&external_config, "# Cargo configuration file").unwrap();
        splicing_manifest.cargo_config = Some(external_config.clone());

        // Splice the workspace
        let workspace_root = temp_dir.as_ref().join("workspace_root");
        let splicing_result = Splicer::new(workspace_root.clone(), splicing_manifest)
            .unwrap()
            .splice_workspace(&cargo());

        // Ensure cargo config files in parent directories lead to errors
        assert!(splicing_result.is_err());
        let err_str = splicing_result.err().unwrap().to_string();
        assert!(err_str.starts_with("A Cargo config file was found in a parent directory"));
        assert!(err_str.contains(&format!("Workspace = {}", workspace_root.display())));
        assert!(err_str.contains(&format!("Cargo config = {}", external_config.display())));
    }

    #[test]
    fn find_missing_manifests_correct_without_root() {
        let temp_dir = tempfile::tempdir().unwrap();
        let root_manifest_dir = temp_dir.path();
        touch(&root_manifest_dir.join("WORKSPACE.bazel"));
        touch(&root_manifest_dir.join("BUILD.bazel"));
        touch(&root_manifest_dir.join("Cargo.toml"));
        touch(&root_manifest_dir.join("foo").join("Cargo.toml"));
        touch(&root_manifest_dir.join("bar").join("BUILD.bazel"));
        touch(&root_manifest_dir.join("bar").join("Cargo.toml"));

        let known_manifest_paths = btreeset![
            root_manifest_dir
                .join("foo")
                .join("Cargo.toml")
                .normalize()
                .unwrap(),
            root_manifest_dir
                .join("bar")
                .join("Cargo.toml")
                .normalize()
                .unwrap(),
        ];

        let root_manifest: cargo_toml::Manifest = toml::toml! {
            [workspace]
            members = [
                "foo",
                "bar",
            ]
            [package]
            name = "root_pkg"
            version = "0.0.1"

            [lib]
            path = "lib.rs"
        }
        .try_into()
        .unwrap();
        let missing_manifests = SplicerKind::find_missing_manifests(
            &root_manifest,
            root_manifest_dir,
            &known_manifest_paths,
        )
        .unwrap();
        assert_eq!(missing_manifests, btreeset![]);
    }

    #[test]
    fn find_missing_manifests_correct_with_root() {
        let temp_dir = tempfile::tempdir().unwrap();
        let root_manifest_dir = temp_dir.path();
        touch(&root_manifest_dir.join("WORKSPACE.bazel"));
        touch(&root_manifest_dir.join("BUILD.bazel"));
        touch(&root_manifest_dir.join("Cargo.toml"));
        touch(&root_manifest_dir.join("foo").join("Cargo.toml"));
        touch(&root_manifest_dir.join("bar").join("BUILD.bazel"));
        touch(&root_manifest_dir.join("bar").join("Cargo.toml"));

        let known_manifest_paths = btreeset![
            root_manifest_dir.join("Cargo.toml").normalize().unwrap(),
            root_manifest_dir
                .join("foo")
                .join("Cargo.toml")
                .normalize()
                .unwrap(),
            root_manifest_dir
                .join("bar")
                .join("Cargo.toml")
                .normalize()
                .unwrap(),
        ];

        let root_manifest: cargo_toml::Manifest = toml::toml! {
            [workspace]
            members = [
                ".",
                "foo",
                "bar",
            ]
            [package]
            name = "root_pkg"
            version = "0.0.1"

            [lib]
            path = "lib.rs"
        }
        .try_into()
        .unwrap();
        let missing_manifests = SplicerKind::find_missing_manifests(
            &root_manifest,
            root_manifest_dir,
            &known_manifest_paths,
        )
        .unwrap();
        assert_eq!(missing_manifests, btreeset![]);
    }

    #[test]
    fn find_missing_manifests_missing_root() {
        let temp_dir = tempfile::tempdir().unwrap();
        let root_manifest_dir = temp_dir.path();
        touch(&root_manifest_dir.join("WORKSPACE.bazel"));
        touch(&root_manifest_dir.join("BUILD.bazel"));
        touch(&root_manifest_dir.join("Cargo.toml"));
        touch(&root_manifest_dir.join("foo").join("Cargo.toml"));
        touch(&root_manifest_dir.join("bar").join("BUILD.bazel"));
        touch(&root_manifest_dir.join("bar").join("Cargo.toml"));

        let known_manifest_paths = btreeset![
            root_manifest_dir
                .join("foo")
                .join("Cargo.toml")
                .normalize()
                .unwrap(),
            root_manifest_dir
                .join("bar")
                .join("Cargo.toml")
                .normalize()
                .unwrap(),
        ];

        let root_manifest: cargo_toml::Manifest = toml::toml! {
            [workspace]
            members = [
                ".",
                "foo",
                "bar",
            ]
            [package]
            name = "root_pkg"
            version = "0.0.1"

            [lib]
            path = "lib.rs"
        }
        .try_into()
        .unwrap();
        let missing_manifests = SplicerKind::find_missing_manifests(
            &root_manifest,
            root_manifest_dir,
            &known_manifest_paths,
        )
        .unwrap();
        assert_eq!(missing_manifests, btreeset![String::from("//:Cargo.toml")]);
    }

    #[test]
    fn find_missing_manifests_missing_nonroot() {
        let temp_dir = tempfile::tempdir().unwrap();
        let root_manifest_dir = temp_dir.path();
        touch(&root_manifest_dir.join("WORKSPACE.bazel"));
        touch(&root_manifest_dir.join("BUILD.bazel"));
        touch(&root_manifest_dir.join("Cargo.toml"));
        touch(&root_manifest_dir.join("foo").join("Cargo.toml"));
        touch(&root_manifest_dir.join("bar").join("BUILD.bazel"));
        touch(&root_manifest_dir.join("bar").join("Cargo.toml"));
        touch(&root_manifest_dir.join("baz").join("BUILD.bazel"));
        touch(&root_manifest_dir.join("baz").join("Cargo.toml"));

        let known_manifest_paths = btreeset![
            root_manifest_dir
                .join("foo")
                .join("Cargo.toml")
                .normalize()
                .unwrap(),
            root_manifest_dir
                .join("bar")
                .join("Cargo.toml")
                .normalize()
                .unwrap(),
        ];

        let root_manifest: cargo_toml::Manifest = toml::toml! {
            [workspace]
            members = [
                "foo",
                "bar",
                "baz",
            ]
            [package]
            name = "root_pkg"
            version = "0.0.1"

            [lib]
            path = "lib.rs"
        }
        .try_into()
        .unwrap();
        let missing_manifests = SplicerKind::find_missing_manifests(
            &root_manifest,
            root_manifest_dir,
            &known_manifest_paths,
        )
        .unwrap();
        assert_eq!(
            missing_manifests,
            btreeset![String::from("//baz:Cargo.toml")]
        );
    }

    fn touch(path: &Path) {
        std::fs::create_dir_all(path.parent().unwrap()).unwrap();
        std::fs::write(path, &[]).unwrap();
    }
}
