//! Library for generating rust_project.json files from a `Vec<CrateSpec>`
//! See official documentation of file format at https://rust-analyzer.github.io/manual.html

use core::fmt;
use std::{
    collections::{BTreeMap, BTreeSet, HashMap},
    str::FromStr,
};

use anyhow::Context;
use camino::{Utf8Path, Utf8PathBuf};
use serde::{Deserialize, Serialize};

// `Deserialize` on the project shape is needed so cache hits can round-trip
// the persisted JSON back into the `RustProject` the callers want. Cache
// writes are still produced via the canonical assembly path, so the schema
// can drift forward freely; only Deserialize-on-cache-hit relies on it.

use crate::{
    aquery::{CrateSpec, CrateType},
    buildfile_to_targets, source_file_to_buildfile, ToolchainInfo,
};

/// The argument that `rust-analyzer` can pass to the workspace discovery command.
#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub enum RustAnalyzerArg {
    Path(Utf8PathBuf),
    Buildfile(Utf8PathBuf),
}

impl RustAnalyzerArg {
    /// Consumes itself to return a build file and the targets to build.
    pub fn into_target_details(
        self,
        workspace: &Utf8Path,
    ) -> anyhow::Result<(Utf8PathBuf, String)> {
        match self {
            Self::Path(file) => {
                let buildfile = source_file_to_buildfile(&file)?;
                buildfile_to_targets(workspace, &buildfile).map(|t| (buildfile, t))
            }
            Self::Buildfile(buildfile) => {
                buildfile_to_targets(workspace, &buildfile).map(|t| (buildfile, t))
            }
        }
    }
}

impl FromStr for RustAnalyzerArg {
    type Err = anyhow::Error;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        serde_json::from_str(s).context("rust analyzer argument error")
    }
}

/// The format that `rust_analyzer` expects as a response when automatically invoked.
/// See [rust-analyzer documentation][rd] for a thorough description of this interface.
/// [rd]: <https://rust-analyzer.github.io/manual.html#rust-analyzer.workspace.discoverConfig>.
// `Progress` carries an `&fmt::Arguments` for in-flight log lines, which can't
// be deserialized; the cache stores the inner `RustProject`, never the
// discovery envelope, so Serialize is all we need here.
#[derive(Debug, Serialize)]
#[serde(tag = "kind")]
#[serde(rename_all = "snake_case")]
pub enum DiscoverProject<'a> {
    Finished {
        buildfile: Utf8PathBuf,
        project: RustProject,
    },
    Error {
        error: String,
        source: Option<String>,
    },
    Progress {
        message: &'a fmt::Arguments<'a>,
    },
}

/// A `rust-project.json` workspace representation. See
/// [rust-analyzer documentation][rd] for a thorough description of this interface.
/// [rd]: https://rust-analyzer.github.io/manual.html#non-cargo-based-projects
#[derive(Debug, Serialize, Deserialize)]
pub struct RustProject {
    /// The path to a Rust sysroot.
    sysroot: Utf8PathBuf,

    /// Path to the directory with *source code* of
    /// sysroot crates.
    sysroot_src: Utf8PathBuf,

    /// The set of crates comprising the current
    /// project. Must include all transitive
    /// dependencies as well as sysroot crate (libstd,
    /// libcore and such).
    crates: Vec<Crate>,

    /// The set of runnables, such as tests or benchmarks,
    /// that can be found in the crate.
    runnables: Vec<Runnable>,
}

/// A `rust-project.json` crate representation. See
/// [rust-analyzer documentation][rd] for a thorough description of this interface.
/// [rd]: https://rust-analyzer.github.io/manual.html#non-cargo-based-projects
#[derive(Debug, Serialize, Deserialize)]
pub struct Crate {
    /// A name used in the package's project declaration
    #[serde(skip_serializing_if = "Option::is_none")]
    display_name: Option<String>,

    /// Path to the root module of the crate.
    root_module: String,

    /// Edition of the crate.
    edition: String,

    /// Dependencies
    deps: Vec<Dependency>,

    /// Should this crate be treated as a member of current "workspace".
    #[serde(skip_serializing_if = "Option::is_none")]
    is_workspace_member: Option<bool>,

    /// Optionally specify the (super)set of `.rs` files comprising this crate.
    #[serde(skip_serializing_if = "Source::is_empty", default)]
    source: Source,

    /// The set of cfgs activated for a given crate, like
    /// `["unix", "feature=\"foo\"", "feature=\"bar\""]`.
    cfg: Vec<String>,

