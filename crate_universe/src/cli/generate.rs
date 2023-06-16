//! The cli entrypoint for the `generate` subcommand

use std::fs;
use std::path::PathBuf;

use anyhow::{bail, Context as AnyhowContext, Result};
use clap::Parser;

use crate::config::Config;
use crate::context::Context;
use crate::lockfile::{lock_context, write_lockfile};
use crate::metadata::{load_metadata, Annotations, Cargo};
use crate::rendering::{write_outputs, Renderer};
use crate::splicing::SplicingManifest;

/// Command line options for the `generate` subcommand
#[derive(Parser, Debug)]
#[clap(about = "Command line options for the `generate` subcommand", version)]
pub struct GenerateOptions {
    /// The path to a Cargo binary to use for gathering metadata
    #[clap(long, env = "CARGO")]
    pub cargo: Option<PathBuf>,

    /// The path to a rustc binary for use with Cargo
    #[clap(long, env = "RUSTC")]
    pub rustc: Option<PathBuf>,

    /// The config file with information about the Bazel and Cargo workspace
    #[clap(long)]
    pub config: PathBuf,

    /// A generated manifest of splicing inputs
    #[clap(long)]
    pub splicing_manifest: PathBuf,

    /// The path to either a Cargo or Bazel lockfile
    #[clap(long)]
    pub lockfile: Option<PathBuf>,

    /// The path to a [Cargo.lock](https://doc.rust-lang.org/cargo/guide/cargo-toml-vs-cargo-lock.html) file.
    #[clap(long)]
    pub cargo_lockfile: PathBuf,

    /// The directory of the current repository rule
    #[clap(long)]
    pub repository_dir: PathBuf,

    /// A [Cargo config](https://doc.rust-lang.org/cargo/reference/config.html#configuration)
    /// file to use when gathering metadata
    #[clap(long)]
    pub cargo_config: Option<PathBuf>,

    /// Whether or not to ignore the provided lockfile and re-generate one
    #[clap(long)]
    pub repin: bool,

    /// The path to a Cargo metadata `json` file. This file must be next to a `Cargo.toml` and `Cargo.lock` file.
    #[clap(long)]
    pub metadata: Option<PathBuf>,

    /// If true, outputs will be printed instead of written to disk.
    #[clap(long)]
    pub dry_run: bool,
}

pub fn generate(opt: GenerateOptions) -> Result<()> {
    // Load the config
    let config = Config::try_from_path(&opt.config)?;

    // Go straight to rendering if there is no need to repin
    if !opt.repin {
        if let Some(lockfile) = &opt.lockfile {
            let context = Context::try_from_path(lockfile)?;

            // Render build files
            let outputs = Renderer::new(
                config.rendering,
                config.supported_platform_triples,
                config.generate_target_compatible_with,
            )
            .render(&context)?;

            // Write the outputs to disk
            write_outputs(outputs, &opt.repository_dir, opt.dry_run)?;

            return Ok(());
        }
    }

    // Ensure Cargo and Rustc are available for use during generation.
    let cargo_bin = Cargo::new(match opt.cargo {
        Some(bin) => bin,
        None => bail!("The `--cargo` argument is required when generating unpinned content"),
    });
    let rustc_bin = match &opt.rustc {
        Some(bin) => bin,
        None => bail!("The `--rustc` argument is required when generating unpinned content"),
    };

    // Ensure a path to a metadata file was provided
    let metadata_path = match &opt.metadata {
        Some(path) => path,
        None => bail!("The `--metadata` argument is required when generating unpinned content"),
    };

    // Load Metadata and Lockfile
    let (cargo_metadata, cargo_lockfile) = load_metadata(metadata_path)?;

    // Annotate metadata
    let annotations = Annotations::new(cargo_metadata, cargo_lockfile.clone(), config.clone())?;

    // Generate renderable contexts for each package
    let context = Context::new(annotations)?;

    // Render build files
    let outputs = Renderer::new(
        config.rendering.clone(),
        config.supported_platform_triples.clone(),
        config.generate_target_compatible_with,
    )
    .render(&context)?;

    // Write outputs
    write_outputs(outputs, &opt.repository_dir, opt.dry_run)?;

    // Ensure Bazel lockfiles are written to disk so future generations can be short-circuited.
    if let Some(lockfile) = opt.lockfile {
        let splicing_manifest = SplicingManifest::try_from_path(&opt.splicing_manifest)?;

        let lock_content =
            lock_context(context, &config, &splicing_manifest, &cargo_bin, rustc_bin)?;

        write_lockfile(lock_content, &lockfile, opt.dry_run)?;
    }

    // Write the updated Cargo.lock file
    fs::write(&opt.cargo_lockfile, cargo_lockfile.to_string())
        .context("Failed to write Cargo.lock file back to the workspace.")?;

    Ok(())
}
