//! The cli entrypoint for the `splice` subcommand

use std::path::PathBuf;

use clap::Parser;

use crate::cli::Result;
use crate::metadata::{write_metadata, Generator, MetadataGenerator};
use crate::splicing::{
    generate_lockfile, ExtraManifestsManifest, Splicer, SplicingManifest, WorkspaceMetadata,
};

/// Command line options for the `splice` subcommand
#[derive(Parser, Debug)]
#[clap(about, version)]
pub struct SpliceOptions {
    /// A generated manifest of splicing inputs
    #[clap(long)]
    pub splicing_manifest: PathBuf,

    /// A generated manifest of "extra workspace members"
    #[clap(long)]
    pub extra_manifests_manifest: PathBuf,

    /// A Cargo lockfile (Cargo.lock).
    #[clap(long)]
    pub cargo_lockfile: Option<PathBuf>,

    /// The directory in which to build the workspace. A `Cargo.toml` file
    /// should always be produced within this directory.
    #[clap(long)]
    pub workspace_dir: PathBuf,

    /// If true, outputs will be printed instead of written to disk.
    #[clap(long)]
    pub dry_run: bool,

    /// The path to a Cargo configuration file.
    #[clap(long)]
    pub cargo_config: Option<PathBuf>,

    /// The path to a Cargo binary to use for gathering metadata
    #[clap(long, env = "CARGO")]
    pub cargo: PathBuf,

    /// The path to a rustc binary for use with Cargo
    #[clap(long, env = "RUSTC")]
    pub rustc: PathBuf,
}

/// Combine a set of disjoint manifests into a single workspace.
pub fn splice(opt: SpliceOptions) -> Result<()> {
    // Load the all config files required for splicing a workspace
    let splicing_manifest = SplicingManifest::try_from_path(&opt.splicing_manifest)?;
    let extra_manifests_manifest =
        ExtraManifestsManifest::try_from_path(opt.extra_manifests_manifest)?;

    // Generate a splicer for creating a Cargo workspace manifest
    let splicer = Splicer::new(
        opt.workspace_dir,
        splicing_manifest,
        extra_manifests_manifest,
    )?;

    // Splice together the manifest
    let manifest_path = splicer.splice_workspace()?;

    // Generate a lockfile
    let cargo_lockfile =
        generate_lockfile(&manifest_path, &opt.cargo_lockfile, &opt.cargo, &opt.rustc)?;

    // Write the registry url info to the manifest now that a lockfile has been generated
    WorkspaceMetadata::write_registry_urls(&cargo_lockfile, &manifest_path)?;

    // Write metadata to the workspace for future reuse
    let (cargo_metadata, _) = Generator::new()
        .with_cargo(opt.cargo)
        .with_rustc(opt.rustc)
        .generate(&manifest_path.as_path_buf())?;

    // Write metadata next to the manifest
    let metadata_path = manifest_path
        .as_path_buf()
        .parent()
        .expect("Newly spliced cargo manifest has no parent directory")
        .join("cargo-bazel-spliced-metadata.json");
    write_metadata(&metadata_path, &cargo_metadata)?;

    Ok(())
}
