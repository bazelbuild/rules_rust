//! The `rustc-cfgs` subcommand: records `rustc --print=cfg` for a set of
//! platforms. See [crate::metadata::rustc_cfgs].

use std::collections::BTreeSet;
use std::fs;
use std::path::PathBuf;

use anyhow::{Context, Result};
use clap::Parser;

use crate::metadata::rustc_cfgs::RustcCfgs;
use crate::utils::target_triple::TargetTriple;

/// Command line options for the `rustc-cfgs` subcommand
#[derive(Parser, Debug)]
#[clap(about = "Record `rustc --print=cfg` for a set of platforms", version)]
pub struct RustcCfgsOptions {
    /// The rustc to record from.
    #[clap(long, env = "RUSTC")]
    pub rustc: PathBuf,

    /// The Bazel platform triples to record, comma separated.
    #[clap(long, value_delimiter = ',')]
    pub triples: Vec<String>,

    /// Where to write the table.
    #[clap(long)]
    pub output: PathBuf,
}

/// Record the cfg table.
pub fn rustc_cfgs(opt: RustcCfgsOptions) -> Result<()> {
    // Several Bazel triples can map onto one Cargo triple.
    let triples: BTreeSet<String> = opt
        .triples
        .into_iter()
        .map(|triple| TargetTriple::from_bazel(triple).to_cargo())
        .collect();
    let table = RustcCfgs::record(&opt.rustc, triples)?;
    let content = serde_json::to_string_pretty(&table).context("Failed to serialize the table")?;
    fs::write(&opt.output, content + "\n")
        .with_context(|| format!("Failed to write {}", opt.output.display()))
}
