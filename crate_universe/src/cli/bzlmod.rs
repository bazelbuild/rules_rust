//! The cli entrypoint for the `bzlmod` subcommand.

use std::collections::BTreeMap;
use std::fs;
use std::path::PathBuf;
use std::thread;

use anyhow::{anyhow, Context};
use clap::Parser;
use serde::Deserialize;

/// A collection of various subcommand arguments for performing `cargo-bazel` executions.
#[derive(Debug, Deserialize)]
struct ModuleManifest {
    /// Arguments to the [`crate::cli::Options::Query`] subcommand.
    pub query_opts: Option<crate::cli::query::QueryOptions>,

    /// Arguments to the [`crate::cli::Options::Splice`] subcommand.
    pub splicing_opts: Option<crate::cli::splice::SpliceOptions>,

    /// Arguments to the [`crate::cli::Options::Generate`] subcommand.
    pub generate_opts: crate::cli::generate::GenerateOptions,
}

type ModuleManifests = BTreeMap<String, ModuleManifest>;

/// Command line options for the `bzlmod` subcommand
#[derive(Parser, Debug)]
#[clap(about = "Command line options for the `bzlmod` subcommand", version)]
pub struct BzlmodOptions {
    /// Module manifests used to provide arguments for all phases of `cargo-bazel`.
    #[clap(long)]
    pub module_manifest: PathBuf,

    /// The location in which to write the mapping of module name to their lockfiles.
    #[clap(long)]
    pub output_lockfiles_manifest: PathBuf,
}

/// A Rust re-implementation of `crates_repository`.
fn module_extension(manifest: ModuleManifest) -> anyhow::Result<()> {
    let ModuleManifest {
        query_opts,
        splicing_opts,
        generate_opts,
    } = manifest;

    // Check if generation is allowed.
    if let Some(opts) = query_opts {
        crate::cli::query::query(opts).context("Error in repin detection.")?;
    }

    // Do splicing if needed
    if let Some(opts) = splicing_opts {
        crate::cli::splice(opts).context("Failed splicing")?;
    };

    // Generate Starlark files.
    crate::cli::generate(generate_opts).context("Failed generation")?;

    Ok(())
}

/// Optimize generating crate repositories by parallelizing the efforts of crate_universe in a single call.
pub fn bzlmod(opt: BzlmodOptions) -> anyhow::Result<()> {
    // Load all manifests.
    let module_manifests = {
        let content = fs::read_to_string(&opt.module_manifest).with_context(|| {
            anyhow!(
                "Failed to read opts file: {}",
                opt.module_manifest.display()
            )
        })?;
        let opts: ModuleManifests = serde_json::from_str(&content).with_context(|| {
            anyhow!(
                "Failed to deserialize opts from: {}\n```json\n{}\n```",
                opt.module_manifest.display(),
                content
                    .lines()
                    .enumerate()
                    .map(|(i, l)| format!("{} {}", i + 1, l))
                    .collect::<Vec<_>>()
                    .join("\n"),
            )
        })?;
        opts
    };

    // Collect lockfiles
    let lockfiles = module_manifests.iter().map(|(name, manifest)| {
        let lockfile = manifest.generate_opts.lockfile.as_ref().with_context(|| anyhow!("In bzlmod all modules are expected to be backed by a lockfile. `{}` is missing one.", name))?.clone();
        Ok::<(String, PathBuf), anyhow::Error>((name.clone(), lockfile))
    }).collect::<anyhow::Result<BTreeMap<String, PathBuf>>>()?;

    // Spawn a thread for each module.
    let threads: Vec<thread::JoinHandle<anyhow::Result<()>>> = module_manifests
        .into_iter()
        .map(|(name, manifest)| {
            thread::spawn(move || {
                let span = tracing::span!(tracing::Level::INFO, "module_extension", name = name);
                let _enter = span.enter();

                module_extension(manifest)
                    .with_context(|| anyhow!("Failed to generate crates for {}", name))?;

                Ok(())
            })
        })
        .collect();

    // Wait for all work to be completed.
    for thread in threads {
        thread.join().map_err(|e| anyhow!("{:?}", e))??;
    }

    // Save the lockfiles manifest
    fs::write(
        &opt.output_lockfiles_manifest,
        serde_json::to_string_pretty(&lockfiles)
            .context("Failed to serialize output lockfiles manifest")?,
    )
    .with_context(|| {
        anyhow!(
            "Failed to write output lockfiles manifest: {}",
            opt.output_lockfiles_manifest.display()
        )
    })?;

    Ok(())
}