    /// Target triple for this Crate.
    #[serde(skip_serializing_if = "Option::is_none")]
    target: Option<String>,

    /// Environment variables, used for the `env!` macro
    #[serde(skip_serializing_if = "Option::is_none")]
    env: Option<BTreeMap<String, String>>,

    /// Whether the crate is a proc-macro crate.
    is_proc_macro: bool,

    /// For proc-macro crates, path to compiled proc-macro (.so file).
    #[serde(skip_serializing_if = "Option::is_none")]
    proc_macro_dylib_path: Option<String>,

    /// Build information for the crate
    #[serde(skip_serializing_if = "Option::is_none")]
    build: Option<Build>,
}

#[derive(Debug, Default, Serialize, Deserialize)]
pub struct Source {
    include_dirs: Vec<String>,
    exclude_dirs: Vec<String>,
}

impl Source {
    fn is_empty(&self) -> bool {
        self.include_dirs.is_empty() && self.exclude_dirs.is_empty()
    }
}

#[derive(Debug, Serialize, Deserialize)]
pub struct Dependency {
    /// Index of a crate in the `crates` array.
    #[serde(rename = "crate")]
    crate_index: usize,

    /// The display name of the crate.
    name: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct Build {
    /// The name associated with this crate.
    ///
    /// This is determined by the build system that produced
    /// the `rust-project.json` in question. For instance, if bazel were used,
    /// the label might be something like `//ide/rust/rust-analyzer:rust-analyzer`.
    ///
    /// Do not attempt to parse the contents of this string; it is a build system-specific
    /// identifier similar to [`Crate::display_name`].
    label: String,
    /// Path corresponding to the build system-specific file defining the crate.
    ///
    /// It is roughly analogous to [`ManifestPath`], but it should *not* be used with
    /// [`crate::ProjectManifest::from_manifest_file`], as the build file may not be
    /// be in the `rust-project.json`.
    build_file: Utf8PathBuf,
    /// The kind of target.
    ///
    /// Examples (non-exhaustively) include [`TargetKind::Bin`], [`TargetKind::Lib`],
    /// and [`TargetKind::Test`]. This information is used to determine what sort
    /// of runnable codelens to provide, if any.
    target_kind: TargetKind,
}

#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum TargetKind {
    Bin,
    /// Any kind of Cargo lib crate-type (dylib, rlib, proc-macro, ...).
    Lib,
    Test,
}

/// A template-like structure for describing runnables.
///
/// These are used for running and debugging binaries and tests without encoding
/// build system-specific knowledge into rust-analyzer.
///
/// # Example
///
/// Below is an example of a test runnable. `{label}` and `{test_id}`
/// are explained in [`Runnable::args`]'s documentation.
///
/// ```json
/// {
///     "program": "bazel",
///     "args": [
///         "test",
///          "{label}",
///          "--test_arg",
///          "{test_id}",
///     ],
///     "cwd": "/home/user/repo-root/",
///     "kind": "testOne"
/// }
/// ```
#[derive(Debug, Serialize, Deserialize)]
pub struct Runnable {
    /// The program invoked by the runnable.
    ///
    /// For example, this might be `cargo`, `bazel`, etc.
    program: String,
    /// The arguments passed to [`Runnable::program`].
    ///
    /// The args can contain two template strings: `{label}` and `{test_id}`.
    /// rust-analyzer will find and replace `{label}` with [`Build::label`] and
    /// `{test_id}` with the test name.
    args: Vec<String>,
    /// The current working directory of the runnable.
    cwd: Utf8PathBuf,
    kind: RunnableKind,
}

/// The kind of runnable.
///
/// Matches rust-analyzer's `RunnableKind` at the discoverConfig
/// boundary. rust-analyzer's deserializer is strict — emitting a
/// variant it doesn't recognize causes the ENTIRE discovery to be
/// rejected, so per-variant emission lives at the call site and is
/// gated on the rust-analyzer version (read from the toolchain's
/// declared `version`; see [`ToolchainInfo::version`]).
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum RunnableKind {
    Check,

    /// On-save build that emits rustc JSON diagnostics on stdout for
    /// rust-analyzer to render as inline squiggles.
    Flycheck,

    /// Can run a binary.
    Run,

    /// Run a single test. rust-analyzer substitutes `{test_id}` with
    /// the function's canonical path (e.g. `tests::it_works`).
    TestOne,

    /// Run every test in a module. rust-analyzer substitutes
    /// `{test_pattern}` with the module path. Bazel's test filter is
    /// per-target rather than per-module, so we forward as
    /// `--test_arg` and let libtest's name-prefix match filter.
    ///
    /// Added in rust-analyzer 1.96. Required there: with a `build`
    /// field present, rust-analyzer routes every runnable through
    /// `ProjectJsonTargetSpec` lookup, and missing kinds cause the
    /// codelens-rendering pipeline to silently drop the `▶ Run Test`
    /// codelens on every `#[test]` fn. Emitting it on 1.95 and
    /// earlier breaks discovery entirely (unknown variant).
    TestMod,
}

