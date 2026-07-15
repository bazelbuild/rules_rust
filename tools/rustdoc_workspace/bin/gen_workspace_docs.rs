//! Generates merged rustdoc documentation for every crate matched by a set of
//! Bazel target patterns — no rule with an explicit `deps` list is required.
//!
//! ```text
//! bazel run @rules_rust//tools/rustdoc_workspace:gen_workspace_docs -- \
//!     --output <dir> [--config <cfg>]... [<target patterns>...]
//! ```
//!
//! The tool applies `rust_workspace_doc_aspect` to the matched targets, which
//! documents each crate with `rustdoc --merge=none` as regular (cached) build
//! actions. It then merges the cross-crate information with `rustdoc
//! --merge=finalize` and assembles the final documentation tree.
//!
//! The `rustdoc` merge flags are unstable, so both the tool and the aspect
//! build must use a nightly toolchain, e.g. run with
//! `--@rules_rust//rust/toolchain/channel=nightly` (or a `--config` that
//! sets it, forwarded to the aspect build via this tool's `--config` flag).

use std::collections::{BTreeMap, BTreeSet};
use std::fs;
use std::io::{BufRead, BufReader};
use std::path::{Path, PathBuf};
use std::process::Command;

use anyhow::{Context, bail};
use clap::Parser;

/// The repository name to load `rust_workspace_doc_aspect` from.
const ASPECT_REPOSITORY: &str = env!("ASPECT_REPOSITORY");

/// Runfiles location of the current toolchain's `rustdoc` binary.
const RUSTDOC_RLOCATIONPATH: &str = env!("RUSTDOC_RLOCATIONPATH");

/// Runfiles location of the `doc_merger` tree assembly tool.
const DOC_MERGER_RLOCATIONPATH: &str = env!("DOC_MERGER_RLOCATIONPATH");

/// Output directory suffixes produced by `rust_workspace_doc_aspect`.
/// Binary crates use a distinct suffix so name collisions with library
/// crates can be resolved the way `cargo doc` does.
const HTML_SUFFIX: &str = ".rustdoc_workspace/html";
const PARTS_SUFFIX: &str = ".rustdoc_workspace/parts";
const BIN_HTML_SUFFIX: &str = ".rustdoc_workspace_bin/html";
const BIN_PARTS_SUFFIX: &str = ".rustdoc_workspace_bin/parts";

/// Directories in a rustdoc output tree which are not crate documentation.
const NON_CRATE_DIRS: &[&str] = &["src", "static.files", "search.desc", "search.index"];

#[derive(Debug, Parser)]
struct Args {
    /// The directory to write the merged documentation to.
    #[clap(long)]
    output: PathBuf,

    /// A markdown file to render as the documentation landing page instead of
    /// the default list of all crates.
    #[clap(long)]
    index_page: Option<PathBuf>,

    /// An extra flag to pass to the finalizing rustdoc invocation. Flags for
    /// the per-crate invocations are set with
    /// `--@rules_rust//rust/settings:rustdoc_workspace_extra_flag` on the
    /// aspect build instead.
    #[clap(long)]
    rustdoc_flag: Vec<String>,

    /// The path to the Bazel workspace directory. If not specified, uses the
    /// result of `bazel info workspace`.
    #[clap(long, env = "BUILD_WORKSPACE_DIRECTORY")]
    workspace: Option<PathBuf>,

    /// The path to a Bazel binary.
    #[clap(long, default_value = "bazel")]
    bazel: PathBuf,

    /// A config to pass to Bazel invocations with `--config=<config>`.
    #[clap(long)]
    config: Vec<String>,

    /// Space separated list of target patterns to document.
    #[clap(default_value = "@//...")]
    targets: Vec<String>,
}

fn main() -> anyhow::Result<()> {
    let args = Args::parse();
    let bazel_args: Vec<String> = args
        .config
        .iter()
        .map(|config| format!("--config={config}"))
        .collect();

    let output = absolute_path(&args.output)?;

    let workspace = match &args.workspace {
        Some(workspace) => workspace.clone(),
        None => bazel_info(&args.bazel, None, "workspace")?.into(),
    };
    let output_base: PathBuf = bazel_info(&args.bazel, Some(&workspace), "output_base")?.into();
    let execution_root: PathBuf =
        bazel_info(&args.bazel, Some(&workspace), "execution_root")?.into();

    let temp_dir = std::env::temp_dir().join(format!("gen_workspace_docs_{}", std::process::id()));
    fs::create_dir_all(&temp_dir)
        .with_context(|| format!("failed to create {}", temp_dir.display()))?;
    let result = generate_docs(
        &args,
        &bazel_args,
        &workspace,
        &output_base,
        &execution_root,
        &temp_dir,
        &output,
    );
    let _ = fs::remove_dir_all(&temp_dir);
    result
}

