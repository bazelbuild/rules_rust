//! Bootstrap an editor at the Bazel-provisioned rust-analyzer toolchain.
//!
//! `setup` is split into one subcommand per editor:
//!
//!   * `vscode` — writes/merges `.vscode/settings.json` with the
//!     `rust-analyzer.*` keys + `files.excludeDirs` auto-populated from
//!     nested `Cargo.toml` discovery + matching `files.exclude` /
//!     `watcherExclude` / `search.exclude` for the Bazel convenience
//!     symlinks. Source binaries live in `.vscode/.rules_rust_analyzer/`.
//!   * `neovim` — copies the source binaries to `.rules_rust_analyzer/`
//!     at the workspace root (no `.vscode` references) and prints an
//!     `nvim-lspconfig` Lua snippet to stdout for the user to paste.
//!   * `helix` — copies the source binaries to `.helix/.rules_rust_analyzer/`
//!     (Helix already uses `.helix/` for its per-project config) and
//!     prints a `languages.toml` snippet to stdout.
//!   * `print` — copies the source binaries to `.rules_rust_analyzer/`
//!     and prints a generic JSON snippet (the same `rust-analyzer.*`
//!     keys VSCode uses; works with coc.nvim, helix-via-JSON, etc.).
//!
//! Common flags (`--workspace`, `--skip-proc-macro-server`,
//! `--skip-rustfmt`, `--per-package-workspaces`) are declared once at
//! the top level with `global = true` and accepted on any subcommand.
//! See the `Cli` struct below.
//!
//! There are no launcher shell scripts. Editors point directly at:
//!
//!   * **Toolchain binaries** (rust-analyzer LSP, proc-macro server,
//!     rustfmt) by their absolute `output_base/external/...` paths,
//!     resolved at install time via setup's own runfiles and baked
//!     directly into the editor config. Toolchain binaries survive
//!     `bazel clean`; only `bazel clean --expunge` invalidates them, in
//!     which case re-running setup re-resolves.
//!   * **Source binaries** (`discover_bazel_rust_project`, `flycheck`)
//!     are also resolved via setup's runfiles, then *copied* into the
//!     launcher dir. They live in `bazel-out` originally and would be
//!     wiped by a regular `bazel clean`; the copy keeps the editor
//!     config self-contained. These binaries self-locate their cache
//!     and output dirs from `current_exe()` at runtime (see
//!     `gen_rust_project_lib::install_dir`); the toolchain-info JSON
//!     they consume is baked into them at compile time as an env-var
//!     literal (see `gen_rust_project_lib`'s `rustc_env_files` wiring),
//!     so no install-time files follow them.

use std::{fs, path::Path};

use anyhow::{Context, Result};
use camino::{Utf8Path, Utf8PathBuf};
use clap::{Args, Parser, Subcommand};
use log::info;
use runfiles::{rlocation, Runfiles};
use serde_json::{json, Map, Value};

// ---------------------------------------------------------------------------
// Settings-file keys (VSCode JSON)
// ---------------------------------------------------------------------------

const DISCOVER_CONFIG_KEY: &str = "rust-analyzer.workspace.discoverConfig";
const SERVER_PATH_KEY: &str = "rust-analyzer.server.path";
const PROC_MACRO_SRV_KEY: &str = "rust-analyzer.procMacro.server";
const RUSTFMT_OVERRIDE_KEY: &str = "rust-analyzer.rustfmt.overrideCommand";

const FILES_WATCHER_EXCLUDE_KEY: &str = "files.watcherExclude";
const FILES_EXCLUDE_KEY: &str = "files.exclude";
const SEARCH_EXCLUDE_KEY: &str = "search.exclude";

/// `rust-analyzer.files.excludeDirs` — the list of workspace-relative dirs
/// rust-analyzer's filesystem scan should skip. Critical for Bazel-first
/// workspaces because rust-analyzer auto-discovers any `Cargo.toml` it
/// finds in immediate subdirectories of the workspace root and loads each
/// as a separate cargo workspace (in ADDITION to the discoverConfig
/// project). Those extra cargo workspaces:
///   1. Exhaust the inotify watch limit on large repos.
///   2. Slow down indexing of the actual Bazel-project files.
///   3. Can cause cross-workspace file-id confusion that hides codelens
///      / runnables on files the user actually opens.
///
/// We populate this with every `<workspace>/<dir>/Cargo.toml` we find at
/// install time. See [`find_cargo_dirs_to_exclude`].
const FILES_EXCLUDE_DIRS_KEY: &str = "rust-analyzer.files.excludeDirs";

/// Glob that matches Bazel's four convenience symlinks at the workspace
/// root: `bazel-bin/`, `bazel-out/`, `bazel-testlogs/`, and
/// `bazel-<workspace-name>/`. Skipping them is the difference between a
/// happy IDE and one that thrashes the OS file-watch limit on every
/// `bazel build`.
const BAZEL_OUTPUTS_GLOB: &str = "**/bazel-*/**";

// ---------------------------------------------------------------------------
// Launcher dir + source-binary install paths
// ---------------------------------------------------------------------------

/// Subdirectory name used (under the per-IDE launcher root) to hold the
/// source binaries setup copies in. The leading dot keeps tidy file
/// explorers from surfacing it as workspace content; the rules_rust
/// prefix prevents collisions with anything else that might want to drop
/// files into the same parent dir.
const LAUNCHER_SUBDIR: &str = ".rules_rust_analyzer";

// On-disk filenames setup uses for the binaries it copies into the
// launcher dir. Re-exported from `gen_rust_project_lib` so the install
// side and the consumer side (rust_project.rs's flycheck-runnable
// path emitter) agree on extension handling — including the `.exe`
// suffix on Windows.
use gen_rust_project_lib::{DISCOVER_BINARY_FILENAME, FLYCHECK_BINARY_FILENAME};

// Runfiles paths setup looks up via `Runfiles::create()` at install
// time. The `_opt` suffix points at the `opt_executable` wrapper in
// `opt_transition.bzl` — these run on every save / discovery and pay
// off in opt mode.
const DISCOVER_BINARY_RLOCATION: &str =
    "rules_rust/tools/rust_analyzer/discover_bazel_rust_project_opt";
const FLYCHECK_BINARY_RLOCATION: &str = "rules_rust/tools/rust_analyzer/flycheck_opt";

// ---------------------------------------------------------------------------
// CLI
// ---------------------------------------------------------------------------

#[derive(Parser)]
#[command(
    name = "setup",
    about = "Bootstrap an editor at the Bazel rust-analyzer toolchain."
)]
struct Cli {
    /// Workspace root. Defaults to BUILD_WORKSPACE_DIRECTORY (set when
    /// invoked via `bazel run`).
    #[arg(long, env = "BUILD_WORKSPACE_DIRECTORY", global = true)]
    workspace: Option<Utf8PathBuf>,

    /// Skip the proc-macro server key. Useful when the editor's bundled
    /// rust-analyzer already matches the Bazel rustc version.
    #[arg(long, global = true)]
    skip_proc_macro_server: bool,

    /// Skip the rustfmt override key. Useful when the workspace
    /// deliberately wants the host's rustfmt instead of the Bazel one.
    #[arg(long, global = true)]
    skip_rustfmt: bool,

    /// Pass `{arg}` to the discover command so rust-analyzer switches
    /// workspaces to the per-file package. Off by default — the whole
    /// workspace gets indexed as one project, which is simpler and what
    /// most users want. Turn this on for monorepos where indexing the
    /// whole graph hurts LSP responsiveness; the trade-off is that
    /// rust-analyzer reloads (and re-runs discover) every time you jump
    /// to a file in a different package, AND that dependents of the
    /// package you're working on aren't indexed.
    #[arg(long, global = true)]
    per_package_workspaces: bool,

    #[command(subcommand)]
    ide: IdeCmd,
}

#[derive(Subcommand)]
enum IdeCmd {
    /// Write/merge `.vscode/settings.json` and install source binaries
    /// under `.vscode/.rules_rust_analyzer/`.
    Vscode(VscodeArgs),