/// True when the toolchain's declared `version` is new enough to
/// deserialize [`RunnableKind::TestMod`] (i.e. 1.96+). Empty or
/// unparsable versions return `false` — safer to degrade gracefully
/// (lose the module-level codelens) than to break discovery.
fn supports_test_mod(version: &str) -> bool {
    let mut parts = version.split('.').filter_map(|p| p.parse::<u32>().ok());
    matches!((parts.next(), parts.next()), (Some(major), Some(minor)) if (major, minor) >= (1, 96))
}

/// Prefers `$RULES_RUST_RA_LAUNCHER_DIR` (published by discover's
/// `self_locate_config`). Falls back to
/// `<workspace>/.rules_rust_analyzer/` for direct-exec debugging.
fn flycheck_launcher_path(workspace: &Utf8Path) -> Utf8PathBuf {
    let launcher_dir = std::env::var("RULES_RUST_RA_LAUNCHER_DIR")
        .ok()
        .filter(|s| !s.is_empty())
        .map(Utf8PathBuf::from)
        .unwrap_or_else(|| workspace.join(".rules_rust_analyzer"));
    launcher_dir.join(crate::FLYCHECK_BINARY_FILENAME)
}

/// Findings from inspecting the consolidated `CrateSpec` set for problems
/// that would otherwise silently degrade the IDE experience.
#[derive(Debug, Default, PartialEq, Eq)]
pub struct AssemblyDiagnostics {
    /// Each entry is `(referencing_crate_id, missing_dep_crate_id)`. The
    /// missing dep was filtered out during dep resolution — usually it
    /// means a target was a non-Rust dep that the aspect skipped, or its
    /// spec generation failed.
    pub missing_deps: Vec<(String, String)>,
    /// Each cycle is rendered as an ordered list of `crate_id`s with the
    /// first node repeated at the end so the loop is visually obvious:
    /// e.g. `["ID-a", "ID-b", "ID-a"]` for an A → B → A cycle.
    pub cycles: Vec<Vec<String>>,
}

impl AssemblyDiagnostics {
    pub fn is_empty(&self) -> bool {
        self.missing_deps.is_empty() && self.cycles.is_empty()
    }
}

/// Inspect the consolidated `CrateSpec` set for problems. This is a pure
/// function returning the findings; callers are responsible for surfacing
/// them (`log::warn!`, persistent log file, etc).
pub fn diagnose(crate_specs: &BTreeSet<CrateSpec>) -> AssemblyDiagnostics {
    use std::collections::BTreeSet as Set;

    let id_set: Set<&str> = crate_specs.iter().map(|c| c.crate_id.as_str()).collect();

    // Pass 1: deps that don't resolve to any crate in the spec set.
    let mut missing_deps: Vec<(String, String)> = Vec::new();
    for c in crate_specs {
        for dep in &c.deps {
            if !id_set.contains(dep.as_str()) {
                missing_deps.push((c.crate_id.clone(), dep.clone()));
            }
        }
    }
    missing_deps.sort();

    // Pass 2: cycles in the resolved (intra-project) dep graph. Only
    // consider edges that point at known crate_ids so missing deps aren't
    // double-reported as cycles.
    let adj: BTreeMap<&str, Vec<&str>> = crate_specs
        .iter()
        .map(|c| {
            (
                c.crate_id.as_str(),
                c.deps
                    .iter()
                    .filter(|d| id_set.contains(d.as_str()))
                    .map(|d| d.as_str())
                    .collect(),
            )
        })
        .collect();
    let cycles = find_all_cycles(&adj);

    AssemblyDiagnostics {
        missing_deps,
        cycles,
    }
}

/// Render a human-readable warning report. Used both for `log::warn!`
/// emission (one line per finding) and for the persistent log file.
pub fn format_diagnostics(diag: &AssemblyDiagnostics) -> String {
    let mut out = String::new();
    for (referencing, missing) in &diag.missing_deps {
        out.push_str(&format!(
            "missing dep: crate {referencing} references {missing} which is not in the project (target may be a non-Rust dep, filtered, or its spec generation failed)\n"
        ));
    }
    for cycle in &diag.cycles {
        out.push_str(&format!("dep cycle: {}\n", cycle.join(" → ")));
    }
    out
}