fn generate_docs(
    args: &Args,
    bazel_args: &[String],
    workspace: &Path,
    output_base: &Path,
    execution_root: &Path,
    temp_dir: &Path,
    output: &Path,
) -> anyhow::Result<()> {
    // Document every matched crate via the aspect. The per-crate outputs are
    // ordinary build actions: cached, remote-executable and shared with any
    // other consumer of the aspect.
    let bep_file = temp_dir.join("bep.json");
    eprintln!("Building per-crate documentation for {:?}...", args.targets);
    let status = bazel_command(&args.bazel, workspace, output_base)
        .arg("build")
        .args(bazel_args)
        .arg(format!(
            "--aspects={ASPECT_REPOSITORY}//rust:defs.bzl%rust_workspace_doc_aspect"
        ))
        .arg("--output_groups=rustdoc_crate_dir,rustdoc_crate_parts")
        .arg(format!("--build_event_json_file={}", bep_file.display()))
        // Remote builds may default to --remote_download_minimal; the merge
        // steps below read the documentation directories locally, so force
        // them to be downloaded.
        .arg("--remote_download_regex=.*[.]rustdoc_workspace(_bin)?/.*")
        .args(&args.targets)
        .status()
        .with_context(|| format!("failed to spawn `{}`", args.bazel.display()))?;
    if !status.success() {
        bail!("the documentation build failed; see the Bazel output above");
    }

    let (doc_dirs, missing) = collect_doc_dirs(&bep_file, execution_root)?;
    if doc_dirs.is_empty() {
        if missing > 0 {
            bail!(
                "the build produced documentation for {missing} crates but the output \
                 directories are not present locally; they were probably not downloaded \
                 from the remote cache",
            );
        }
        bail!(
            "no crate documentation was produced for {:?}. The rustdoc merge flags require a \
             nightly toolchain: build with `--@rules_rust//rust/toolchain/channel=nightly` \
             (e.g. via a --config forwarded with this tool's --config flag).",
            args.targets,
        );
    }
    if missing > 0 {
        eprintln!(
            "Warning: skipping {missing} crates whose documentation directories are not present locally"
        );
    }

    let (html_dirs, parts_dirs, crate_names) = select_crates(doc_dirs)?;
    eprintln!("Collected documentation for {} crates", crate_names.len());

    // Merge the cross-crate information (search index, crate list, ...) by
    // documenting a stub crate with `--merge=finalize`.
    let mut stub_name = String::from("workspace_docs");
    while crate_names.contains(&stub_name) {
        stub_name.push('_');
    }
    let stub_file = temp_dir.join("workspace_docs_stub.rs");
    fs::write(&stub_file, "//! Merged workspace documentation.\n")
        .with_context(|| format!("failed to write {}", stub_file.display()))?;
    let finalize_dir = temp_dir.join("finalize");

    let rustdoc = rlocation(RUSTDOC_RLOCATIONPATH)?;
    eprintln!("Merging cross-crate information...");
    let mut finalize = Command::new(rustdoc);
    finalize
        .current_dir(workspace)
        .arg(&stub_file)
        .arg(format!("--crate-name={stub_name}"))
        .arg("--edition=2024")
        .arg("-Zunstable-options")
        .arg("--merge=finalize")
        // Generate a rustdoc-styled landing page listing all crates.
        .arg("--enable-index-page")
        .arg("--out-dir")
        .arg(&finalize_dir);
    if let Some(index_page) = &args.index_page {
        finalize.arg("--index-page").arg(absolute_path(index_page)?);
    }
    finalize.args(&args.rustdoc_flag);
    for parts_dir in &parts_dirs {
        finalize.arg("--include-parts-dir").arg(parts_dir);
    }
    let status = finalize.status().context("failed to spawn rustdoc")?;
    if !status.success() {
        bail!("rustdoc --merge=finalize failed");
    }

    // Assemble the final tree: every crate's documentation plus the merged
    // shared files, which are copied last so they win over per-crate copies.
    prepare_output_dir(output)?;
    let doc_merger = rlocation(DOC_MERGER_RLOCATIONPATH)?;
    let mut merge = Command::new(doc_merger);
    merge.arg("--output").arg(output);
    merge.arg("--inputs").args(&html_dirs).arg(&finalize_dir);
    let status = merge.status().context("failed to spawn doc_merger")?;
    if !status.success() {
        bail!("failed to assemble the merged documentation tree");
    }

    println!(
        "Merged documentation for {} crates written to {}",
        crate_names.len(),
        output.display(),
    );
    Ok(())
}

/// The documentation output of one crate.
struct CrateDocs {
    html_dir: PathBuf,
    parts_dir: PathBuf,
    is_bin: bool,
}

