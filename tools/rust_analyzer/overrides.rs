//! Detection of Bazel modules with local (non-registry) overrides.
//!
//! A module declared with `local_path_override` or `--override_module` has
//! its sources in a checkout the user edits directly, but Bazel surfaces it
//! through a symlink at `{output_base}/external/<repo>/`. The rust-analyzer
//! aspect classifies every crate under `external/` as a non-member, so
//! rust-analyzer shows no diagnostics for these first-party crates. This
//! module asks Bazel which external repos are really local overrides so
//! `rust_project.rs` can treat their crates as workspace members.
//! See <https://github.com/bazelbuild/rules_rust/issues/4213>.

use std::collections::{BTreeMap, BTreeSet};

use anyhow::Context;
use camino::{Utf8Path, Utf8PathBuf};
use serde::Deserialize;

use crate::bazel_command;

/// A module node in `bazel mod graph --output json`.
#[derive(Debug, Deserialize)]
struct ModGraphNode {
    /// `<name>@<version>`; modules with a non-registry override render as
    /// `<name>@_` (the `version` field still carries the declared version,
    /// so the key is the only reliable override marker).
    #[serde(default)]
    key: String,
    #[serde(default)]
    name: String,
    /// The repo name the parent module uses for this dependency.
    #[serde(rename = "apparentName", default)]
    apparent_name: String,
    #[serde(default)]
    dependencies: Vec<ModGraphNode>,
    #[serde(rename = "indirectDependencies", default)]
    indirect_dependencies: Vec<ModGraphNode>,
}

/// External repository roots (under `{output_base}/external/`) of modules
/// with local overrides — non-registry overrides whose repo directory is a
/// symlink back into a real checkout.
///
/// Best-effort: when the `bazel mod` command itself fails (WORKSPACE mode,
/// pre-bzlmod Bazel), this logs and returns an empty list so gen_rust_project
/// behaves exactly as before. Unparseable output is an error — that means
/// the format changed and this code needs updating.
pub fn local_override_repo_roots(
    bazel: &Utf8Path,
    workspace: &Utf8Path,
    output_base: &Utf8Path,
    bazel_startup_options: &[String],
) -> anyhow::Result<Vec<Utf8PathBuf>> {
    let graph_json = match run_bazel_mod(
        bazel,
        workspace,
        output_base,
        bazel_startup_options,
        &["graph", "--output", "json"],
    ) {
        Ok(stdout) => stdout,
        Err(e) => {
            log::debug!("`bazel mod graph` unavailable ({e:#}); assuming no module overrides");
            return Ok(Vec::new());
        }
    };

    let overridden = overridden_modules(&graph_json)?;
    if overridden.is_empty() {
        return Ok(Vec::new());
    }

    // Resolve module names to canonical repo names through the root module's
    // repo mapping — authoritative for every repo the root can see, across
    // the canonical-name schemes of different Bazel versions.
    let mapping_json = run_bazel_mod(
        bazel,
        workspace,
        output_base,
        bazel_startup_options,
        &["dump_repo_mapping", ""],
    )
    .context("`bazel mod dump_repo_mapping` failed after `bazel mod graph` succeeded")?;
    let mapping: BTreeMap<String, String> =
        serde_json::from_str(&mapping_json).context("parsing `bazel mod dump_repo_mapping`")?;

    let external = output_base.join("external");
    let roots = overridden
        .iter()
        .map(|module| {
            let canonical = match mapping.get(&module.apparent_name) {
                Some(canonical) => canonical.clone(),
                // Overridden but not visible from the root module (an
                // override of a transitively-used module). Fall back to
                // Bazel's documented canonical name for modules, `<name>+`.
                None => format!("{}+", module.name),
            };
            external.join(canonical)
        })
        // Keep only repos that are symlinks: that is what distinguishes a
        // *local* override (`local_path_override`, `--override_module`) from
        // a fetched non-registry override (`git_override`,
        // `archive_override`), whose sources are not editable checkouts.
        .filter(|root| {
            root.symlink_metadata()
                .map(|m| m.file_type().is_symlink())
                .unwrap_or(false)
        })
        .collect();

    Ok(roots)
}

/// An overridden module: its declared name and the name the root module
/// knows it by.
#[derive(Debug, PartialEq, Eq, PartialOrd, Ord)]
struct OverriddenModule {
    name: String,
    apparent_name: String,
}