    /// Install source binaries under `.rules_rust_analyzer/` (no
    /// `.vscode/` references) and print an `nvim-lspconfig` Lua snippet
    /// to stdout.
    Neovim,

    /// Install source binaries under `.helix/.rules_rust_analyzer/` and
    /// print a `languages.toml` snippet to stdout.
    Helix,

    /// Install source binaries under `.rules_rust_analyzer/` and print
    /// the editor-agnostic JSON snippet (same `rust-analyzer.*` keys
    /// VSCode uses; works with coc.nvim and similar JSON-config LSP
    /// clients).
    Print,
}

#[derive(Args)]
struct VscodeArgs {
    /// Settings file to write. Relative paths are resolved under
    /// `--workspace`.
    #[arg(short, long, default_value = ".vscode/settings.json")]
    output: Utf8PathBuf,

    /// Print the would-be-written JSON to stdout instead of writing it.
    #[arg(long)]
    dry_run: bool,

    /// Overwrite the file with just the managed keys instead of merging.
    /// Destroys user keys — use only on a fresh `.vscode/`.
    #[arg(long)]
    replace: bool,
}

// ---------------------------------------------------------------------------
// Entry point + per-IDE dispatch
// ---------------------------------------------------------------------------

fn main() -> Result<()> {
    env_logger::init();
    let Cli {
        workspace,
        skip_proc_macro_server,
        skip_rustfmt,
        per_package_workspaces,
        ide,
    } = Cli::parse();

    let workspace = workspace.unwrap_or_else(|| Utf8PathBuf::from("."));
    let launcher_dir = launcher_dir_for(&workspace, &ide);
    let runfiles = Runfiles::create().context("creating Runfiles for setup")?;
    let toolchain = ToolchainBinaries {
        rust_analyzer: lookup_canonical(&runfiles, env!("RUST_ANALYZER_RLOCATIONPATH"))?,
        proc_macro_srv: lookup_canonical(
            &runfiles,
            env!("RUST_ANALYZER_PROC_MACRO_SRV_RLOCATIONPATH"),
        )?,
        rustfmt: lookup_canonical(&runfiles, env!("RUSTFMT_RLOCATIONPATH"))?,
    };

    install_source_binaries(&launcher_dir, &runfiles)?;

    let ctx = SetupCtx {
        workspace,
        launcher_dir,
        skip_proc_macro_server,
        skip_rustfmt,
        per_package_workspaces,
        toolchain,
    };

    match ide {
        IdeCmd::Vscode(args) => run_vscode(&ctx, args),
        IdeCmd::Neovim => run_neovim(&ctx),
        IdeCmd::Helix => run_helix(&ctx),
        IdeCmd::Print => run_print(&ctx),
    }
}

/// Shared state computed once at startup and threaded through every
/// per-IDE runner.
struct SetupCtx {
    workspace: Utf8PathBuf,
    /// Editor-specific dir setup copies source binaries into. The
    /// discover/flycheck binaries self-locate their cache + output dirs
    /// as siblings of themselves (`<launcher_dir>/cache` and
    /// `<launcher_dir>/output_user_root` respectively).
    launcher_dir: Utf8PathBuf,
    skip_proc_macro_server: bool,
    skip_rustfmt: bool,
    per_package_workspaces: bool,
    /// Canonical absolute paths of the three toolchain binaries, baked
    /// directly into the editor config. See [`ToolchainBinaries`] for
    /// how they're resolved.
    toolchain: ToolchainBinaries,
}

/// Absolute, canonicalized paths to the three toolchain binaries the
/// editor needs to reference. Resolved once in `main` via setup's own
/// runfiles + the `*_RLOCATIONPATH` make-vars (baked at compile time
/// by the `rustc_env` block on setup's BUILD target) + [`fs::canonicalize`]
/// (escapes the runfiles symlink tree — which lives in `bazel-out` and
/// would be wiped by `bazel clean` — and lands at the canonical
/// `output_base/external/...` path that only goes away on
/// `bazel clean --expunge`).
struct ToolchainBinaries {
    rust_analyzer: Utf8PathBuf,
    proc_macro_srv: Utf8PathBuf,
    rustfmt: Utf8PathBuf,
}

fn lookup_runfile(runfiles: &Runfiles, env_path: &str) -> Result<Utf8PathBuf> {
    let pathbuf = rlocation!(runfiles, env_path)
        .with_context(|| format!("rlocation not found: {env_path}"))?;
    Utf8PathBuf::try_from(pathbuf)
        .with_context(|| format!("rlocation {env_path} was not valid UTF-8"))
}

fn lookup_canonical(runfiles: &Runfiles, env_path: &str) -> Result<Utf8PathBuf> {
    let path = lookup_runfile(runfiles, env_path)?;
    let canonical = fs::canonicalize(&path)
        .with_context(|| format!("canonicalizing rlocation {env_path} = {path}"))?;
    Utf8PathBuf::try_from(canonical)
        .with_context(|| format!("canonical path for {env_path} was not valid UTF-8"))
}

// ---------------------------------------------------------------------------
// VSCode subcommand
// ---------------------------------------------------------------------------

fn run_vscode(ctx: &SetupCtx, args: VscodeArgs) -> Result<()> {
    let output_path = if args.output.is_absolute() {
        args.output.clone()
    } else {
        ctx.workspace.join(&args.output)
    };

    let managed = vscode_managed_keys(ctx, &ctx.launcher_dir);
    let key_count = managed.len();

    let merged = if args.replace {
        let mut obj = Map::new();
        for (k, v) in managed {
            obj.insert(k, realize_managed(v));
        }
        Value::Object(obj)
    } else {
        merge_into_existing(&output_path, managed)?
    };

    if args.dry_run {
        println!("=== {output_path} ===");
        println!("{}", serde_json::to_string_pretty(&merged)?);
        return Ok(());
    }

    write_settings(output_path.as_std_path(), &merged)?;
    info!(
        "{} {} key(s) in {output_path}",
        if args.replace { "Wrote" } else { "Merged" },
        key_count,
    );
    Ok(())
}

// ---------------------------------------------------------------------------
// Neovim subcommand
// ---------------------------------------------------------------------------

fn run_neovim(ctx: &SetupCtx) -> Result<()> {
    let snippet = generate_neovim_lua(ctx, &ctx.launcher_dir);
    print_snippet_with_banner("Add this to your init.lua (nvim-lspconfig):", &snippet);
    Ok(())
}

// ---------------------------------------------------------------------------
// Helix subcommand
// ---------------------------------------------------------------------------

fn run_helix(ctx: &SetupCtx) -> Result<()> {
    let snippet = generate_helix_toml(ctx, &ctx.launcher_dir);
    print_snippet_with_banner(
        "Add this to .helix/languages.toml at the workspace root:",
        &snippet,
    );
    Ok(())
}

// ---------------------------------------------------------------------------
// Print subcommand
// ---------------------------------------------------------------------------

fn run_print(ctx: &SetupCtx) -> Result<()> {
    let snippet = generate_settings_json(ctx, &ctx.launcher_dir);
    print_snippet_with_banner(
        "Add this to your editor's rust-analyzer settings (coc-settings.json, etc.):",
        &snippet,
    );
    Ok(())
}

// ---------------------------------------------------------------------------
// Source-binary install
// ---------------------------------------------------------------------------

/// Copy the discover binary and the flycheck binary into `dir`. These
/// live in `bazel-out` originally and would be wiped by `bazel clean`;
/// the copy keeps the installation self-contained until the next
/// `bazel clean --expunge` (which removes the toolchain binaries from
/// `output_base` and requires re-running setup anyway).
///
/// The toolchain-info JSON discover used to consume at runtime is no
/// longer copied here — its content is baked into the binary at compile
/// time via an `env!()` literal (see `gen_rust_project_lib`'s
/// `rustc_env_files` wiring on the BUILD target).
fn install_source_binaries(dir: &Utf8Path, runfiles: &Runfiles) -> Result<()> {
    fs::create_dir_all(dir).with_context(|| format!("creating directory {dir}"))?;
    for (rlocation, filename) in [
        (DISCOVER_BINARY_RLOCATION, DISCOVER_BINARY_FILENAME),
        (FLYCHECK_BINARY_RLOCATION, FLYCHECK_BINARY_FILENAME),
    ] {
        let src = lookup_runfile(runfiles, rlocation)?;
        let dest = dir.join(filename);
        fs::copy(&src, &dest).with_context(|| format!("copying {src} -> {dest}"))?;
        set_executable(&dest)?;
    }
    Ok(())
}