#[derive(Clone, Copy, PartialEq, Eq)]
enum DfsColor {
    White,
    Gray,
    Black,
}

fn find_all_cycles(adj: &BTreeMap<&str, Vec<&str>>) -> Vec<Vec<String>> {
    let mut colors: HashMap<&str, DfsColor> = adj.keys().map(|&k| (k, DfsColor::White)).collect();
    let mut found: BTreeSet<Vec<String>> = BTreeSet::new();
    let mut path: Vec<&str> = Vec::new();

    // BTreeMap iteration is sorted, so DFS roots are visited deterministically
    // and the produced cycle paths are stable across runs (important for
    // tests).
    for &start in &adj.keys().copied().collect::<Vec<_>>() {
        if colors.get(start).copied().unwrap_or(DfsColor::White) == DfsColor::White {
            dfs_collect_cycles(start, adj, &mut colors, &mut path, &mut found);
        }
    }

    // Render: close each cycle by repeating the first node at the end.
    found
        .into_iter()
        .map(|mut cycle| {
            if let Some(first) = cycle.first().cloned() {
                cycle.push(first);
            }
            cycle
        })
        .collect()
}

fn dfs_collect_cycles<'a>(
    node: &'a str,
    adj: &BTreeMap<&'a str, Vec<&'a str>>,
    colors: &mut HashMap<&'a str, DfsColor>,
    path: &mut Vec<&'a str>,
    found: &mut BTreeSet<Vec<String>>,
) {
    colors.insert(node, DfsColor::Gray);
    path.push(node);

    if let Some(neighbors) = adj.get(node) {
        for &next in neighbors {
            match colors.get(next).copied().unwrap_or(DfsColor::White) {
                DfsColor::White => dfs_collect_cycles(next, adj, colors, path, found),
                DfsColor::Gray => {
                    // Back-edge: cycle from `next` (on path) back to itself
                    // via `node`. Self-loops (node == next) are handled by
                    // the same code path — `start_idx` points at the last
                    // path entry, producing a single-element cycle.
                    if let Some(start_idx) = path.iter().position(|&n| n == next) {
                        let cycle_nodes: Vec<&str> = path[start_idx..].to_vec();
                        found.insert(canonicalize_cycle(&cycle_nodes));
                    }
                }
                DfsColor::Black => {
                    // Already fully processed: cannot be on the current
                    // path, so no cycle involving it from here.
                }
            }
        }
    }

    colors.insert(node, DfsColor::Black);
    path.pop();
}

/// Rotate a cycle so its lexicographically smallest element is first; this
/// makes A→B→C→A and B→C→A→B compare equal after canonicalization, so the
/// dedup set treats them as the same cycle regardless of which DFS root
/// discovered it.
fn canonicalize_cycle(cycle: &[&str]) -> Vec<String> {
    if cycle.is_empty() {
        return Vec::new();
    }
    let min_idx = (0..cycle.len()).min_by_key(|&i| cycle[i]).unwrap_or(0);
    cycle[min_idx..]
        .iter()
        .chain(cycle[..min_idx].iter())
        .map(|s| s.to_string())
        .collect()
}