/// Walk the module graph and collect every module whose key carries the
/// non-registry-override marker (`<name>@_`).
fn overridden_modules(graph_json: &str) -> anyhow::Result<BTreeSet<OverriddenModule>> {
    let root: ModGraphNode =
        serde_json::from_str(graph_json).context("parsing `bazel mod graph --output json`")?;

    let mut found = BTreeSet::new();
    let mut stack = vec![&root];
    while let Some(node) = stack.pop() {
        if node.key.ends_with("@_") {
            found.insert(OverriddenModule {
                name: node.name.clone(),
                apparent_name: node.apparent_name.clone(),
            });
        }
        stack.extend(&node.dependencies);
        stack.extend(&node.indirect_dependencies);
    }
    Ok(found)
}

fn run_bazel_mod(
    bazel: &Utf8Path,
    workspace: &Utf8Path,
    output_base: &Utf8Path,
    bazel_startup_options: &[String],
    mod_args: &[&str],
) -> anyhow::Result<String> {
    let output = bazel_command(bazel, Some(workspace), Some(output_base))
        .args(bazel_startup_options)
        .arg("mod")
        .args(mod_args)
        .output()
        .with_context(|| format!("spawning `bazel mod {}`", mod_args.join(" ")))?;

    if !output.status.success() {
        anyhow::bail!(
            "`bazel mod {}` failed ({}):\n{}",
            mod_args.join(" "),
            output.status,
            String::from_utf8_lossy(&output.stderr),
        );
    }

    String::from_utf8(output.stdout).context("`bazel mod` output is not UTF-8")
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Trimmed-down real output of `bazel mod graph --output json` from a
    /// workspace with one `local_path_override` module (`mypkg@_`) among
    /// regular registry dependencies.
    const GRAPH_JSON: &str = r#"{
        "key": "<root>",
        "name": "myworkspace",
        "version": "1.0.0",
        "apparentName": "myworkspace",
        "dependencies": [
            {
                "key": "rules_rust@0.73.0",
                "name": "rules_rust",
                "version": "0.73.0",
                "apparentName": "rules_rust",
                "dependencies": [],
                "indirectDependencies": [],
                "cycles": []
            },
            {
                "key": "mypkg@_",
                "name": "mypkg",
                "version": "0.1.0",
                "apparentName": "mypkg",
                "dependencies": [],
                "indirectDependencies": [],
                "cycles": []
            }
        ],
        "indirectDependencies": [],
        "cycles": []
    }"#;

    #[test]
    fn overridden_modules_found_by_key_marker() {
        let found = overridden_modules(GRAPH_JSON).unwrap();
        // `mypkg` is overridden (key `mypkg@_`) even though its `version`
        // field carries a declared version; `rules_rust` is not.
        assert_eq!(found.len(), 1);
        let module = found.first().unwrap();
        assert_eq!(module.name, "mypkg");
        assert_eq!(module.apparent_name, "mypkg");
    }

    #[test]
    fn no_overrides_yields_empty_set() {
        let graph = r#"{
            "key": "<root>",
            "name": "myworkspace",
            "version": "1.0.0",
            "apparentName": "myworkspace",
            "dependencies": [
                {
                    "key": "rules_rust@0.73.0",
                    "name": "rules_rust",
                    "version": "0.73.0",
                    "apparentName": "rules_rust"
                }
            ]
        }"#;
        assert!(overridden_modules(graph).unwrap().is_empty());
    }

    #[test]
    fn nested_overrides_are_collected() {
        // An override of a module the root only reaches transitively still
        // shows the `@_` marker on the nested node.
        let graph = r#"{
            "key": "<root>",
            "name": "myworkspace",
            "version": "1.0.0",
            "apparentName": "myworkspace",
            "dependencies": [
                {
                    "key": "some_dep@1.0.0",
                    "name": "some_dep",
                    "version": "1.0.0",
                    "apparentName": "some_dep",
                    "dependencies": [
                        {
                            "key": "transitive_pkg@_",
                            "name": "transitive_pkg",
                            "version": "2.0.0",
                            "apparentName": "transitive_pkg"
                        }
                    ]
                }
            ]
        }"#;
        let found = overridden_modules(graph).unwrap();
        assert_eq!(found.len(), 1);
        assert_eq!(found.first().unwrap().name, "transitive_pkg");
    }

    #[test]
    fn malformed_graph_is_an_error() {
        assert!(overridden_modules("not json").is_err());
    }
}