#[cfg(unix)]
fn set_executable(path: &Utf8Path) -> Result<()> {
    use std::os::unix::fs::PermissionsExt;
    let mut perms = fs::metadata(path)
        .with_context(|| format!("stat {path}"))?
        .permissions();
    // rwxr-xr-x: rust-analyzer (and the user from a shell) must be able
    // to exec this; group/other read+exec is harmless.
    perms.set_mode(0o755);
    fs::set_permissions(path, perms).with_context(|| format!("chmod {path}"))?;
    Ok(())
}

#[cfg(not(unix))]
fn set_executable(_path: &Utf8Path) -> Result<()> {
    // Windows doesn't use POSIX exec bits; `.bat`/`.exe` extension
    // is the cue for the OS loader.
    Ok(())
}

/// Normalize backslashes to forward slashes. Applied to every path we
/// hand to an editor's config file (settings.json, languages.toml, init.lua,
/// coc-settings.json).
///
/// Why everywhere:
///   * In JSON / Lua / TOML, `\` is an escape character — Windows-native
///     paths (`C:\Users\me\...`) embed as invalid escape sequences and
///     break the parser.
///   * Modern Windows tooling — VSCode, rust-analyzer, bazel.exe — all
///     accept forward slashes universally.
fn to_forward_slashes(path: &str) -> String {
    if cfg!(windows) {
        path.replace('\\', "/")
    } else {
        path.to_owned()
    }
}

// ---------------------------------------------------------------------------
// Editor-relative defaults
// ---------------------------------------------------------------------------

/// Resolve the launcher directory for a given IDE subcommand. Setup is
/// authoritative over the binary install dir / cache / output_user_root
/// placement; every downstream default is computed by appending to
/// whatever this returns.
fn launcher_dir_for(workspace: &Utf8Path, ide: &IdeCmd) -> Utf8PathBuf {
    match ide {
        IdeCmd::Vscode(args) => {
            let output_path = if args.output.is_absolute() {
                args.output.clone()
            } else {
                workspace.join(&args.output)
            };
            output_path
                .parent()
                .map(|p| p.to_owned())
                .unwrap_or_else(|| workspace.join(".vscode"))
                .join(LAUNCHER_SUBDIR)
        }
        IdeCmd::Helix => workspace.join(".helix").join(LAUNCHER_SUBDIR),
        // Neovim has no canonical per-project dotdir; print covers
        // editor-agnostic JSON-config LSP clients. Both land at the
        // workspace root.
        IdeCmd::Neovim | IdeCmd::Print => workspace.join(LAUNCHER_SUBDIR),
    }
}

// ---------------------------------------------------------------------------
// Cargo.toml scan (for files.excludeDirs auto-population)
// ---------------------------------------------------------------------------

/// Scan the workspace root one level deep for `<dir>/Cargo.toml` and
/// return the subdirectory names. These match exactly the files that
/// rust-analyzer's `ProjectManifest::discover` finds via
/// `find_cargo_toml_in_child_dir` — which only goes one level down to
/// avoid runaway scans (see rust-analyzer's `crates/project-model/src/
/// lib.rs::find_cargo_toml_in_child_dir`). Feeding these to
/// `rust-analyzer.files.excludeDirs` is the load-bearing piece that
/// keeps the cargo workspaces from being auto-loaded alongside the
/// discoverConfig project.
///
/// Skip `bazel-*` symlinks — those point into the Bazel output tree
/// and any Cargo.toml found there is an artifact, not a real source
/// manifest the user cares about.
///
/// Returns dir names sorted for deterministic snippet / settings.json
/// output.
fn find_cargo_dirs_to_exclude(workspace_root: &Utf8Path) -> Vec<String> {
    let mut out: Vec<String> = Vec::new();
    let read = match fs::read_dir(workspace_root) {
        Ok(r) => r,
        Err(_) => return out,
    };
    for entry in read.flatten() {
        let Ok(file_type) = entry.file_type() else {
            continue;
        };
        if !file_type.is_dir() {
            continue;
        }
        let Ok(name) = entry.file_name().into_string() else {
            continue;
        };
        if name.starts_with("bazel-") || name.starts_with('.') {
            continue;
        }
        let cargo_toml = entry.path().join("Cargo.toml");
        if cargo_toml.is_file() {
            out.push(name);
        }
    }
    out.sort();
    out
}

// ---------------------------------------------------------------------------
// VSCode settings.json merge
// ---------------------------------------------------------------------------

/// A managed key/value pair plus how to combine it with whatever the user
/// already has under that key.
enum ManagedValue {
    /// Overwrite the whole key — appropriate for scalar / object-shaped
    /// keys like `rust-analyzer.server.path` where the rules_rust value is
    /// the canonical one and stale entries should be replaced.
    Replace(Value),
    /// Dict-merge: ensure the key is an object containing the listed
    /// sub-entries. If the user already has a value for a given glob
    /// pattern we leave it alone — including explicit `false` overrides —
    /// so they can opt out of any individual exclude by setting it to
    /// `false` rather than deleting the entry (which we'd just add back).
    InsertEntries(Vec<(String, Value)>),
    /// List-union: ensure the key is an array containing the listed
    /// values. User entries are preserved; ours are appended only if not
    /// already present (string equality). Removed user entries stay
    /// removed across re-runs — we only ADD, never DELETE.
    InsertListEntries(Vec<Value>),
}

/// VSCode-flavored managed keys, in canonical order.
fn vscode_managed_keys(ctx: &SetupCtx, launcher_dir: &Utf8Path) -> Vec<(String, ManagedValue)> {
    let ra_path = to_forward_slashes(ctx.toolchain.rust_analyzer.as_str());
    let pms_path = to_forward_slashes(ctx.toolchain.proc_macro_srv.as_str());
    let rustfmt_path = to_forward_slashes(ctx.toolchain.rustfmt.as_str());
    let discover_path = to_forward_slashes(launcher_dir.join(DISCOVER_BINARY_FILENAME).as_str());
    let bazel_outputs = || vec![(BAZEL_OUTPUTS_GLOB.to_string(), Value::Bool(true))];
    // `{arg}` opts into per-package workspace switching. See `--per-package-workspaces`.
    let discover_command = if ctx.per_package_workspaces {
        json!([discover_path, "{arg}"])
    } else {
        json!([discover_path])
    };
    let mut out = vec![
        (
            DISCOVER_CONFIG_KEY.to_string(),
            ManagedValue::Replace(json!({
                // Point directly at the discover binary; it self-locates
                // its sibling toolchain JSON from `argv[0]`'s dirname.
                "command": discover_command,
                "progressLabel": "rules_rust",
                "filesToWatch": [
                    "BUILD",
                    "BUILD.bazel",
                    "MODULE.bazel",
                    "WORKSPACE",
                    "WORKSPACE.bazel",
                ],
            })),
        ),
        (
            SERVER_PATH_KEY.to_string(),
            ManagedValue::Replace(Value::String(ra_path)),
        ),
    ];
    if !ctx.skip_proc_macro_server {
        out.push((
            PROC_MACRO_SRV_KEY.to_string(),
            ManagedValue::Replace(Value::String(pms_path)),
        ));
    }
    if !ctx.skip_rustfmt {
        // overrideCommand is an argv array; the toolchain rustfmt takes
        // file contents on stdin and writes formatted output to stdout,
        // which is the contract rust-analyzer expects.
        out.push((
            RUSTFMT_OVERRIDE_KEY.to_string(),
            ManagedValue::Replace(json!([rustfmt_path])),
        ));
    }
    // Three exclude maps share the same Bazel-outputs glob — dict-merged
    // so any user entries (other patterns, explicit `false` overrides)
    // survive untouched.
    out.push((
        FILES_WATCHER_EXCLUDE_KEY.to_string(),
        ManagedValue::InsertEntries(bazel_outputs()),
    ));
    out.push((
        FILES_EXCLUDE_KEY.to_string(),
        ManagedValue::InsertEntries(bazel_outputs()),
    ));
    out.push((
        SEARCH_EXCLUDE_KEY.to_string(),
        ManagedValue::InsertEntries(bazel_outputs()),
    ));
    // rust-analyzer.files.excludeDirs: list-union with the names of every
    // immediate subdirectory that contains a Cargo.toml. See the key's
    // doc comment for why this matters.
    let cargo_dirs = find_cargo_dirs_to_exclude(&ctx.workspace);
    if !cargo_dirs.is_empty() {
        out.push((
            FILES_EXCLUDE_DIRS_KEY.to_string(),
            ManagedValue::InsertListEntries(cargo_dirs.into_iter().map(Value::String).collect()),
        ));
    }
    out
}