/// Find the html/parts directory pairs produced by the aspect in the build's
/// BEP output. Returns the pairs present on disk and the number of crates
/// whose directories were reported but are not present locally.
fn collect_doc_dirs(
    bep_file: &Path,
    execution_root: &Path,
) -> anyhow::Result<(Vec<CrateDocs>, usize)> {
    let file = fs::File::open(bep_file)
        .with_context(|| format!("failed to open {}", bep_file.display()))?;

    let mut pairs: BTreeMap<String, (Option<PathBuf>, Option<PathBuf>, bool)> = BTreeMap::new();
    for line in BufReader::new(file).lines() {
        let line = line.context("failed to read the build event stream")?;
        let Ok(event) = serde_json::from_str::<serde_json::Value>(&line) else {
            continue;
        };
        let Some(files) = event
            .get("namedSetOfFiles")
            .and_then(|set| set.get("files"))
            .and_then(|files| files.as_array())
        else {
            continue;
        };
        for file in files {
            // Reconstruct the local path from the file's name and path prefix
            // rather than its URI: remote builds report bytestream:// URIs.
            let Some(name) = file.get("name").and_then(|name| name.as_str()) else {
                continue;
            };
            let mut path = execution_root.to_path_buf();
            if let Some(prefix) = file.get("pathPrefix").and_then(|prefix| prefix.as_array()) {
                for component in prefix {
                    if let Some(component) = component.as_str() {
                        path.push(component);
                    }
                }
            }
            path.push(name);
            let path = path.to_string_lossy().into_owned();

            // Tree artifacts appear in the BEP as their individual files, so
            // truncate each path to the html/parts directory containing it.
            for (html_suffix, parts_suffix, is_bin) in [
                (HTML_SUFFIX, PARTS_SUFFIX, false),
                (BIN_HTML_SUFFIX, BIN_PARTS_SUFFIX, true),
            ] {
                if let Some(base) = doc_dir_base(&path, html_suffix) {
                    let dir = format!("{base}{html_suffix}");
                    pairs.entry(base).or_insert((None, None, is_bin)).0 = Some(PathBuf::from(dir));
                    break;
                } else if let Some(base) = doc_dir_base(&path, parts_suffix) {
                    let dir = format!("{base}{parts_suffix}");
                    pairs.entry(base).or_insert((None, None, is_bin)).1 = Some(PathBuf::from(dir));
                    break;
                }
            }
        }
    }

    // The same crate can be documented in both the target and the exec
    // configuration (proc-macro dependencies). Prefer the target
    // configuration's copy when both exist.
    let mut chosen: BTreeMap<String, (String, bool)> = BTreeMap::new();
    for base in pairs.keys() {
        let (rel, is_exec) = split_configuration(base);
        match chosen.get(&rel) {
            Some((_, false)) => {}
            _ => {
                chosen.insert(rel, (base.clone(), is_exec));
            }
        }
    }

    let mut doc_dirs = Vec::new();
    let mut missing = 0;
    for (base, _) in chosen.into_values() {
        let (html_dir, parts_dir, is_bin) = &pairs[&base];
        if let (Some(html_dir), Some(parts_dir)) = (html_dir, parts_dir) {
            if html_dir.is_dir() && parts_dir.is_dir() {
                doc_dirs.push(CrateDocs {
                    html_dir: html_dir.clone(),
                    parts_dir: parts_dir.clone(),
                    is_bin: *is_bin,
                });
            } else {
                missing += 1;
            }
        }
    }
    Ok((doc_dirs, missing))
}

/// Split a path below `bazel-out` into its configuration-independent remainder
/// and whether the configuration is an exec configuration.
fn split_configuration(base: &str) -> (String, bool) {
    if let Some(index) = base.find("/bazel-out/") {
        let rest = &base[index + "/bazel-out/".len()..];
        if let Some(slash) = rest.find('/') {
            let configuration = &rest[..slash];
            return (rest[slash..].to_owned(), configuration.contains("-exec"));
        }
    }
    (base.to_owned(), false)
}

/// If `path` is a doc directory with the given suffix or a file inside one,
/// return the path prefix preceding the suffix.
fn doc_dir_base(path: &str, suffix: &str) -> Option<String> {
    if let Some(base) = path.strip_suffix(suffix) {
        return Some(base.to_owned());
    }
    let inner = format!("{suffix}/");
    path.find(&inner).map(|pos| path[..pos].to_owned())
}