pub fn assemble_rust_project(
    bazel: &Utf8Path,
    workspace: &Utf8Path,
    toolchain_info: ToolchainInfo,
    crate_specs: &BTreeSet<CrateSpec>,
) -> anyhow::Result<RustProject> {
    let emit_test_mod = supports_test_mod(&toolchain_info.version);

    let mut runnables = vec![
        Runnable {
            program: bazel.to_string(),
            args: vec!["build".to_owned(), "{label}".to_owned()],
            cwd: workspace.to_owned(),
            kind: RunnableKind::Check,
        },
        // On-save flycheck. Args stay user-agnostic — per-user
        // preferences (clippy, ...) live in
        // `<launcher_dir>/user_config.json` and are read by
        // `bin/flycheck.rs` on each save.
        Runnable {
            program: flycheck_launcher_path(workspace).to_string(),
            args: vec!["{label}".to_owned(), "{saved_file}".to_owned()],
            cwd: workspace.to_owned(),
            kind: RunnableKind::Flycheck,
        },
        Runnable {
            program: bazel.to_string(),
            args: vec![
                "test".to_owned(),
                "{label}".to_owned(),
                "--test_output".to_owned(),
                "streamed".to_owned(),
                "--test_arg".to_owned(),
                "--nocapture".to_owned(),
                "--test_arg".to_owned(),
                "--exact".to_owned(),
                "--test_arg".to_owned(),
                "{test_id}".to_owned(),
            ],
            cwd: workspace.to_owned(),
            kind: RunnableKind::TestOne,
        },
        // Run unlocks the per-#[test]-fn TestOne codelens via the
        // same rust-analyzer ProjectJsonTargetSpec quirk that makes
        // TestMod load-bearing. Empirically verified against 1.96.0;
        // the template itself is only INVOKED for binary main()s, so
        // its presence is harmless when the user clicks a test
        // codelens — TestOne fires instead.
        Runnable {
            program: bazel.to_string(),
            args: vec!["run".to_owned(), "{label}".to_owned()],
            cwd: workspace.to_owned(),
            kind: RunnableKind::Run,
        },
    ];

    if emit_test_mod {
        // `{test_pattern}` is rust-analyzer's module path (e.g.
        // `tests::`). Bazel's test filter is per-target rather than
        // per-module, so we forward as `--test_arg` and let libtest's
        // name-prefix match do the filtering. Approximate but
        // functionally correct for the typical lib + inline
        // `#[cfg(test)] mod tests` layout. See `RunnableKind::TestMod`
        // for why this matters on rust-analyzer 1.96+.
        runnables.push(Runnable {
            program: bazel.to_string(),
            args: vec![
                "test".to_owned(),
                "{label}".to_owned(),
                "--test_output".to_owned(),
                "streamed".to_owned(),
                "--test_arg".to_owned(),
                "--nocapture".to_owned(),
                "--test_arg".to_owned(),
                "{test_pattern}".to_owned(),
            ],
            cwd: workspace.to_owned(),
            kind: RunnableKind::TestMod,
        });
    }

    let mut project = RustProject {
        sysroot: toolchain_info.sysroot,
        sysroot_src: toolchain_info.sysroot_src,
        crates: Vec::new(),
        runnables,
    };

    // Pre-compute crate_id → index and crate_id → spec maps so the dep
    // resolution pass below can reference any crate (forward or backward)
    // without toposorting. The artificial cycles that the merge-by-root-
    // module heuristic produced are gone now that crate_id is unique per
    // Bazel target; but even if a future change ever introduced duplicate
    // ids or a true cycle, the worst case here is silently dropping a dep
    // edge rather than failing the whole project load.
    let id_to_index: HashMap<&str, usize> = crate_specs
        .iter()
        .enumerate()
        .map(|(i, c)| (c.crate_id.as_str(), i))
        .collect();
    let id_to_spec: HashMap<&str, &CrateSpec> = crate_specs
        .iter()
        .map(|c| (c.crate_id.as_str(), c))
        .collect();

    for c in crate_specs {
        let target_kind = match c.crate_type {
            CrateType::Bin if c.is_test => TargetKind::Test,
            CrateType::Bin => TargetKind::Bin,
            CrateType::Rlib
            | CrateType::Lib
            | CrateType::Dylib
            | CrateType::Cdylib
            | CrateType::Staticlib
            | CrateType::ProcMacro => TargetKind::Lib,
        };

        // (No per-crate Run runnable here — rust-analyzer's
        // `runnable_template(kind)` only looks at the first matching entry
        // and substitutes `{label}` from the crate's `build.label`. The
        // single Run template assembled above covers every bin.)

        let deps: Vec<Dependency> = c
            .deps
            .iter()
            .filter_map(|dep_id| {
                let crate_index = *id_to_index.get(dep_id.as_str())?;
                let dep_spec = id_to_spec.get(dep_id.as_str())?;
                let name = c
                    .aliases
                    .get(dep_id.as_str())
                    .cloned()
                    .unwrap_or_else(|| dep_spec.display_name.clone());
                Some(Dependency { crate_index, name })
            })
            .collect();

        project.crates.push(Crate {
            display_name: Some(c.display_name.clone()),
            root_module: c.root_module.clone(),
            edition: c.edition.clone(),
            deps,
            is_workspace_member: Some(c.is_workspace_member),
            source: match &c.source {
                Some(s) => Source {
                    exclude_dirs: s.exclude_dirs.clone(),
                    include_dirs: s.include_dirs.clone(),
                },
                None => Source::default(),
            },
            cfg: c.cfg.clone(),
            target: Some(c.target.clone()),
            env: Some(c.env.clone()),
            is_proc_macro: c.proc_macro_dylib_path.is_some(),
            proc_macro_dylib_path: c.proc_macro_dylib_path.clone(),
            build: c.build.as_ref().map(|b| Build {
                // `consolidate_crate_specs` already replaces the lib's
                // build.label with the sibling test's, so `{label}`
                // substitution in TestOne / Check templates is always a
                // valid Bazel target.
                label: b.label.clone(),
                build_file: b.build_file.clone().into(),
                target_kind,
            }),
        });
    }

    Ok(project)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn supports_test_mod_at_or_above_1_96() {
        // At-minimum and above-minimum: emit.
        assert!(supports_test_mod("1.96.0"));
        assert!(supports_test_mod("2.0.0"));
        // The cited problem version: don't emit.
        assert!(!supports_test_mod("1.95.0"));
        // Unknown / unset version: safe default (degrade gracefully —
        // lose the module-level codelens rather than break discovery
        // by emitting a variant rust-analyzer rejects).
        assert!(!supports_test_mod(""));
        assert!(!supports_test_mod("not-a-version"));
    }

    /// A simple example with a single crate and no dependencies.
    #[test]
    fn generate_rust_project_single() {
        let project = assemble_rust_project(
            Utf8Path::new("bazel"),
            Utf8Path::new("workspace"),
            ToolchainInfo {
                sysroot: "sysroot".to_owned().into(),
                sysroot_src: "sysroot_src".to_owned().into(),
                version: String::new(),
            },
            &BTreeSet::from([CrateSpec {
                aliases: BTreeMap::new(),
                crate_id: "ID-example".into(),
                display_name: "example".into(),
                edition: "2018".into(),
                root_module: "example/lib.rs".into(),
                is_workspace_member: true,
                deps: BTreeSet::new(),
                proc_macro_dylib_path: None,
                source: None,
                cfg: vec!["test".into(), "debug_assertions".into()],
                env: BTreeMap::new(),
                target: "x86_64-unknown-linux-gnu".into(),
                crate_type: CrateType::Rlib,
                is_test: false,
                build: None,
            }]),
        )
        .expect("expect success");

        assert_eq!(project.crates.len(), 1);
        let c = &project.crates[0];
        assert_eq!(c.display_name, Some("example".into()));
        assert_eq!(c.root_module, "example/lib.rs");
        assert_eq!(c.deps.len(), 0);
    }

    /// An example with a one crate having two dependencies.
    #[test]
    fn generate_rust_project_with_deps() {
        let project = assemble_rust_project(
            Utf8Path::new("bazel"),
            Utf8Path::new("workspace"),
            ToolchainInfo {
                sysroot: "sysroot".to_owned().into(),
                sysroot_src: "sysroot_src".to_owned().into(),
                version: String::new(),
            },
            &BTreeSet::from([
                CrateSpec {
                    aliases: BTreeMap::new(),
                    crate_id: "ID-example".into(),
                    display_name: "example".into(),
                    edition: "2018".into(),
                    root_module: "example/lib.rs".into(),
                    is_workspace_member: true,
                    deps: BTreeSet::from(["ID-dep_a".into(), "ID-dep_b".into()]),
                    proc_macro_dylib_path: None,
                    source: None,
                    cfg: vec!["test".into(), "debug_assertions".into()],
                    env: BTreeMap::new(),
                    target: "x86_64-unknown-linux-gnu".into(),
                    crate_type: CrateType::Rlib,
                    is_test: false,
                    build: None,
                },
                CrateSpec {
                    aliases: BTreeMap::new(),
                    crate_id: "ID-dep_a".into(),
                    display_name: "dep_a".into(),
                    edition: "2018".into(),
                    root_module: "dep_a/lib.rs".into(),
                    is_workspace_member: false,
                    deps: BTreeSet::new(),
                    proc_macro_dylib_path: None,
                    source: None,
                    cfg: vec!["test".into(), "debug_assertions".into()],
                    env: BTreeMap::new(),
                    target: "x86_64-unknown-linux-gnu".into(),
                    crate_type: CrateType::Rlib,
                    is_test: false,
                    build: None,
                },
                CrateSpec {
                    aliases: BTreeMap::new(),
                    crate_id: "ID-dep_b".into(),
                    display_name: "dep_b".into(),
                    edition: "2018".into(),
                    root_module: "dep_b/lib.rs".into(),
                    is_workspace_member: false,
                    deps: BTreeSet::new(),
                    proc_macro_dylib_path: None,
                    source: None,
                    cfg: vec!["test".into(), "debug_assertions".into()],
                    env: BTreeMap::new(),
                    target: "x86_64-unknown-linux-gnu".into(),
                    crate_type: CrateType::Rlib,
                    is_test: false,
                    build: None,
                },
            ]),
        )
        .expect("expect success");

        assert_eq!(project.crates.len(), 3);
        // Both dep_a and dep_b should be one of the first two crates.
        assert!(
            Some("dep_a".into()) == project.crates[0].display_name
                || Some("dep_a".into()) == project.crates[1].display_name
        );
        assert!(
            Some("dep_b".into()) == project.crates[0].display_name
                || Some("dep_b".into()) == project.crates[1].display_name
        );
        let c = &project.crates[2];
        assert_eq!(c.display_name, Some("example".into()));
    }

    fn spec(id: &str, deps: &[&str]) -> CrateSpec {
        CrateSpec {
            aliases: BTreeMap::new(),
            crate_id: id.into(),
            display_name: id.replace("ID-", ""),
            edition: "2018".into(),
            root_module: format!("{}/lib.rs", id.replace("ID-", "")),
            is_workspace_member: true,
            deps: deps.iter().map(|s| s.to_string()).collect(),
            proc_macro_dylib_path: None,
            source: None,
            cfg: vec![],
            env: BTreeMap::new(),
            target: "x86_64-unknown-linux-gnu".into(),
            crate_type: CrateType::Rlib,
            is_test: false,
            build: None,
        }
    }

    /// A cyclic input — A depends on B and B depends on A — must still
    /// produce a usable project. Earlier code returned an `Err` here, which
    /// hid every crate from rust-analyzer.
    #[test]
    fn cycle_does_not_break_assembly() {
        let project = assemble_rust_project(
            Utf8Path::new("bazel"),
            Utf8Path::new("workspace"),
            ToolchainInfo {
                sysroot: "sysroot".to_owned().into(),
                sysroot_src: "sysroot_src".to_owned().into(),
                version: String::new(),
            },
            &BTreeSet::from([spec("ID-a", &["ID-b"]), spec("ID-b", &["ID-a"])]),
        )
        .expect("cycle must not fail assembly");

        // Both crates present and both edges resolved by index — a real
        // graph cycle in the JSON, which rust-analyzer handles fine.
        assert_eq!(project.crates.len(), 2);
        let a = project
            .crates
            .iter()
            .find(|c| c.display_name.as_deref() == Some("a"))
            .unwrap();
        let b = project
            .crates
            .iter()
            .find(|c| c.display_name.as_deref() == Some("b"))
            .unwrap();
        assert_eq!(a.deps.len(), 1);
        assert_eq!(b.deps.len(), 1);
    }

    /// A dep pointing at a non-existent crate_id (e.g., a target whose spec
    /// got filtered) must drop just that edge, not bail.
    #[test]
    fn missing_dep_is_dropped_not_fatal() {
        let project = assemble_rust_project(
            Utf8Path::new("bazel"),
            Utf8Path::new("workspace"),
            ToolchainInfo {
                sysroot: "sysroot".to_owned().into(),
                sysroot_src: "sysroot_src".to_owned().into(),
                version: String::new(),
            },
            &BTreeSet::from([spec("ID-a", &["ID-nonexistent"])]),
        )
        .expect("missing dep must not fail assembly");

        assert_eq!(project.crates.len(), 1);
        assert_eq!(project.crates[0].deps.len(), 0);
    }

    /// The runnable command must be byte-identical across users regardless
    /// of clippy preference — flycheck reads its own per-user opt-in from
    /// `user_config.json` on each save. If this ever regresses to
    /// per-user command args, the CLI contract with `bin/flycheck.rs`
    /// silently breaks (clap rejects unknown flags at runtime).
    #[test]
    fn flycheck_runnable_uses_positional_args_only() {
        let project = assemble_rust_project(
            Utf8Path::new("bazel"),
            Utf8Path::new("workspace"),
            ToolchainInfo {
                sysroot: "sysroot".to_owned().into(),
                sysroot_src: "sysroot_src".to_owned().into(),
                version: String::new(),
            },
            &BTreeSet::from([spec("ID-a", &[])]),
        )
        .expect("expect success");

        let flycheck = project
            .runnables
            .iter()
            .find(|r| matches!(r.kind, RunnableKind::Flycheck))
            .expect("flycheck runnable must exist");
        assert_eq!(
            flycheck.args,
            vec!["{label}".to_owned(), "{saved_file}".to_owned()],
        );
    }

    // --- diagnose() suite ---

    #[test]
    fn diagnose_missing_dep_names_both_crates() {
        let diag = diagnose(&BTreeSet::from([spec("ID-a", &["ID-nonexistent"])]));
        assert_eq!(diag.cycles, Vec::<Vec<String>>::new());
        assert_eq!(
            diag.missing_deps,
            vec![("ID-a".to_string(), "ID-nonexistent".to_string())]
        );
    }

    #[test]
    fn diagnose_simple_cycle_reports_full_path() {
        let diag = diagnose(&BTreeSet::from([
            spec("ID-a", &["ID-b"]),
            spec("ID-b", &["ID-a"]),
        ]));
        assert!(diag.missing_deps.is_empty(), "{:?}", diag.missing_deps);
        // Canonical form: lex-smallest first ("ID-a"), closed loop.
        assert_eq!(diag.cycles, vec![vec!["ID-a", "ID-b", "ID-a"]]);
    }

    #[test]
    fn diagnose_three_cycle_reports_full_path() {
        let diag = diagnose(&BTreeSet::from([
            spec("ID-a", &["ID-b"]),
            spec("ID-b", &["ID-c"]),
            spec("ID-c", &["ID-a"]),
        ]));
        assert!(diag.missing_deps.is_empty());
        assert_eq!(diag.cycles, vec![vec!["ID-a", "ID-b", "ID-c", "ID-a"]]);
    }

    #[test]
    fn diagnose_self_loop_is_a_cycle() {
        let diag = diagnose(&BTreeSet::from([spec("ID-a", &["ID-a"])]));
        assert!(diag.missing_deps.is_empty());
        // Self-loop reports as the node back to itself.
        assert_eq!(diag.cycles, vec![vec!["ID-a", "ID-a"]]);
    }

    #[test]
    fn diagnose_independent_cycles_all_reported() {
        let diag = diagnose(&BTreeSet::from([
            // First disjoint cycle: a → b → a
            spec("ID-a", &["ID-b"]),
            spec("ID-b", &["ID-a"]),
            // Second disjoint cycle: x → y → x
            spec("ID-x", &["ID-y"]),
            spec("ID-y", &["ID-x"]),
        ]));
        assert!(diag.missing_deps.is_empty());
        assert_eq!(
            diag.cycles,
            vec![vec!["ID-a", "ID-b", "ID-a"], vec!["ID-x", "ID-y", "ID-x"],]
        );
    }

    #[test]
    fn diagnose_acyclic_graph_reports_nothing() {
        let diag = diagnose(&BTreeSet::from([
            spec("ID-a", &["ID-b", "ID-c"]),
            spec("ID-b", &["ID-c"]),
            spec("ID-c", &[]),
        ]));
        assert!(diag.is_empty(), "expected no diagnostics, got {:?}", diag);
    }

    #[test]
    fn diagnose_diamond_dependency_no_cycle() {
        // Classic diamond: A depends on B and C, both depend on D. No cycles.
        let diag = diagnose(&BTreeSet::from([
            spec("ID-a", &["ID-b", "ID-c"]),
            spec("ID-b", &["ID-d"]),
            spec("ID-c", &["ID-d"]),
            spec("ID-d", &[]),
        ]));
        assert!(
            diag.cycles.is_empty(),
            "diamond is not a cycle, got {:?}",
            diag.cycles
        );
    }

    #[test]
    fn diagnose_reports_missing_and_cycle_together() {
        // Mixed: cycle a ↔ b, plus a missing dep on c.
        let diag = diagnose(&BTreeSet::from([
            spec("ID-a", &["ID-b", "ID-missing"]),
            spec("ID-b", &["ID-a"]),
        ]));
        assert_eq!(
            diag.missing_deps,
            vec![("ID-a".to_string(), "ID-missing".to_string())]
        );
        // Only the resolvable edge contributes to cycle detection — the
        // missing dep isn't double-counted.
        assert_eq!(diag.cycles, vec![vec!["ID-a", "ID-b", "ID-a"]]);
    }

    #[test]
    fn format_diagnostics_renders_human_readable_lines() {
        let diag = AssemblyDiagnostics {
            missing_deps: vec![("ID-foo".into(), "ID-bar".into())],
            cycles: vec![vec!["ID-a".into(), "ID-b".into(), "ID-a".into()]],
        };
        let out = format_diagnostics(&diag);
        assert!(out.contains("missing dep: crate ID-foo references ID-bar"));
        assert!(out.contains("dep cycle: ID-a → ID-b → ID-a"));
    }
}