/// Read the existing settings file (if any), apply each managed key per
/// its `ManagedValue` strategy, and return the merged object.
fn merge_into_existing(path: &Utf8Path, managed: Vec<(String, ManagedValue)>) -> Result<Value> {
    let mut object = match fs::read_to_string(path) {
        Ok(content) if content.trim().is_empty() => Map::new(),
        Ok(content) => match serde_json::from_str::<Value>(&content) {
            Ok(Value::Object(map)) => map,
            Ok(other) => {
                anyhow::bail!(
                    "{} is not a JSON object (found {}); refusing to merge. Use --replace to overwrite.",
                    path,
                    match other {
                        Value::Null => "null",
                        Value::Bool(_) => "bool",
                        Value::Number(_) => "number",
                        Value::String(_) => "string",
                        Value::Array(_) => "array",
                        // `Object` handled by the outer Ok(Value::Object(...)) arm.
                        Value::Object(_) => "object",
                    }
                );
            }
            Err(e) => {
                anyhow::bail!(
                    "{} is not valid strict JSON ({}). VSCode tolerates comments and trailing commas, but this tool does not. Either remove the JSONC features or pass --replace.",
                    path,
                    e
                );
            }
        },
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => Map::new(),
        Err(e) => return Err(e).with_context(|| format!("reading {path}")),
    };
    for (k, v) in managed {
        apply_managed(&mut object, k, v);
    }
    Ok(Value::Object(object))
}

fn apply_managed(object: &mut Map<String, Value>, key: String, value: ManagedValue) {
    match value {
        ManagedValue::Replace(v) => {
            object.insert(key, v);
        }
        ManagedValue::InsertEntries(entries) => {
            // Coerce the existing entry to an object. If a user managed to
            // set, say, `files.exclude` to a non-object value, we replace
            // it — VSCode wouldn't accept that anyway.
            let existing = object
                .entry(key)
                .or_insert_with(|| Value::Object(Map::new()));
            if !matches!(existing, Value::Object(_)) {
                *existing = Value::Object(Map::new());
            }
            let Value::Object(map) = existing else {
                unreachable!("just assigned to Value::Object above")
            };
            for (sub_k, sub_v) in entries {
                // `or_insert` preserves any pre-existing entry under the
                // same glob, including explicit `false` overrides — that's
                // how users opt out of an individual exclude without us
                // re-adding it on the next run.
                map.entry(sub_k).or_insert(sub_v);
            }
        }
        ManagedValue::InsertListEntries(entries) => {
            // Same shape-coercion as InsertEntries but for arrays.
            let existing = object
                .entry(key)
                .or_insert_with(|| Value::Array(Vec::new()));
            if !matches!(existing, Value::Array(_)) {
                *existing = Value::Array(Vec::new());
            }
            let Value::Array(arr) = existing else {
                unreachable!("just assigned to Value::Array above")
            };
            for entry in entries {
                if !arr.iter().any(|existing| existing == &entry) {
                    arr.push(entry);
                }
            }
        }
    }
}

/// Materialize a managed value into a fresh object — used by `--replace`,
/// which writes only our keys with no pre-existing context to merge into.
fn realize_managed(value: ManagedValue) -> Value {
    match value {
        ManagedValue::Replace(v) => v,
        ManagedValue::InsertEntries(entries) => {
            let mut m = Map::new();
            for (k, v) in entries {
                m.insert(k, v);
            }
            Value::Object(m)
        }
        ManagedValue::InsertListEntries(entries) => Value::Array(entries),
    }
}

fn write_settings(path: &Path, value: &Value) -> Result<()> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)
            .with_context(|| format!("creating directory {}", parent.display()))?;
    }
    let mut json = serde_json::to_string_pretty(value)?;
    json.push('\n');
    fs::write(path, json).with_context(|| format!("writing {}", path.display()))?;
    Ok(())
}

// ---------------------------------------------------------------------------
// Snippet generators for non-VSCode IDEs
//
// Each format has one main template constant and three optional sub-block
// constants (proc-macro / rustfmt / files.excludeDirs). The generator
// resolves each sub-block to a string (substituted-or-empty) and then does
// a final pass on the main template. Reads top-to-bottom in the format
// it's emitting — `cargo expand` or `cat`-friendly during review.
//
// Placeholders are `__SHOUTING_SNAKE__` everywhere. The substitution is a
// literal string replace, so paths must not contain the placeholder
// strings themselves (in practice never true).
// ---------------------------------------------------------------------------

// Universal placeholders used across all snippet templates.
const TPL_RA_LAUNCHER: &str = "__RA_LAUNCHER__";
const TPL_DISCOVER_LAUNCHER: &str = "__DISCOVER_LAUNCHER__";
const TPL_PMS_LAUNCHER: &str = "__PMS_LAUNCHER__";
const TPL_RUSTFMT_LAUNCHER: &str = "__RUSTFMT_LAUNCHER__";
// `__EXCLUDE_ENTRIES__` is filled with the format-appropriate comma-
// separated string list (`"a", "b"` for Lua/TOML/JSON — same syntax in
// all three since they all quote with `"`).
const TPL_EXCLUDE_ENTRIES: &str = "__EXCLUDE_ENTRIES__";
// `__DISCOVER_PER_PACKAGE_ARG__` is filled with either `, "{arg}"` (when
// `--per-package-workspaces` is set) or the empty string. Same syntax
// across Lua/TOML/JSON since `"{arg}"` is a quoted string literal in all
// three formats.
const TPL_DISCOVER_PER_PACKAGE_ARG: &str = "__DISCOVER_PER_PACKAGE_ARG__";
const PER_PACKAGE_ARG_SUFFIX: &str = ", \"{arg}\"";
// Optional-block slots in the main templates.
const TPL_OPT_PROC_MACRO: &str = "__OPT_PROC_MACRO__";
const TPL_OPT_RUSTFMT: &str = "__OPT_RUSTFMT__";
const TPL_OPT_EXCLUDES: &str = "__OPT_EXCLUDES__";

// -- Neovim (nvim-lspconfig) Lua --

const NEOVIM_LUA_TEMPLATE: &str = r#"require("lspconfig").rust_analyzer.setup({
  cmd = { "__RA_LAUNCHER__" },
  settings = {
    ["rust-analyzer"] = {
      workspace = {
        discoverConfig = {
          command = { "__DISCOVER_LAUNCHER__"__DISCOVER_PER_PACKAGE_ARG__ },
          progressLabel = "rules_rust",
          filesToWatch = { "BUILD", "BUILD.bazel", "MODULE.bazel", "WORKSPACE", "WORKSPACE.bazel" },
        },
      },
__OPT_PROC_MACRO____OPT_RUSTFMT____OPT_EXCLUDES__      lens = { enable = true },
    },
  },
})
"#;

const NEOVIM_LUA_PROC_MACRO: &str = r#"      procMacro = {
        server = "__PMS_LAUNCHER__",
      },
"#;