/// Resolve crate name collisions the way `cargo doc` does: library crates
/// win, and a binary whose name collides with an already documented crate is
/// skipped with a warning.
fn select_crates(
    doc_dirs: Vec<CrateDocs>,
) -> anyhow::Result<(Vec<PathBuf>, Vec<PathBuf>, BTreeSet<String>)> {
    let (bins, libs): (Vec<_>, Vec<_>) = doc_dirs.into_iter().partition(|docs| docs.is_bin);

    let mut html_dirs = Vec::new();
    let mut parts_dirs = Vec::new();
    let mut names = BTreeSet::new();
    for docs in libs.into_iter().chain(bins) {
        let Some(name) = crate_name_of(&docs.html_dir)? else {
            continue;
        };
        if !names.insert(name.clone()) {
            if docs.is_bin {
                eprintln!(
                    "Warning: not documenting binary crate `{name}`: its output would collide \
                     with another documented crate"
                );
            } else {
                eprintln!("Warning: duplicate library crate name `{name}`; keeping the first");
            }
            continue;
        }
        html_dirs.push(docs.html_dir);
        parts_dirs.push(docs.parts_dir);
    }
    Ok((html_dirs, parts_dirs, names))
}

/// Determine the crate documented in a rustdoc output tree: the subdirectory
/// which contains an `index.html`. (Directories pre-created for cross-crate
/// links are empty, so at most one such subdirectory exists.)
fn crate_name_of(html_dir: &Path) -> anyhow::Result<Option<String>> {
    for entry in
        fs::read_dir(html_dir).with_context(|| format!("failed to read {}", html_dir.display()))?
    {
        let entry = entry?;
        let name = entry.file_name().to_string_lossy().into_owned();
        if NON_CRATE_DIRS.contains(&name.as_str()) {
            continue;
        }
        if entry.path().join("index.html").is_file() {
            return Ok(Some(name));
        }
    }
    eprintln!(
        "Warning: no crate documentation found in {}; skipping",
        html_dir.display()
    );
    Ok(None)
}

/// Resolve a path argument against the directory `bazel run` was invoked from.
fn absolute_path(path: &Path) -> anyhow::Result<PathBuf> {
    if path.is_absolute() {
        return Ok(path.to_owned());
    }
    let base = match std::env::var_os("BUILD_WORKING_DIRECTORY") {
        Some(cwd) => PathBuf::from(cwd),
        None => std::env::current_dir()?,
    };
    Ok(base.join(path))
}

/// Clear the output directory, refusing to delete a directory that does not
/// look like previously generated documentation.
fn prepare_output_dir(output: &Path) -> anyhow::Result<()> {
    if output.exists() {
        let is_empty = output
            .read_dir()
            .with_context(|| format!("failed to read {}", output.display()))?
            .next()
            .is_none();
        if !is_empty && !output.join("crates.js").exists() {
            bail!(
                "refusing to overwrite {}: it is not empty and does not look like generated \
                 documentation (no crates.js)",
                output.display(),
            );
        }
        fs::remove_dir_all(output)
            .with_context(|| format!("failed to remove {}", output.display()))?;
    }
    Ok(())
}

fn rlocation(rlocationpath: &str) -> anyhow::Result<PathBuf> {
    let runfiles = runfiles::Runfiles::create()
        .map_err(|e| anyhow::anyhow!("failed to locate runfiles: {e:?}"))?;
    let path = runfiles::rlocation!(runfiles, rlocationpath)
        .with_context(|| format!("runfile not found: {rlocationpath}"))?;
    if !path.exists() {
        bail!("runfile does not exist: {}", path.display());
    }
    Ok(path)
}

fn bazel_info(bazel: &Path, workspace: Option<&Path>, key: &str) -> anyhow::Result<String> {
    let mut command = Command::new(bazel);
    if let Some(workspace) = workspace {
        command.current_dir(workspace);
    }
    command
        .env_remove("BAZELISK_SKIP_WRAPPER")
        .env_remove("BUILD_WORKING_DIRECTORY")
        .env_remove("BUILD_WORKSPACE_DIRECTORY");
    let output = command
        .arg("info")
        .arg(key)
        .output()
        .with_context(|| format!("failed to spawn `{}`", bazel.display()))?;
    if !output.status.success() {
        bail!(
            "`bazel info {key}` failed:\n{}",
            String::from_utf8_lossy(&output.stderr),
        );
    }
    Ok(String::from_utf8(output.stdout)?.trim().to_owned())
}

/// A Bazel command sharing the server of the invocation that launched this
/// tool: same workspace, explicit `--output_base`, and without the
/// `bazel run` environment which would otherwise confuse the nested client.
fn bazel_command(bazel: &Path, workspace: &Path, output_base: &Path) -> Command {
    let mut command = Command::new(bazel);
    command
        .current_dir(workspace)
        .env_remove("BAZELISK_SKIP_WRAPPER")
        .env_remove("BUILD_WORKING_DIRECTORY")
        .env_remove("BUILD_WORKSPACE_DIRECTORY")
        .arg(format!("--output_base={}", output_base.display()));
    command
}
