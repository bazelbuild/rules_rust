//! The `rustc --print=cfg` output of every supported platform, recorded in
//! `rustc_cfgs.json` next to this file.
//!
//! `cfg(...)` dependencies are evaluated against these values, so the same
//! lockfile comes out whatever rustc is installed and none is needed to check
//! one. `bazel run //crate_universe:rustc_cfgs.install` records the table from
//! the toolchain `rules_rust` registers, and
//! `//crate_universe:rustc_cfgs_diff_test` fails when a toolchain update changes
//! it.

use std::collections::BTreeMap;
use std::path::Path;
use std::process::Command;
use std::sync::OnceLock;

use anyhow::{bail, Context, Result};
use serde::{Deserialize, Serialize};

/// `rustc --print=cfg` per platform.
#[derive(Debug, Default, Serialize, Deserialize)]
pub(crate) struct RustcCfgs {
    /// `rustc --version` of the rustc the table was recorded from.
    pub(crate) rustc: String,

    /// `rustc --print=cfg --target=<triple>` for each Cargo triple, one cfg per
    /// entry, sorted.
    pub(crate) cfgs: BTreeMap<String, Vec<String>>,
}

impl RustcCfgs {
    /// Records the table from `rustc` for the given Cargo triples.
    pub(crate) fn record(rustc: &Path, triples: impl IntoIterator<Item = String>) -> Result<Self> {
        let version = Command::new(rustc)
            .arg("--version")
            .output()
            .with_context(|| format!("Error spawning `{} --version`", rustc.display()))?;
        if !version.status.success() {
            bail!("Failed to query the version of {}", rustc.display());
        }
        let cfgs = triples
            .into_iter()
            .map(|triple| print_cfg(rustc, &triple).map(|cfgs| (triple, cfgs)))
            .collect::<Result<_>>()?;
        Ok(Self {
            rustc: String::from_utf8_lossy(&version.stdout).trim().to_owned(),
            cfgs,
        })
    }

    /// The table recorded in the repository.
    pub(crate) fn recorded() -> &'static RustcCfgs {
        static TABLE: OnceLock<RustcCfgs> = OnceLock::new();
        TABLE.get_or_init(|| {
            serde_json::from_str(include_str!("rustc_cfgs.json"))
                .expect("the recorded rustc cfg table is valid")
        })
    }

    /// The cfg text of a triple as `rustc --print=cfg` prints it, if recorded.
    pub(crate) fn cfg_text(&self, triple: &str) -> Option<String> {
        self.cfgs.get(triple).map(|cfgs| cfgs.join("\n"))
    }
}

/// Runs `rustc --print=cfg --target={triple}` and returns its lines, sorted.
pub(crate) fn print_cfg(rustc: &Path, triple: &str) -> Result<Vec<String>> {
    let output = Command::new(rustc)
        .arg("--print=cfg")
        .arg(format!("--target={triple}"))
        .output()
        .with_context(|| {
            format!(
                "Error spawning `{} --print=cfg --target={}`",
                rustc.display(),
                triple
            )
        })?;

    if !output.status.success() {
        tracing::error!("{}", String::from_utf8_lossy(&output.stderr));
        bail!(
            "Failed to query rustc for the cfg values of the target triple '{}': {}",
            triple,
            output.status
        );
    }

    let text = String::from_utf8(output.stdout)
        .with_context(|| format!("`rustc --print=cfg --target={triple}` emitted invalid UTF-8"))?;
    let mut cfgs: Vec<String> = text
        .lines()
        .map(str::trim)
        .filter(|line| !line.is_empty())
        .map(str::to_owned)
        .collect();
    cfgs.sort();
    cfgs.dedup();
    Ok(cfgs)
}

#[cfg(test)]
mod test {
    use super::*;

    #[test]
    fn recorded_table_parses_and_joins_lines() {
        let table = RustcCfgs::recorded();
        for (triple, cfgs) in &table.cfgs {
            assert!(
                cfgs.windows(2).all(|w| w[0] < w[1]),
                "{triple} cfgs are sorted"
            );
            assert_eq!(table.cfg_text(triple).unwrap(), cfgs.join("\n"));
        }
        assert!(table.cfg_text("not-a-real-triple").is_none());
    }
}