const NEOVIM_LUA_RUSTFMT: &str = r#"      rustfmt = {
        overrideCommand = { "__RUSTFMT_LAUNCHER__" },
      },
"#;

const NEOVIM_LUA_EXCLUDES: &str = r#"      files = {
        excludeDirs = { __EXCLUDE_ENTRIES__ },
      },
"#;

// -- Helix languages.toml --

const HELIX_TOML_TEMPLATE: &str = r#"[language-server.rust-analyzer]
command = "__RA_LAUNCHER__"

[language-server.rust-analyzer.config.rust-analyzer.workspace.discoverConfig]
command = ["__DISCOVER_LAUNCHER__"__DISCOVER_PER_PACKAGE_ARG__]
progressLabel = "rules_rust"
filesToWatch = ["BUILD", "BUILD.bazel", "MODULE.bazel", "WORKSPACE", "WORKSPACE.bazel"]
__OPT_PROC_MACRO____OPT_RUSTFMT____OPT_EXCLUDES__
[language-server.rust-analyzer.config.rust-analyzer.lens]
enable = true
"#;

const HELIX_TOML_PROC_MACRO: &str = r#"
[language-server.rust-analyzer.config.rust-analyzer.procMacro]
server = "__PMS_LAUNCHER__"
"#;

const HELIX_TOML_RUSTFMT: &str = r#"
[language-server.rust-analyzer.config.rust-analyzer.rustfmt]
overrideCommand = ["__RUSTFMT_LAUNCHER__"]
"#;

const HELIX_TOML_EXCLUDES: &str = r#"
[language-server.rust-analyzer.config.rust-analyzer.files]
excludeDirs = [__EXCLUDE_ENTRIES__]
"#;

// -- Editor-agnostic JSON (coc.nvim, vim-lsp, ALE, ...) --
//
// JSON's trailing-comma intolerance is the awkward part: each optional
// block ends with `,\n  ` so it slots between an existing comma-terminated
// line and the next un-comma'd key. The final unconditional key
// (`lens.enable`) has no trailing comma so the object closes cleanly
// whether or not any optionals fire.

const SETTINGS_JSON_TEMPLATE: &str = r#"{
  "rust-analyzer.server.path": "__RA_LAUNCHER__",
  "rust-analyzer.workspace.discoverConfig": {
    "command": ["__DISCOVER_LAUNCHER__"__DISCOVER_PER_PACKAGE_ARG__],
    "progressLabel": "rules_rust",
    "filesToWatch": ["BUILD", "BUILD.bazel", "MODULE.bazel", "WORKSPACE", "WORKSPACE.bazel"]
  },
  __OPT_PROC_MACRO____OPT_RUSTFMT____OPT_EXCLUDES__"rust-analyzer.lens.enable": true
}
"#;

const SETTINGS_JSON_PROC_MACRO: &str = r#""rust-analyzer.procMacro.server": "__PMS_LAUNCHER__",
  "#;

const SETTINGS_JSON_RUSTFMT: &str = r#""rust-analyzer.rustfmt.overrideCommand": ["__RUSTFMT_LAUNCHER__"],
  "#;

const SETTINGS_JSON_EXCLUDES: &str = r#""rust-analyzer.files.excludeDirs": [__EXCLUDE_ENTRIES__],
  "#;

// -- Helpers shared by all three generators --

/// Bracket a printed snippet with a banner on stderr so the user can
/// distinguish setup's own narration from the snippet itself.
fn print_snippet_with_banner(banner: &str, snippet: &str) {
    eprintln!("\n========== {banner} ==========");
    println!("{snippet}");
    eprintln!("========== end ==========\n");
}

/// Format the cargo-excludes list for the `__EXCLUDE_ENTRIES__`
/// placeholder. All three target formats (Lua / TOML / JSON) quote
/// strings with `"` and separate with `, ` — same output works
/// everywhere.
fn cargo_excludes_as_quoted_list(ctx: &SetupCtx) -> Option<String> {
    let excludes = find_cargo_dirs_to_exclude(&ctx.workspace);
    if excludes.is_empty() {
        None
    } else {
        Some(
            excludes
                .iter()
                .map(|d| format!("{d:?}"))
                .collect::<Vec<_>>()
                .join(", "),
        )
    }
}

/// Resolve one of the three optional blocks. If `enabled`, run
/// `substitute` on the block template; otherwise return empty.
fn opt_block(enabled: bool, block: &str, substitute: impl FnOnce(&str) -> String) -> String {
    if enabled {
        substitute(block)
    } else {
        String::new()
    }
}

/// Resolve the `__DISCOVER_PER_PACKAGE_ARG__` placeholder content. Returns
/// `, "{arg}"` (suffix to the discover-command array) when per-package
/// workspaces are on, empty string otherwise.
fn per_package_suffix(ctx: &SetupCtx) -> &'static str {
    if ctx.per_package_workspaces {
        PER_PACKAGE_ARG_SUFFIX
    } else {
        ""
    }
}

// -- Generators --

/// The four forward-slashed absolute paths every editor snippet
/// (Neovim Lua, Helix TOML, JSON) needs. Three come from the toolchain
/// directly; `discover` is at `<launcher_dir>/discover_bazel_rust_project`
/// (setup copied it there). Precomputed once per generator call so the
/// optional-block closures can borrow strings instead of re-running
/// `to_forward_slashes` each time.
struct SnippetPaths {
    ra: String,
    pms: String,
    rustfmt: String,
    discover: String,
}

impl SnippetPaths {
    fn for_ctx(ctx: &SetupCtx, launcher_dir: &Utf8Path) -> Self {
        Self {
            ra: to_forward_slashes(ctx.toolchain.rust_analyzer.as_str()),
            pms: to_forward_slashes(ctx.toolchain.proc_macro_srv.as_str()),
            rustfmt: to_forward_slashes(ctx.toolchain.rustfmt.as_str()),
            discover: to_forward_slashes(launcher_dir.join(DISCOVER_BINARY_FILENAME).as_str()),
        }
    }
}

/// Render a snippet `main_template` plus three optional sub-templates
/// (proc-macro, rustfmt, excludes) under their `TPL_OPT_*`
/// placeholders. Shared by the three per-editor generators — they
/// differ only in their template constants.
fn render_snippet(
    ctx: &SetupCtx,
    paths: &SnippetPaths,
    main_template: &str,
    proc_macro_template: &str,
    rustfmt_template: &str,
    excludes_template: &str,
) -> String {
    let proc_macro = opt_block(!ctx.skip_proc_macro_server, proc_macro_template, |t| {
        t.replace(TPL_PMS_LAUNCHER, &paths.pms)
    });
    let rustfmt = opt_block(!ctx.skip_rustfmt, rustfmt_template, |t| {
        t.replace(TPL_RUSTFMT_LAUNCHER, &paths.rustfmt)
    });
    let excludes = match cargo_excludes_as_quoted_list(ctx) {
        Some(entries) => excludes_template.replace(TPL_EXCLUDE_ENTRIES, &entries),
        None => String::new(),
    };
    main_template
        .replace(TPL_RA_LAUNCHER, &paths.ra)
        .replace(TPL_DISCOVER_LAUNCHER, &paths.discover)
        .replace(TPL_DISCOVER_PER_PACKAGE_ARG, per_package_suffix(ctx))
        .replace(TPL_OPT_PROC_MACRO, &proc_macro)
        .replace(TPL_OPT_RUSTFMT, &rustfmt)
        .replace(TPL_OPT_EXCLUDES, &excludes)
}

/// `nvim-lspconfig` Lua snippet. The user pastes this into their
/// `init.lua` (or similar). Absolute paths are baked in at install
/// time — re-run `setup neovim` if the workspace moves.
fn generate_neovim_lua(ctx: &SetupCtx, launcher_dir: &Utf8Path) -> String {
    let paths = SnippetPaths::for_ctx(ctx, launcher_dir);
    render_snippet(
        ctx,
        &paths,
        NEOVIM_LUA_TEMPLATE,
        NEOVIM_LUA_PROC_MACRO,
        NEOVIM_LUA_RUSTFMT,
        NEOVIM_LUA_EXCLUDES,
    )
}

