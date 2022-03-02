//! The cli entrypoint for the `vendor` subcommand

use std::collections::BTreeSet;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::{self, ExitStatus};

use anyhow::{bail, Context as AnyhowContext, Result};
use clap::Parser;

use crate::config::{Config, VendorMode};
use crate::context::Context;
use crate::metadata::{Annotations, VendorGenerator};
use crate::metadata::{Generator, MetadataGenerator};
use crate::rendering::{render_module_label, write_outputs, Renderer};
use crate::splicing::{
    generate_lockfile, ExtraManifestsManifest, Splicer, SplicingManifest, WorkspaceMetadata,
};

/// Command line options for the `vendor` subcommand
#[derive(Parser, Debug)]
#[clap(about, version)]
pub struct VendorOptions {
    /// The path to a Cargo binary to use for gathering metadata
    #[clap(long, env = "CARGO")]
    pub cargo: PathBuf,

    /// The path to a rustc binary for use with Cargo
    #[clap(long, env = "RUSTC")]
    pub rustc: PathBuf,

    /// The path to a buildifier binary for formatting generated BUILD files
    #[clap(long)]
    pub buildifier: Option<PathBuf>,

    /// The config file with information about the Bazel and Cargo workspace
    #[clap(long)]
    pub config: PathBuf,

    /// A generated manifest of splicing inputs
    #[clap(long)]
    pub splicing_manifest: PathBuf,

    /// The path to a Cargo lockfile
    #[clap(long)]
    pub cargo_lockfile: Option<PathBuf>,

    /// A [Cargo config](https://doc.rust-lang.org/cargo/reference/config.html#configuration)
    /// file to use when gathering metadata
    #[clap(long)]
    pub cargo_config: Option<PathBuf>,

    /// The path to a Cargo metadata `json` file.
    #[clap(long)]
    pub metadata: Option<PathBuf>,

    /// A generated manifest of "extra workspace members"
    #[clap(long)]
    pub extra_manifests_manifest: PathBuf,

    /// The directory in which to build the workspace. A `Cargo.toml` file
    /// should always be produced within this directory.
    #[clap(long, env = "BUILD_WORKSPACE_DIRECTORY")]
    pub workspace_dir: PathBuf,

    /// If true, outputs will be printed instead of written to disk.
    #[clap(long)]
    pub dry_run: bool,
}

/// Run buildifier on a given file.
fn buildifier_format(bin: &Path, file: &Path) -> Result<ExitStatus> {
    let status = process::Command::new(bin)
        .args(["-lint=fix", "-mode=fix", "-warnings=all"])
        .arg(file)
        .status()
        .context("Failed to apply buildifier fixes")?;

    if !status.success() {
        bail!(status)
    }

    Ok(status)
}

pub fn vendor(opt: VendorOptions) -> Result<()> {
    // Load the all config files required for splicing a workspace
    let splicing_manifest =
        SplicingManifest::try_from_path(&opt.splicing_manifest)?.absoulutize(&opt.workspace_dir);
    let extra_manifests_manifest =
        ExtraManifestsManifest::try_from_path(opt.extra_manifests_manifest)?.absoulutize();

    let temp_dir = tempfile::tempdir().context("Failed to create temporary directory")?;

    // Generate a splicer for creating a Cargo workspace manifest
    let splicer = Splicer::new(
        PathBuf::from(temp_dir.as_ref()),
        splicing_manifest,
        extra_manifests_manifest,
    )
    .context("Failed to crate splicer")?;

    // Splice together the manifest
    let manifest_path = splicer
        .splice_workspace()
        .context("Failed to splice workspace")?;

    // Generate a lockfile
    let cargo_lockfile =
        generate_lockfile(&manifest_path, &opt.cargo_lockfile, &opt.cargo, &opt.rustc)?;

    // Write the registry url info to the manifest now that a lockfile has been generated
    WorkspaceMetadata::write_registry_urls(&cargo_lockfile, &manifest_path)?;

    // Write metadata to the workspace for future reuse
    let (cargo_metadata, cargo_lockfile) = Generator::new()
        .with_cargo(opt.cargo.clone())
        .with_rustc(opt.rustc.clone())
        .generate(&manifest_path.as_path_buf())?;

    // Load the config from disk
    let config = Config::try_from_path(&opt.config)?;

    // Annotate metadata
    let annotations = Annotations::new(cargo_metadata, cargo_lockfile, config.clone())?;

    // Generate renderable contexts for earch package
    let context = Context::new(annotations)?;

    // Render build files
    let outputs = Renderer::new(config.rendering.clone()).render(&context)?;

    // Cache the file names for potential use with buildifier
    let file_names: BTreeSet<PathBuf> = outputs.keys().cloned().collect();

    // First ensure vendoring and rendering happen in a clean directory
    let vendor_dir_label = render_module_label(&config.rendering.crates_module_template, "BUILD")?;
    let vendor_dir = opt
        .workspace_dir
        .join(vendor_dir_label.package.unwrap_or_default());
    if vendor_dir.exists() {
        fs::remove_dir_all(&vendor_dir)
            .with_context(|| format!("Failed to delete {}", vendor_dir.display()))?;
    }

    // Vendor the crates from the spliced workspace
    if matches!(config.rendering.vendor_mode, Some(VendorMode::Local)) {
        VendorGenerator::new(opt.cargo.clone(), opt.rustc.clone())
            .generate(manifest_path.as_path_buf(), &vendor_dir)
            .context("Failed to vendor dependencies")?;
    }

    // Write outputs
    write_outputs(outputs, &opt.workspace_dir, opt.dry_run)
        .context("Failed writing output files")?;

    // Optionally apply buildifier fixes
    if let Some(buildifier_bin) = opt.buildifier {
        for file in file_names {
            let file_path = opt.workspace_dir.join(file);
            buildifier_format(&buildifier_bin, &file_path)
                .with_context(|| format!("Failed to run buildifier on {}", file_path.display()))?;
        }
    }

    Ok(())
}
