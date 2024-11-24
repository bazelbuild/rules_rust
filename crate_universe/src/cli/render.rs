use crate::config::RenderConfig;
use crate::context::CrateContext;
use crate::rendering::{Platforms, Renderer};
use crate::utils::target_triple::TargetTriple;

use anyhow::{Context, Result};
use clap::Parser;
use serde::{Deserialize, Serialize};

use std::collections::BTreeSet;
use std::path::PathBuf;

#[derive(Parser, Debug)]
#[clap(about = "Command line options for the `render` subcommand", version)]
pub struct RenderOptions {
    #[clap(long)]
    options_json: String,

    #[clap(long)]
    output_path: PathBuf,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct StructuredRenderOptions {
    config: RenderConfig,

    supported_platform_triples: BTreeSet<TargetTriple>,

    platforms: Platforms,

    crate_context: CrateContext,
}

pub fn render(opt: RenderOptions) -> Result<()> {
    let RenderOptions {
        options_json,
        output_path,
    } = opt;

    let deserialized_options = serde_json::from_str(&options_json)
        .with_context(|| format!("Failed to deserialize options_json from '{}'", options_json))?;

    let StructuredRenderOptions {
        config,
        supported_platform_triples,
        platforms,
        crate_context,
    } = deserialized_options;

    let renderer = Renderer::new(config, supported_platform_triples);
    let output = renderer.render_one_build_file(&platforms, &crate_context)
        .with_context(|| format!("Failed to render BUILD.bazel file for crate {}", crate_context.name))?;
    std::fs::write(&output_path, output.as_bytes())
        .with_context(|| format!("Failed to write BUILD.bazel file to {}", output_path.display()))?;

    Ok(())
}