/// Helix `languages.toml` snippet. Pasted under
/// `.helix/languages.toml`. Absolute paths baked in (Helix's TOML
/// parser doesn't expand env or workspace vars).
fn generate_helix_toml(ctx: &SetupCtx, launcher_dir: &Utf8Path) -> String {
    let paths = SnippetPaths::for_ctx(ctx, launcher_dir);
    render_snippet(
        ctx,
        &paths,
        HELIX_TOML_TEMPLATE,
        HELIX_TOML_PROC_MACRO,
        HELIX_TOML_RUSTFMT,
        HELIX_TOML_EXCLUDES,
    )
}

/// Editor-agnostic JSON snippet using the standard `rust-analyzer.*`
/// keys. Works with coc.nvim (`coc-settings.json`), helix-via-JSON,
/// vim-lsp, etc. — anything that lets you set `rust-analyzer` settings
/// as JSON.
fn generate_settings_json(ctx: &SetupCtx, launcher_dir: &Utf8Path) -> String {
    let paths = SnippetPaths::for_ctx(ctx, launcher_dir);
    render_snippet(
        ctx,
        &paths,
        SETTINGS_JSON_TEMPLATE,
        SETTINGS_JSON_PROC_MACRO,
        SETTINGS_JSON_RUSTFMT,
        SETTINGS_JSON_EXCLUDES,
    )
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    fn dummy_toolchain() -> ToolchainBinaries {
        ToolchainBinaries {
            rust_analyzer: Utf8PathBuf::from("/obase/external/ra/rust-analyzer"),
            proc_macro_srv: Utf8PathBuf::from("/obase/external/ra/proc-macro-srv"),
            rustfmt: Utf8PathBuf::from("/obase/external/rfmt/rustfmt"),
        }
    }

    fn dummy_ctx() -> (SetupCtx, Utf8PathBuf) {
        let workspace = Utf8PathBuf::from("/ws");
        let launcher_dir = workspace.join(".vscode").join(LAUNCHER_SUBDIR);
        let ctx = SetupCtx {
            workspace,
            launcher_dir: launcher_dir.clone(),
            skip_proc_macro_server: false,
            skip_rustfmt: false,
            per_package_workspaces: false,
            toolchain: dummy_toolchain(),
        };
        (ctx, launcher_dir)
    }

    /// Pull a `Replace`-flavored value out of a `(key, ManagedValue)` list
    /// by key. Panics if missing or if the entry uses one of the merge
    /// strategies.
    fn replace_value<'a>(keys: &'a [(String, ManagedValue)], key: &str) -> &'a Value {
        let entry = keys
            .iter()
            .find(|(k, _)| k == key)
            .unwrap_or_else(|| panic!("missing managed key {key}"));
        match &entry.1 {
            ManagedValue::Replace(v) => v,
            ManagedValue::InsertEntries(_) | ManagedValue::InsertListEntries(_) => {
                panic!("expected Replace strategy for {key}")
            }
        }
    }

    #[test]
    fn merge_preserves_user_keys() {
        let (ctx, launcher_dir) = dummy_ctx();
        let tmp = std::env::temp_dir().join(format!("setup_test_{}", std::process::id()));
        std::fs::create_dir_all(&tmp).unwrap();
        let path = Utf8PathBuf::try_from(tmp.join("settings.json")).unwrap();
        fs::write(
            &path,
            r#"{"editor.tabSize": 4, "rust-analyzer.server.path": "old"}"#,
        )
        .unwrap();
        let merged = merge_into_existing(&path, vscode_managed_keys(&ctx, &launcher_dir)).unwrap();
        let obj = merged.as_object().unwrap();
        // User key preserved
        assert_eq!(obj.get("editor.tabSize"), Some(&json!(4)));
        // Managed key overwritten and points at the canonical toolchain path.
        assert_eq!(
            obj.get(SERVER_PATH_KEY).unwrap().as_str().unwrap(),
            "/obase/external/ra/rust-analyzer"
        );
        // discoverConfig present
        assert!(obj.get(DISCOVER_CONFIG_KEY).is_some());
        let _ = std::fs::remove_dir_all(&tmp);
    }

    #[test]
    fn merge_handles_missing_file() {
        let (ctx, launcher_dir) = dummy_ctx();
        let tmp = std::env::temp_dir().join(format!("setup_test2_{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&tmp);
        let path = Utf8PathBuf::try_from(tmp.join("settings.json")).unwrap();
        let merged = merge_into_existing(&path, vscode_managed_keys(&ctx, &launcher_dir)).unwrap();
        let obj = merged.as_object().unwrap();
        assert!(obj.contains_key(DISCOVER_CONFIG_KEY));
        assert!(obj.contains_key(SERVER_PATH_KEY));
        assert!(obj.contains_key(PROC_MACRO_SRV_KEY));
        assert!(obj.contains_key(RUSTFMT_OVERRIDE_KEY));
        assert!(obj.contains_key(FILES_WATCHER_EXCLUDE_KEY));
        assert!(obj.contains_key(FILES_EXCLUDE_KEY));
        assert!(obj.contains_key(SEARCH_EXCLUDE_KEY));
    }

    #[test]
    fn skip_proc_macro_server_drops_one_key() {
        let (mut ctx, launcher_dir) = dummy_ctx();
        let with_srv = vscode_managed_keys(&ctx, &launcher_dir);
        ctx.skip_proc_macro_server = true;
        let without_srv = vscode_managed_keys(&ctx, &launcher_dir);
        // 4 rust-analyzer keys + 3 exclude maps = 7 total.
        assert_eq!(with_srv.len(), 7);
        assert_eq!(without_srv.len(), 6);
        assert!(!without_srv.iter().any(|(k, _)| k == PROC_MACRO_SRV_KEY));
    }

    #[test]
    fn skip_rustfmt_drops_only_the_rustfmt_key() {
        let (mut ctx, launcher_dir) = dummy_ctx();
        let with_fmt = vscode_managed_keys(&ctx, &launcher_dir);
        ctx.skip_rustfmt = true;
        let without_fmt = vscode_managed_keys(&ctx, &launcher_dir);
        assert_eq!(with_fmt.len(), 7);
        assert_eq!(without_fmt.len(), 6);
        assert!(!without_fmt.iter().any(|(k, _)| k == RUSTFMT_OVERRIDE_KEY));
        // The proc-macro key still rides along.
        assert!(without_fmt.iter().any(|(k, _)| k == PROC_MACRO_SRV_KEY));
    }

    #[test]
    fn rustfmt_override_is_argv_array_pointing_at_toolchain() {
        let (ctx, launcher_dir) = dummy_ctx();
        let keys = vscode_managed_keys(&ctx, &launcher_dir);
        let val = replace_value(&keys, RUSTFMT_OVERRIDE_KEY);
        let arr = val.as_array().unwrap();
        assert_eq!(arr.len(), 1);
        assert_eq!(arr[0].as_str().unwrap(), "/obase/external/rfmt/rustfmt");
    }

    #[test]
    fn vscode_managed_keys_emit_toolchain_paths_and_discover_in_launcher_dir() {
        let (ctx, launcher_dir) = dummy_ctx();
        let keys = vscode_managed_keys(&ctx, &launcher_dir);
        // The four rust-analyzer.* path keys map to the dummy toolchain
        // absolutes; discoverConfig.command[0] is rooted at launcher_dir.
        assert_eq!(
            replace_value(&keys, SERVER_PATH_KEY).as_str().unwrap(),
            "/obase/external/ra/rust-analyzer"
        );
        assert_eq!(
            replace_value(&keys, PROC_MACRO_SRV_KEY).as_str().unwrap(),
            "/obase/external/ra/proc-macro-srv"
        );
        let discover_cmd = replace_value(&keys, DISCOVER_CONFIG_KEY)
            .get("command")
            .and_then(|v| v.as_array())
            .expect("command must be an array");
        assert_eq!(
            discover_cmd[0].as_str().unwrap(),
            format!("/ws/.vscode/.rules_rust_analyzer/{DISCOVER_BINARY_FILENAME}")
        );
    }

    #[test]
    fn watcher_exclude_dict_merges_with_user_entries() {
        let (ctx, launcher_dir) = dummy_ctx();
        let tmp = std::env::temp_dir().join(format!("setup_excludes_test_{}", std::process::id()));
        std::fs::create_dir_all(&tmp).unwrap();
        let path = Utf8PathBuf::try_from(tmp.join("settings.json")).unwrap();
        // User already had one watcher exclude AND an explicit `false`
        // override of our glob. Both must survive intact.
        fs::write(
            &path,
            r#"{
              "files.watcherExclude": {
                "**/node_modules/**": true,
                "**/bazel-*/**": false
              }
            }"#,
        )
        .unwrap();
        let merged = merge_into_existing(&path, vscode_managed_keys(&ctx, &launcher_dir)).unwrap();
        let watchers = merged
            .as_object()
            .unwrap()
            .get(FILES_WATCHER_EXCLUDE_KEY)
            .unwrap()
            .as_object()
            .unwrap();
        // User's other entry preserved.
        assert_eq!(watchers.get("**/node_modules/**"), Some(&json!(true)));
        // User's explicit override of our glob preserved — we did NOT
        // overwrite their `false` with our `true`.
        assert_eq!(watchers.get(BAZEL_OUTPUTS_GLOB), Some(&json!(false)));
        let _ = std::fs::remove_dir_all(&tmp);
    }

    #[test]
    fn find_cargo_dirs_finds_immediate_subdirs_with_cargo_toml() {
        // Mock workspace: rules_rust-ish layout with two cargo dirs to
        // exclude, one Bazel dir to ignore, one dot-dir to ignore, and
        // one ordinary dir without Cargo.toml that should be left alone.
        let tmp = std::env::temp_dir().join(format!("setup_cargo_dirs_{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&tmp);
        std::fs::create_dir_all(&tmp).unwrap();
        for d in ["cargo", "crate_universe", "bazel-bin", ".git", "util"] {
            std::fs::create_dir_all(tmp.join(d)).unwrap();
        }
        for d in ["cargo", "crate_universe", "bazel-bin"] {
            std::fs::write(tmp.join(d).join("Cargo.toml"), "[package]\nname=\"x\"\n").unwrap();
        }
        // `rust/runfiles/Cargo.toml` exists in rules_rust but `rust/`
        // itself has no Cargo.toml at one level — verify we DON'T add
        // `rust` (since rust-analyzer's one-level scan won't find it
        // either, no point excluding it).
        std::fs::create_dir_all(tmp.join("rust").join("runfiles")).unwrap();
        std::fs::write(
            tmp.join("rust").join("runfiles").join("Cargo.toml"),
            "[package]\nname=\"runfiles\"\n",
        )
        .unwrap();

        let dirs = find_cargo_dirs_to_exclude(&Utf8PathBuf::try_from(tmp.clone()).unwrap());
        assert_eq!(
            dirs,
            vec!["cargo".to_string(), "crate_universe".to_string()]
        );
        let _ = std::fs::remove_dir_all(&tmp);
    }

    #[test]
    fn insert_list_entries_preserves_user_values_and_dedupes() {
        let mut obj = Map::new();
        obj.insert(
            "rust-analyzer.files.excludeDirs".to_string(),
            json!(["user_dir", "cargo"]),
        );
        apply_managed(
            &mut obj,
            "rust-analyzer.files.excludeDirs".to_string(),
            ManagedValue::InsertListEntries(vec![json!("cargo"), json!("crate_universe")]),
        );
        let arr = obj
            .get("rust-analyzer.files.excludeDirs")
            .unwrap()
            .as_array()
            .unwrap();
        // user_dir preserved, cargo not duplicated, crate_universe added.
        assert_eq!(
            arr,
            &vec![json!("user_dir"), json!("cargo"), json!("crate_universe")]
        );
    }

    #[test]
    fn launcher_dir_for_picks_editor_specific_subdir() {
        let ws = Utf8PathBuf::from("/workspace");
        assert_eq!(
            launcher_dir_for(
                &ws,
                &IdeCmd::Vscode(VscodeArgs {
                    output: Utf8PathBuf::from(".vscode/settings.json"),
                    dry_run: false,
                    replace: false,
                }),
            ),
            Utf8PathBuf::from("/workspace/.vscode/.rules_rust_analyzer"),
        );
        assert_eq!(
            launcher_dir_for(&ws, &IdeCmd::Helix),
            Utf8PathBuf::from("/workspace/.helix/.rules_rust_analyzer"),
        );
        assert_eq!(
            launcher_dir_for(&ws, &IdeCmd::Neovim),
            Utf8PathBuf::from("/workspace/.rules_rust_analyzer"),
        );
        assert_eq!(
            launcher_dir_for(&ws, &IdeCmd::Print),
            Utf8PathBuf::from("/workspace/.rules_rust_analyzer"),
        );
    }

    #[test]
    fn launcher_dir_for_vscode_honors_custom_output() {
        let ws = Utf8PathBuf::from("/workspace");
        // Custom output path → launcher dir sits alongside it.
        let custom = IdeCmd::Vscode(VscodeArgs {
            output: Utf8PathBuf::from(".custom/conf.json"),
            dry_run: false,
            replace: false,
        });
        assert_eq!(
            launcher_dir_for(&ws, &custom),
            Utf8PathBuf::from("/workspace/.custom/.rules_rust_analyzer"),
        );
    }

    #[test]
    fn neovim_snippet_contains_toolchain_and_discover_paths_and_lens_enable() {
        let (ctx, _) = dummy_ctx();
        let launcher_dir = ctx.workspace.join(LAUNCHER_SUBDIR);
        let snippet = generate_neovim_lua(&ctx, &launcher_dir);
        assert!(snippet.contains("require(\"lspconfig\").rust_analyzer.setup"));
        // rust-analyzer LSP from the toolchain.
        assert!(snippet.contains("/obase/external/ra/rust-analyzer"));
        // discover binary from the launcher dir.
        assert!(snippet.contains("/ws/.rules_rust_analyzer/discover_bazel_rust_project"));
        assert!(snippet.contains("lens = { enable = true }"));
    }

    #[test]
    fn helix_snippet_uses_toml_section_headers() {
        let (ctx, _) = dummy_ctx();
        let launcher_dir = ctx.workspace.join(".helix").join(LAUNCHER_SUBDIR);
        let snippet = generate_helix_toml(&ctx, &launcher_dir);
        assert!(snippet.contains("[language-server.rust-analyzer]"));
        assert!(snippet.contains(
            "[language-server.rust-analyzer.config.rust-analyzer.workspace.discoverConfig]"
        ));
        // rust-analyzer LSP path comes from the toolchain.
        assert!(snippet.contains("/obase/external/ra/rust-analyzer"));
        // discover sits next to the helix-specific launcher dir.
        assert!(snippet.contains("/ws/.helix/.rules_rust_analyzer/discover_bazel_rust_project"));
    }

    #[test]
    fn print_snippet_is_valid_json() {
        let (ctx, _) = dummy_ctx();
        let launcher_dir = ctx.workspace.join(LAUNCHER_SUBDIR);
        let snippet = generate_settings_json(&ctx, &launcher_dir);
        let parsed: Value = serde_json::from_str(&snippet).expect("snippet must be valid JSON");
        let obj = parsed.as_object().unwrap();
        assert!(obj.contains_key(SERVER_PATH_KEY));
        assert!(obj.contains_key(DISCOVER_CONFIG_KEY));
        assert!(obj.contains_key(PROC_MACRO_SRV_KEY));
        assert!(obj.contains_key(RUSTFMT_OVERRIDE_KEY));
        // Toolchain paths land in the right JSON keys.
        assert_eq!(
            obj.get(SERVER_PATH_KEY).unwrap().as_str().unwrap(),
            "/obase/external/ra/rust-analyzer"
        );
        assert_eq!(
            obj.get(PROC_MACRO_SRV_KEY).unwrap().as_str().unwrap(),
            "/obase/external/ra/proc-macro-srv"
        );
    }

    /// JSON's trailing-comma intolerance is the trickiest template-
    /// substitution case; verify every combination of dropped optional
    /// blocks still produces valid JSON.
    #[test]
    fn print_snippet_is_valid_json_under_every_skip_combination() {
        for &(skip_pms, skip_fmt) in &[(false, false), (true, false), (false, true), (true, true)] {
            let (mut ctx, _) = dummy_ctx();
            ctx.skip_proc_macro_server = skip_pms;
            ctx.skip_rustfmt = skip_fmt;
            let launcher_dir = ctx.workspace.join(LAUNCHER_SUBDIR);
            let snippet = generate_settings_json(&ctx, &launcher_dir);
            serde_json::from_str::<Value>(&snippet).unwrap_or_else(|e| {
                panic!(
                    "snippet not valid JSON for skip_pms={skip_pms} skip_fmt={skip_fmt}: {e}\n--- snippet ---\n{snippet}"
                )
            });
        }
    }

    /// `skip_*` flags should drop the matching optional sub-block from
    /// the Lua / TOML / JSON output entirely. Verifying via substring
    /// search on the format-specific marker keeps the test simple — if
    /// the marker drifts, both this and the format-specific generator
    /// need to be updated, which is the right coupling.
    #[test]
    fn skip_flags_drop_optional_blocks_from_all_snippets() {
        let (mut ctx, _) = dummy_ctx();
        ctx.skip_proc_macro_server = true;
        ctx.skip_rustfmt = true;
        let launcher_dir = ctx.workspace.join(LAUNCHER_SUBDIR);

        let lua = generate_neovim_lua(&ctx, &launcher_dir);
        assert!(
            !lua.contains("procMacro"),
            "lua: procMacro block leaked\n{lua}"
        );
        assert!(
            !lua.contains("rustfmt = {"),
            "lua: rustfmt block leaked\n{lua}"
        );
        // Discover + RA paths still present.
        assert!(lua.contains("discoverConfig"));

        let toml = generate_helix_toml(&ctx, &launcher_dir);
        assert!(
            !toml.contains("procMacro"),
            "helix: procMacro block leaked\n{toml}"
        );
        assert!(
            !toml.contains("rustfmt]"),
            "helix: rustfmt block leaked\n{toml}"
        );

        let json = generate_settings_json(&ctx, &launcher_dir);
        let parsed: Value = serde_json::from_str(&json).unwrap();
        let obj = parsed.as_object().unwrap();
        assert!(!obj.contains_key(PROC_MACRO_SRV_KEY));
        assert!(!obj.contains_key(RUSTFMT_OVERRIDE_KEY));
        // Sanity: required keys still there.
        assert!(obj.contains_key(SERVER_PATH_KEY));
        assert!(obj.contains_key(DISCOVER_CONFIG_KEY));
    }

    /// Default (per-package off) → discover command has only the binary
    /// path. Opt-in (per-package on) → discover command also has `"{arg}"`,
    /// the rust-analyzer placeholder for the file the user opened.
    #[test]
    fn discover_command_includes_per_package_arg_only_when_opted_in() {
        let (mut ctx, launcher_dir) = dummy_ctx();
        // Default: per_package_workspaces = false.
        let keys = vscode_managed_keys(&ctx, &launcher_dir);
        let cmd = replace_value(&keys, DISCOVER_CONFIG_KEY)
            .get("command")
            .and_then(|v| v.as_array())
            .expect("command must be an array");
        assert_eq!(
            cmd.len(),
            1,
            "default: discover command should be [binary]; got {cmd:?}"
        );

        // Opt-in.
        ctx.per_package_workspaces = true;
        let keys = vscode_managed_keys(&ctx, &launcher_dir);
        let cmd = replace_value(&keys, DISCOVER_CONFIG_KEY)
            .get("command")
            .and_then(|v| v.as_array())
            .expect("command must be an array");
        assert_eq!(
            cmd.len(),
            2,
            "per-package on: discover command should be [binary, \"{{arg}}\"]; got {cmd:?}"
        );
        assert_eq!(cmd[1].as_str(), Some("{arg}"));
    }

    /// Same default-vs-opt-in coverage but for the Lua/TOML/JSON snippets,
    /// since those go through a totally different substitution path.
    #[test]
    fn snippets_include_per_package_arg_only_when_opted_in() {
        let (mut ctx, launcher_dir) = dummy_ctx();
        // Default off.
        let lua = generate_neovim_lua(&ctx, &launcher_dir);
        let toml = generate_helix_toml(&ctx, &launcher_dir);
        let json = generate_settings_json(&ctx, &launcher_dir);
        assert!(
            !lua.contains("\"{arg}\""),
            "lua leaks {{arg}} when per-package off:\n{lua}"
        );
        assert!(
            !toml.contains("\"{arg}\""),
            "toml leaks {{arg}} when per-package off:\n{toml}"
        );
        assert!(
            !json.contains("\"{arg}\""),
            "json leaks {{arg}} when per-package off:\n{json}"
        );
        // No leftover placeholder either way.
        for body in [&lua, &toml, &json] {
            assert!(!body.contains(TPL_DISCOVER_PER_PACKAGE_ARG));
        }
        // Opt-in.
        ctx.per_package_workspaces = true;
        let lua = generate_neovim_lua(&ctx, &launcher_dir);
        let toml = generate_helix_toml(&ctx, &launcher_dir);
        let json = generate_settings_json(&ctx, &launcher_dir);
        assert!(
            lua.contains("\"{arg}\""),
            "lua missing {{arg}} when per-package on:\n{lua}"
        );
        assert!(
            toml.contains("\"{arg}\""),
            "toml missing {{arg}} when per-package on:\n{toml}"
        );
        assert!(
            json.contains("\"{arg}\""),
            "json missing {{arg}} when per-package on:\n{json}"
        );
        // JSON must still parse.
        serde_json::from_str::<Value>(&json).expect("json snippet stays valid with per-package on");
    }

    #[test]
    fn snippet_templates_contain_every_placeholder_they_reference() {
        for (name, body) in [
            ("neovim main", NEOVIM_LUA_TEMPLATE),
            ("helix main", HELIX_TOML_TEMPLATE),
            ("json main", SETTINGS_JSON_TEMPLATE),
        ] {
            for ph in [
                TPL_RA_LAUNCHER,
                TPL_DISCOVER_LAUNCHER,
                TPL_DISCOVER_PER_PACKAGE_ARG,
                TPL_OPT_PROC_MACRO,
                TPL_OPT_RUSTFMT,
                TPL_OPT_EXCLUDES,
            ] {
                assert!(body.contains(ph), "{name} missing {ph}");
            }
        }
        for (name, body) in [
            ("neovim proc_macro", NEOVIM_LUA_PROC_MACRO),
            ("helix proc_macro", HELIX_TOML_PROC_MACRO),
            ("json proc_macro", SETTINGS_JSON_PROC_MACRO),
        ] {
            assert!(
                body.contains(TPL_PMS_LAUNCHER),
                "{name} missing {TPL_PMS_LAUNCHER}"
            );
        }
        for (name, body) in [
            ("neovim rustfmt", NEOVIM_LUA_RUSTFMT),
            ("helix rustfmt", HELIX_TOML_RUSTFMT),
            ("json rustfmt", SETTINGS_JSON_RUSTFMT),
        ] {
            assert!(
                body.contains(TPL_RUSTFMT_LAUNCHER),
                "{name} missing {TPL_RUSTFMT_LAUNCHER}"
            );
        }
        for (name, body) in [
            ("neovim excludes", NEOVIM_LUA_EXCLUDES),
            ("helix excludes", HELIX_TOML_EXCLUDES),
            ("json excludes", SETTINGS_JSON_EXCLUDES),
        ] {
            assert!(
                body.contains(TPL_EXCLUDE_ENTRIES),
                "{name} missing {TPL_EXCLUDE_ENTRIES}"
            );
        }
    }
}
