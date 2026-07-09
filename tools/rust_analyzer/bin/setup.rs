//! Bootstrap an editor at the Bazel-provisioned rust-analyzer toolchain.
//!
//! The committed editor config — `.vscode/settings.json` or
//! `.code-workspace` — references the launcher dir via VS Code's
//! `${workspaceFolder}` variable, so the file is portable across
//! developers and platforms. The per-developer launcher dir
//! (`<workspace>/.rules_rust_analyzer/`, gitignored) holds:
//!
//!   * **Source binaries** copied straight from runfiles
//!     (`discover_bazel_rust_project.exe`, `flycheck.exe`) — toolchain
//!     JSON they consume is baked at compile time via
//!     `gen_rust_project_lib`'s `rustc_env_files` wiring.
//!   * **Launcher shims** (`rust_analyzer.exe`,
//!     `rust_analyzer_proc_macro_srv.exe`, `rustfmt.exe`) — three
//!     byte-identical copies of `bin/launcher.rs` that look up the
//!     real toolchain path in sibling `launcher_paths.json` and exec.
//!   * **`launcher_paths.json`** — written from the runfiles-resolved
//!     toolchain; the only thing that needs refreshing when the
//!     toolchain moves (rustup update, MODULE.bazel change,
//!     `bazel clean --expunge`).
//!
//! The `.exe` suffix on every platform is intentional: Node's
//! `child_process.spawn` (the rust-analyzer extension's spawner)
//! requires it on Windows, and POSIX `execve` ignores file extensions
//! — same filename works everywhere.

use std::{fs, io, path::Path};

use anyhow::{Context, Result};
use camino::{Utf8Path, Utf8PathBuf};
use clap::{Args, Parser, Subcommand};
use jsonc_parser::{
    cst::{CstInputValue, CstObject, CstRootNode},
    ParseOptions,
};
use log::info;
use runfiles::{rlocation, Runfiles};
use serde_json::{json, Value};

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
use gen_rust_project_lib::{
    user_config, CACHE_SUBDIR, DISCOVER_BINARY_FILENAME, FLYCHECK_BINARY_FILENAME,
};

// Runfiles paths setup looks up via `Runfiles::create()` at install
// time. The `_opt` suffix points at the `opt_executable` wrapper in
// `opt_transition.bzl` — these run on every save / discovery and pay
// off in opt mode.
const DISCOVER_BINARY_RLOCATION: &str =
    "rules_rust/tools/rust_analyzer/discover_bazel_rust_project_opt";
const FLYCHECK_BINARY_RLOCATION: &str = "rules_rust/tools/rust_analyzer/flycheck_opt";

/// Source of truth for the launcher dispatch table: each entry is
/// both the install filename (`<name>.exe`) and the
/// `launcher_paths.json` key the launcher looks itself up under at
/// runtime. Keep in sync with [`toolchain_target_for`].
const LAUNCHER_LOGICAL_NAMES: &[&str] =
    &["rust_analyzer", "rust_analyzer_proc_macro_srv", "rustfmt"];

const LAUNCHER_PATHS_JSON: &str = "launcher_paths.json";

fn launcher_filename(logical: &str) -> String {
    format!("{logical}.exe")
}

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

    /// Opt this developer into per-package workspace switching. Writes
    /// `{"per_package_workspaces": true}` into the local
    /// `<launcher_dir>/user_config.json` — the shared committed
    /// settings file is unaffected. `--no-per-package-workspaces` flips
    /// it back off. Without either flag the file is left alone.
    ///
    /// When on, discover scopes each save to the file's owning
    /// package instead of re-emitting the whole workspace. Turn this
    /// on for monorepos where indexing the whole graph hurts LSP
    /// responsiveness; the trade-off is that rust-analyzer reloads
    /// (and re-runs discover) every time you jump to a file in a
    /// different package, AND that dependents of the package you're
    /// working on aren't indexed.
    #[arg(long, conflicts_with = "no_per_package_workspaces", global = true)]
    per_package_workspaces: bool,

    /// Opt this developer OUT of per-package workspace switching. See
    /// `--per-package-workspaces`.
    #[arg(long, conflicts_with = "per_package_workspaces", global = true)]
    no_per_package_workspaces: bool,

    /// Opt this developer into running clippy on save and streaming
    /// its diagnostics alongside rustc's. Writes
    /// `{"clippy": true}` into the local
    /// `<launcher_dir>/user_config.json` — the shared committed
    /// settings file is unaffected. `--no-clippy` flips it back off.
    /// Without either flag the file is left alone.
    #[arg(long, conflicts_with = "no_clippy", global = true)]
    clippy: bool,

    /// Opt this developer OUT of running clippy on save. See `--clippy`.
    #[arg(long, conflicts_with = "clippy", global = true)]
    no_clippy: bool,

    /// Delete the discover cache (`<launcher-dir>/cache/`) before
    /// running the rest of setup. Use when rust-analyzer is serving
    /// stale symbols after a toolchain change or `bazel clean
    /// --expunge` — the next discover invocation re-populates the
    /// cache from scratch. Does not touch `user_config.json` or
    /// flycheck's `output_user_root/`.
    #[arg(long, global = true)]
    clean: bool,

    /// Persist a per-user override for flycheck's inner Bazel
    /// `--output_user_root`. Writes the path into
    /// `<launcher_dir>/user_config.json` so it survives future setup
    /// runs without touching the shared committed settings file.
    /// The `--output_user_root` flag on the flycheck binary still
    /// wins over this. To clear, delete the `output_user_root` key
    /// from `user_config.json` by hand.
    #[arg(long, global = true, value_name = "PATH")]
    output_user_root: Option<Utf8PathBuf>,

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
    /// `.vscode/settings.json` file to write. Relative paths are
    /// resolved under `--workspace`. Defaults to
    /// `<workspace>/.vscode/settings.json` — always written.
    #[arg(long)]
    settings_json: Option<Utf8PathBuf>,

    /// `.code-workspace` file to also update (in addition to
    /// `settings.json`). When unset, autodetects a unique
    /// `*.code-workspace` at the workspace root; multiple candidates
    /// require this flag to disambiguate. Pass a path to force-target
    /// a specific file even if it doesn't currently exist.
    #[arg(long)]
    code_workspace: Option<Utf8PathBuf>,

    /// Skip the `.code-workspace` write entirely (bypasses autodetect
    /// and any `--code-workspace` value).
    #[arg(long)]
    no_code_workspace: bool,

    /// Key to nest managed `rust-analyzer.*` keys under when writing
    /// to a `.code-workspace`. Defaults to `settings` — the block
    /// VS Code reads window-scoped rust-analyzer configuration from
    /// when the project is opened via the workspace file.
    #[arg(long)]
    settings_key: Option<String>,

    /// Print each would-be-written file to stdout instead of writing.
    #[arg(long)]
    dry_run: bool,

    /// Replace the managed portion of each target file instead of
    /// merging. In `.vscode/settings.json` this overwrites the root;
    /// in `.code-workspace` this overwrites the nested `settings`
    /// object only (sibling `folders` / `tasks` / `extensions` stay
    /// intact — the workspace file wouldn't be usable otherwise).
    #[arg(long)]
    replace: bool,
}

// ---------------------------------------------------------------------------
// Entry point + per-IDE dispatch
// ---------------------------------------------------------------------------

/// Resolve a `--foo` / `--no-foo` flag pair (mutually exclusive via
/// `clap::conflicts_with`) to a tri-state: `Some(true)` for `--foo`,
/// `Some(false)` for `--no-foo`, `None` when neither was given
/// (leave existing state alone).
fn pick_toggle(on: bool, off: bool) -> Option<bool> {
    if on {
        Some(true)
    } else if off {
        Some(false)
    } else {
        None
    }
}

/// Merge the CLI-provided toggles into `<launcher_dir>/user_config.json`.
/// Only the fields the user actually named are touched; anything else
/// in the file is preserved so future keys added by other flags don't
/// get clobbered by an unrelated `setup --clippy` run.
fn apply_user_config_edits(
    launcher_dir: &Utf8Path,
    clippy: Option<bool>,
    per_package_workspaces: Option<bool>,
    output_user_root: Option<Utf8PathBuf>,
) -> Result<()> {
    if clippy.is_none() && per_package_workspaces.is_none() && output_user_root.is_none() {
        return Ok(());
    }
    let mut config = user_config::load(launcher_dir);
    if let Some(v) = clippy {
        config.clippy = v;
    }
    if let Some(v) = per_package_workspaces {
        config.per_package_workspaces = v;
    }
    if let Some(v) = output_user_root {
        config.output_user_root = Some(v);
    }
    user_config::save(launcher_dir, &config)?;
    info!(
        "user_config: clippy={} per_package_workspaces={} output_user_root={:?}",
        config.clippy, config.per_package_workspaces, config.output_user_root
    );
    Ok(())
}

fn main() -> Result<()> {
    env_logger::init();
    let Cli {
        workspace,
        skip_proc_macro_server,
        skip_rustfmt,
        per_package_workspaces,
        no_per_package_workspaces,
        clippy,
        no_clippy,
        clean,
        output_user_root,
        ide,
    } = Cli::parse();

    let workspace = workspace.unwrap_or_else(|| Utf8PathBuf::from("."));

    // Tri-state resolution of the per-user opt-ins: explicit flag wins,
    // otherwise the file is left as-is. `clap`'s `conflicts_with` above
    // guarantees the (true, true) case can't happen.
    let pending_clippy = pick_toggle(clippy, no_clippy);
    let pending_ppw = pick_toggle(per_package_workspaces, no_per_package_workspaces);

    let vscode_targets = match &ide {
        IdeCmd::Vscode(args) => Some(resolve_vscode_targets(&workspace, args)?),
        IdeCmd::Neovim | IdeCmd::Helix | IdeCmd::Print => None,
    };
    let launcher_dir = launcher_dir_for(&workspace, &ide);

    if clean {
        clean_cache(&launcher_dir)?;
    }

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
    // Launcher shims are only referenced by the VSCode subcommand's
    // managed keys; neovim / helix / print snippets bake absolute
    // toolchain paths directly and don't go through the launchers.
    if matches!(ide, IdeCmd::Vscode(_)) {
        install_toolchain_launchers(&launcher_dir, &runfiles, &toolchain)?;
    }

    // Apply any pending user_config edits before dispatching to the
    // per-IDE runner — that way tests / --dry-run flows (future work)
    // and the per-IDE runners themselves see a consistent on-disk
    // state, and running `setup --clippy` with no IDE change still
    // takes effect.
    apply_user_config_edits(&launcher_dir, pending_clippy, pending_ppw, output_user_root)?;

    let ctx = SetupCtx {
        launcher_dir,
        skip_proc_macro_server,
        skip_rustfmt,
        toolchain,
    };

    match ide {
        IdeCmd::Vscode(args) => run_vscode(&ctx, args, vscode_targets.unwrap()),
        IdeCmd::Neovim => run_neovim(&ctx),
        IdeCmd::Helix => run_helix(&ctx),
        IdeCmd::Print => run_print(&ctx),
    }
}

/// Shared state computed once at startup and threaded through every
/// per-IDE runner.
struct SetupCtx {
    /// Editor-specific dir setup copies source binaries into. The
    /// discover/flycheck binaries self-locate their cache + output dirs
    /// as siblings of themselves (`<launcher_dir>/cache` and
    /// `<launcher_dir>/output_user_root` respectively).
    launcher_dir: Utf8PathBuf,
    skip_proc_macro_server: bool,
    skip_rustfmt: bool,
    /// Canonical absolute paths of the three toolchain binaries,
    /// written into `launcher_paths.json` for the launcher shims to
    /// read at LSP startup. See [`ToolchainBinaries`] for how they're
    /// resolved.
    toolchain: ToolchainBinaries,
}

/// Absolute, canonicalized paths to the three toolchain binaries the
/// launcher shims exec. Resolved once in `main` via setup's own
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

/// VS Code multi-root workspace file extension; used by
/// [`autodetect_code_workspace`] to find a workspace file at the
/// project root.
const CODE_WORKSPACE_EXT: &str = ".code-workspace";

const DEFAULT_VSCODE_OUTPUT: &str = ".vscode/settings.json";

/// `settings_json` is always written; `code_workspace` is optional
/// (autodetected when a unique `.code-workspace` exists at the
/// workspace root, forced by `--code-workspace`, or skipped by
/// `--no-code-workspace`). Resolved before install work so
/// ambiguous-`.code-workspace` errors fail fast.
#[derive(Debug)]
struct ResolvedVscodeTargets {
    settings_json: Utf8PathBuf,
    /// When set, the managed keys ALSO get merged into this file
    /// under [`CodeWorkspaceTarget::settings_key`] (default
    /// `"settings"` — the block VS Code reads window-scoped
    /// rust-analyzer config from when opening via the workspace file).
    code_workspace: Option<CodeWorkspaceTarget>,
}

#[derive(Debug)]
struct CodeWorkspaceTarget {
    path: Utf8PathBuf,
    settings_key: String,
}

fn resolve_vscode_targets(
    workspace: &Utf8Path,
    args: &VscodeArgs,
) -> Result<ResolvedVscodeTargets> {
    let settings_json = args
        .settings_json
        .as_deref()
        .map(|p| abs_or_under(workspace, p))
        .unwrap_or_else(|| workspace.join(DEFAULT_VSCODE_OUTPUT));
    let code_workspace = resolve_code_workspace_target(workspace, args)?;
    Ok(ResolvedVscodeTargets {
        settings_json,
        code_workspace,
    })
}

fn resolve_code_workspace_target(
    workspace: &Utf8Path,
    args: &VscodeArgs,
) -> Result<Option<CodeWorkspaceTarget>> {
    if args.no_code_workspace {
        return Ok(None);
    }
    let path = match args.code_workspace.as_deref() {
        Some(p) => Some(abs_or_under(workspace, p)),
        None => autodetect_code_workspace(workspace)?,
    };
    Ok(path.map(|path| CodeWorkspaceTarget {
        path,
        settings_key: args
            .settings_key
            .clone()
            .unwrap_or_else(|| "settings".to_owned()),
    }))
}

/// Resolve a CLI-supplied path against `workspace`: absolute paths
/// pass through, relative ones join under the workspace root.
fn abs_or_under(workspace: &Utf8Path, path: &Utf8Path) -> Utf8PathBuf {
    if path.is_absolute() {
        path.to_owned()
    } else {
        workspace.join(path)
    }
}

/// Zero matches → `Ok(None)` (`settings.json` gets written alone);
/// one → `Ok(Some)`; two or more → `Err`, since auto-targeting is
/// ambiguous (user must pass `--code-workspace` to pick, or
/// `--no-code-workspace` to skip).
fn autodetect_code_workspace(workspace: &Utf8Path) -> Result<Option<Utf8PathBuf>> {
    let read = match fs::read_dir(workspace) {
        Ok(r) => r,
        // Workspace path missing or unreadable is fine for autodetect —
        // no code-workspace to write.
        Err(_) => return Ok(None),
    };
    let mut matches: Vec<Utf8PathBuf> = Vec::new();
    for entry in read.flatten() {
        let Ok(name) = entry.file_name().into_string() else {
            continue;
        };
        if name.ends_with(CODE_WORKSPACE_EXT) {
            matches.push(workspace.join(name));
        }
    }
    matches.sort();
    match matches.len() {
        0 => Ok(None),
        1 => Ok(matches.pop()),
        _ => anyhow::bail!(
            "multiple `*{CODE_WORKSPACE_EXT}` files at {workspace}: {}. Pass `--code-workspace <path>` to pick one, or `--no-code-workspace` to skip.",
            matches
                .iter()
                .map(|p| p.file_name().unwrap_or(""))
                .collect::<Vec<_>>()
                .join(", "),
        ),
    }
}

fn run_vscode(ctx: &SetupCtx, args: VscodeArgs, targets: ResolvedVscodeTargets) -> Result<()> {
    let ResolvedVscodeTargets {
        settings_json,
        code_workspace,
    } = targets;
    let managed = vscode_managed_keys(ctx);

    // Always settings.json (managed keys at root); then optionally
    // the .code-workspace (managed keys nested under `settings_key`
    // so sibling folders / tasks / extensions / user comments
    // survive).
    let writes = std::iter::once((settings_json, None))
        .chain(code_workspace.map(|cw| (cw.path, Some(cw.settings_key))));

    for (path, settings_key) in writes {
        let merged = if args.replace {
            replace_managed_file(&path, &managed, settings_key.as_deref())?
        } else {
            merge_file(&path, &managed, settings_key.as_deref())?
        };
        if args.dry_run {
            println!("=== {path} ===");
            println!("{merged}");
        } else {
            write_text(path.as_std_path(), &merged)?;
            info!(
                "{} {} in {path}",
                if args.replace { "Wrote" } else { "Merged" },
                managed.len(),
            );
        }
    }
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

/// Delete the discover-output cache under `launcher_dir`. Called on
/// `--clean`. Leaves everything else in `launcher_dir` alone
/// (`user_config.json` is per-user prefs; `output_user_root/` is
/// flycheck's Bazel build tree, expensive to rebuild). Missing dir is
/// not an error — clean is idempotent.
fn clean_cache(launcher_dir: &Utf8Path) -> Result<()> {
    let cache = launcher_dir.join(CACHE_SUBDIR);
    match fs::remove_dir_all(&cache) {
        Ok(()) => {
            eprintln!("cleared discover cache at {cache}");
            Ok(())
        }
        Err(e) if e.kind() == io::ErrorKind::NotFound => Ok(()),
        Err(e) => Err(e).with_context(|| format!("removing discover cache at {cache}")),
    }
}

/// Copy discover + flycheck into `dir`. They live in `bazel-out`
/// originally and would be wiped by `bazel clean`; the copy survives
/// until the next `bazel clean --expunge` (which also nukes the
/// toolchain binaries and requires re-running setup anyway).
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

/// Assumes `dir` already exists — `install_source_binaries`, called
/// earlier in `main`, creates it.
fn install_toolchain_launchers(
    dir: &Utf8Path,
    runfiles: &Runfiles,
    toolchain: &ToolchainBinaries,
) -> Result<()> {
    let launcher_src = lookup_runfile(runfiles, env!("LAUNCHER_RLOCATIONPATH"))?;
    for logical in LAUNCHER_LOGICAL_NAMES {
        let dest = dir.join(launcher_filename(logical));
        fs::copy(&launcher_src, &dest)
            .with_context(|| format!("copying {launcher_src} -> {dest}"))?;
        set_executable(&dest)?;
    }
    write_launcher_paths_json(&dir.join(LAUNCHER_PATHS_JSON), toolchain)
}

fn write_launcher_paths_json(path: &Utf8Path, toolchain: &ToolchainBinaries) -> Result<()> {
    // Entirely generated file — no trivia to preserve, so plain
    // serde_json is fine (unlike the .vscode/settings.json /
    // .code-workspace merges that go through the CST).
    let map = Value::Object(
        LAUNCHER_LOGICAL_NAMES
            .iter()
            .map(|logical| {
                let target = toolchain_target_for(logical, toolchain);
                (
                    (*logical).to_owned(),
                    Value::String(target.as_str().to_owned()),
                )
            })
            .collect(),
    );
    let mut json = serde_json::to_string_pretty(&map)?;
    json.push('\n');
    write_text(path.as_std_path(), &json)
}

fn toolchain_target_for<'a>(logical: &str, toolchain: &'a ToolchainBinaries) -> &'a Utf8PathBuf {
    match logical {
        "rust_analyzer" => &toolchain.rust_analyzer,
        "rust_analyzer_proc_macro_srv" => &toolchain.proc_macro_srv,
        "rustfmt" => &toolchain.rustfmt,
        other => panic!("unknown launcher logical name `{other}` — keep LAUNCHER_LOGICAL_NAMES and ToolchainBinaries in sync"),
    }
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

/// Workspace-relative launcher dir for the Vscode subcommand. Pinned
/// to `.vscode/` regardless of where the settings file lives (default
/// `.vscode/settings.json`, or a `.code-workspace` at the workspace
/// root, or a custom `--output` path): `.vscode/` is universally
/// recognized as VSCode-scoped, and the committed settings file
/// references `${workspaceFolder}/.vscode/.rules_rust_analyzer/<name>.exe`
/// so it stays the same no matter what output path the user picked.
const VSCODE_LAUNCHER_REL: &str = ".vscode";

fn launcher_dir_for(workspace: &Utf8Path, ide: &IdeCmd) -> Utf8PathBuf {
    match ide {
        IdeCmd::Vscode(_) => workspace.join(VSCODE_LAUNCHER_REL).join(LAUNCHER_SUBDIR),
        IdeCmd::Helix => workspace.join(".helix").join(LAUNCHER_SUBDIR),
        // Neovim has no canonical per-project dotdir; print covers
        // editor-agnostic JSON-config LSP clients. Both land at the
        // workspace root.
        IdeCmd::Neovim | IdeCmd::Print => workspace.join(LAUNCHER_SUBDIR),
    }
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
}

/// VS Code expands `${workspaceFolder}` for rust-analyzer's path
/// settings — that's what keeps the committed settings file portable.
/// Kept in sync with [`launcher_dir_for`]'s VSCode arm via
/// [`VSCODE_LAUNCHER_REL`].
fn workspace_relative(filename: &str) -> String {
    format!("${{workspaceFolder}}/{VSCODE_LAUNCHER_REL}/{LAUNCHER_SUBDIR}/{filename}")
}

fn vscode_managed_keys(ctx: &SetupCtx) -> Vec<(String, ManagedValue)> {
    let ra_path = workspace_relative("rust_analyzer.exe");
    let pms_path = workspace_relative("rust_analyzer_proc_macro_srv.exe");
    let rustfmt_path = workspace_relative("rustfmt.exe");
    let discover_path = workspace_relative(DISCOVER_BINARY_FILENAME);
    let bazel_outputs = || vec![(BAZEL_OUTPUTS_GLOB.to_string(), Value::Bool(true))];
    // Rendered discover command is intentionally identical for every
    // developer — per-user knobs (clippy, per-package-workspaces) live
    // in `<launcher_dir>/user_config.json`, not here. `{arg}` is
    // always present so rust-analyzer will pass the per-file arg on
    // demand; discover ignores it when the user opted out of
    // per-package-workspaces.
    let discover_command = json!([discover_path, "{arg}"]);
    let mut out = vec![
        (
            DISCOVER_CONFIG_KEY.to_string(),
            ManagedValue::Replace(json!({
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
    out
}

/// Parse `path` as JSONC via `jsonc-parser`'s CST — which preserves
/// comments, whitespace, and trailing commas so mutations round-trip
/// without stripping trivia. Missing / empty files return a fresh empty
/// root object.
///
/// The returned `CstRootNode` MUST NOT be dropped while any of its
/// descendants are in use — the CST uses weak parent pointers and
/// dropping the root panics its children.
fn parse_root(path: &Utf8Path) -> Result<CstRootNode> {
    let text = match fs::read_to_string(path) {
        Ok(t) if t.trim().is_empty() => "{}\n".to_owned(),
        Ok(t) => t,
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => "{}\n".to_owned(),
        Err(e) => return Err(e).with_context(|| format!("reading {path}")),
    };
    CstRootNode::parse(&text, &ParseOptions::default())
        .map_err(|e| anyhow::anyhow!("{path} is not valid JSON ({e})"))
}

fn root_object(path: &Utf8Path, root: &CstRootNode) -> Result<CstObject> {
    root.object_value().ok_or_else(|| {
        anyhow::anyhow!(
            "{path}'s root is not a JSON object; refusing to merge. Use --replace to overwrite."
        )
    })
}

/// Merge `managed` into the JSONC file at `path`, preserving all
/// existing comments and formatting. Returns the merged file content
/// as a string ready to write. See [`apply_managed_cst`] for the
/// per-strategy semantics.
fn merge_file(
    path: &Utf8Path,
    managed: &[(String, ManagedValue)],
    settings_key: Option<&str>,
) -> Result<String> {
    let root = parse_root(path)?;
    let root_obj = root_object(path, &root)?;
    let target = match settings_key {
        None => root_obj,
        Some(k) => root_obj.object_value_or_create(k).ok_or_else(|| {
            anyhow::anyhow!(
                "{path}'s `{k}` is not an object; refusing to merge. Use --replace to overwrite."
            )
        })?,
    };
    for (key, value) in managed {
        apply_managed_cst(&target, key, value);
    }
    Ok(root.to_string())
}

/// `--replace` path. With `settings_key = Some` we only replace
/// `root[key]` — sibling keys (`folders` / `tasks` / `extensions` on
/// a `.code-workspace`) survive, since the user can't usefully
/// `--replace` the whole workspace file. Without a `settings_key`
/// the entire root document is replaced with just the managed keys.
fn replace_managed_file(
    path: &Utf8Path,
    managed: &[(String, ManagedValue)],
    settings_key: Option<&str>,
) -> Result<String> {
    let props: Vec<(String, CstInputValue)> = managed
        .iter()
        .map(|(k, v)| (k.clone(), realize_managed_cst(v)))
        .collect();
    // Without a settings_key we're wholesale-replacing the document;
    // no need to parse (and no need to inherit corruption from the
    // existing file). Only the settings_key branch has to preserve
    // siblings and therefore has to read what's there.
    let root = if settings_key.is_some() {
        parse_root(path)?
    } else {
        CstRootNode::parse("{}\n", &ParseOptions::default()).expect("empty object is valid JSON")
    };
    match settings_key {
        None => {
            root.set_value(CstInputValue::Object(props));
        }
        Some(k) => {
            let root_obj = root_object(path, &root)?;
            if let Some(existing) = root_obj.get(k) {
                existing.remove();
            }
            root_obj.append(k, CstInputValue::Object(props));
        }
    }
    Ok(root.to_string())
}

/// Mutate `target` per the [`ManagedValue`] strategy:
///
/// * `Replace` — overwrite (creates the property if missing).
/// * `InsertEntries` — dict-merge: add sub-entries that aren't
///   already present. If the existing value isn't an object, it's
///   overwritten (VSCode wouldn't accept a non-object here anyway).
fn apply_managed_cst(target: &CstObject, key: &str, value: &ManagedValue) {
    match value {
        ManagedValue::Replace(v) => {
            let cst_v = to_cst_input(v);
            match target.get(key) {
                Some(prop) => prop.set_value(cst_v),
                None => {
                    target.append(key, cst_v);
                }
            }
        }
        ManagedValue::InsertEntries(entries) => {
            let obj = target.object_value_or_set(key);
            for (sub_k, sub_v) in entries {
                if obj.get(sub_k).is_none() {
                    obj.append(sub_k, to_cst_input(sub_v));
                }
            }
        }
    }
}

/// Materialize a managed value as a fresh CST input — used by the
/// `--replace` path where there's no pre-existing structure to
/// preserve.
fn realize_managed_cst(value: &ManagedValue) -> CstInputValue {
    match value {
        ManagedValue::Replace(v) => to_cst_input(v),
        ManagedValue::InsertEntries(entries) => CstInputValue::Object(
            entries
                .iter()
                .map(|(k, v)| (k.clone(), to_cst_input(v)))
                .collect(),
        ),
    }
}

fn to_cst_input(v: &Value) -> CstInputValue {
    match v {
        Value::Null => CstInputValue::Null,
        Value::Bool(b) => CstInputValue::Bool(*b),
        // `jsonc-parser` takes numbers as their source text — reusing
        // serde_json's canonical formatting round-trips cleanly since
        // both agree on the numeric grammar.
        Value::Number(n) => CstInputValue::Number(n.to_string()),
        Value::String(s) => CstInputValue::String(s.clone()),
        Value::Array(arr) => CstInputValue::Array(arr.iter().map(to_cst_input).collect()),
        Value::Object(obj) => CstInputValue::Object(
            obj.iter()
                .map(|(k, v)| (k.clone(), to_cst_input(v)))
                .collect(),
        ),
    }
}

fn write_text(path: &Path, text: &str) -> Result<()> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)
            .with_context(|| format!("creating directory {}", parent.display()))?;
    }
    fs::write(path, text).with_context(|| format!("writing {}", path.display()))?;
    Ok(())
}

// ---------------------------------------------------------------------------
// Snippet generators for non-VSCode IDEs
//
// Each format has one main template constant and two optional sub-block
// constants (proc-macro / rustfmt). The generator resolves each sub-block
// to a string (substituted-or-empty) and then does a final pass on the
// main template. Reads top-to-bottom in the format it's emitting —
// `cargo expand` or `cat`-friendly during review.
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
// Optional-block slots in the main templates.
const TPL_OPT_PROC_MACRO: &str = "__OPT_PROC_MACRO__";
const TPL_OPT_RUSTFMT: &str = "__OPT_RUSTFMT__";
// The `, "{arg}"` after `__DISCOVER_LAUNCHER__` in each template is
// literal, not a placeholder. Per-package-workspaces is per-user
// (`<launcher_dir>/user_config.json`), so the shared snippet always
// includes the arg slot — discover honors the user's preference at
// runtime. Same syntax works in Lua/TOML/JSON since all three quote
// strings with `"`.

// -- Neovim (nvim-lspconfig) Lua --

const NEOVIM_LUA_TEMPLATE: &str = r#"require("lspconfig").rust_analyzer.setup({
  cmd = { "__RA_LAUNCHER__" },
  settings = {
    ["rust-analyzer"] = {
      workspace = {
        discoverConfig = {
          command = { "__DISCOVER_LAUNCHER__", "{arg}" },
          progressLabel = "rules_rust",
          filesToWatch = { "BUILD", "BUILD.bazel", "MODULE.bazel", "WORKSPACE", "WORKSPACE.bazel" },
        },
      },
__OPT_PROC_MACRO____OPT_RUSTFMT__      lens = { enable = true },
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

// -- Helix languages.toml --

const HELIX_TOML_TEMPLATE: &str = r#"[language-server.rust-analyzer]
command = "__RA_LAUNCHER__"

[language-server.rust-analyzer.config.rust-analyzer.workspace.discoverConfig]
command = ["__DISCOVER_LAUNCHER__", "{arg}"]
progressLabel = "rules_rust"
filesToWatch = ["BUILD", "BUILD.bazel", "MODULE.bazel", "WORKSPACE", "WORKSPACE.bazel"]
__OPT_PROC_MACRO____OPT_RUSTFMT__
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
    "command": ["__DISCOVER_LAUNCHER__", "{arg}"],
    "progressLabel": "rules_rust",
    "filesToWatch": ["BUILD", "BUILD.bazel", "MODULE.bazel", "WORKSPACE", "WORKSPACE.bazel"]
  },
  __OPT_PROC_MACRO____OPT_RUSTFMT__"rust-analyzer.lens.enable": true
}
"#;

const SETTINGS_JSON_PROC_MACRO: &str = r#""rust-analyzer.procMacro.server": "__PMS_LAUNCHER__",
  "#;

const SETTINGS_JSON_RUSTFMT: &str = r#""rust-analyzer.rustfmt.overrideCommand": ["__RUSTFMT_LAUNCHER__"],
  "#;

// -- Helpers shared by all three generators --

/// Bracket a printed snippet with a banner on stderr so the user can
/// distinguish setup's own narration from the snippet itself.
fn print_snippet_with_banner(banner: &str, snippet: &str) {
    eprintln!("\n========== {banner} ==========");
    println!("{snippet}");
    eprintln!("========== end ==========\n");
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

// -- Generators --

/// The four forward-slashed absolute paths every editor snippet
/// (Neovim Lua, Helix TOML, JSON) needs. Three come from the toolchain
/// directly; `discover` is at `<launcher_dir>/<DISCOVER_BINARY_FILENAME>`
/// (setup copied it there). Snippet generators use absolute paths
/// (unlike the VSCode subcommand's `${workspaceFolder}` references) —
/// snippets are user-pasted and gitignored, not committed. Precomputed
/// once per generator call so the optional-block closures can borrow
/// strings instead of re-running `to_forward_slashes` each time.
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

/// Render a snippet `main_template` plus two optional sub-templates
/// (proc-macro, rustfmt) under their `TPL_OPT_*` placeholders. Shared
/// by the three per-editor generators — they differ only in their
/// template constants.
fn render_snippet(
    ctx: &SetupCtx,
    paths: &SnippetPaths,
    main_template: &str,
    proc_macro_template: &str,
    rustfmt_template: &str,
) -> String {
    let proc_macro = opt_block(!ctx.skip_proc_macro_server, proc_macro_template, |t| {
        t.replace(TPL_PMS_LAUNCHER, &paths.pms)
    });
    let rustfmt = opt_block(!ctx.skip_rustfmt, rustfmt_template, |t| {
        t.replace(TPL_RUSTFMT_LAUNCHER, &paths.rustfmt)
    });
    main_template
        .replace(TPL_RA_LAUNCHER, &paths.ra)
        .replace(TPL_DISCOVER_LAUNCHER, &paths.discover)
        .replace(TPL_OPT_PROC_MACRO, &proc_macro)
        .replace(TPL_OPT_RUSTFMT, &rustfmt)
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

    /// Fake workspace root used to derive per-editor launcher dirs in
    /// tests. Not stored on `SetupCtx`; test callers `.join(...)` this
    /// directly for the launcher_dir they want to test against.
    const DUMMY_WORKSPACE: &str = "/ws";

    fn dummy_ctx() -> (SetupCtx, Utf8PathBuf) {
        let launcher_dir = Utf8PathBuf::from(DUMMY_WORKSPACE)
            .join(VSCODE_LAUNCHER_REL)
            .join(LAUNCHER_SUBDIR);
        let ctx = SetupCtx {
            launcher_dir: launcher_dir.clone(),
            skip_proc_macro_server: false,
            skip_rustfmt: false,
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
            ManagedValue::InsertEntries(_) => {
                panic!("expected Replace strategy for {key}")
            }
        }
    }

    /// Parse the merged-text output of `merge_file` / `replace_managed_file`
    /// back into a `serde_json::Value` for assertion. Uses `jsonc_parser`'s
    /// serde_json bridge so JSONC output (comments / trailing commas) round-trips.
    fn parse_merged(merged: &str) -> Value {
        jsonc_parser::parse_to_serde_value(merged, &Default::default())
            .expect("output must be valid JSON")
            .expect("non-empty JSON")
    }

    #[test]
    fn merge_preserves_user_keys() {
        let (ctx, _launcher_dir) = dummy_ctx();
        let tmp = std::env::temp_dir().join(format!("setup_test_{}", std::process::id()));
        std::fs::create_dir_all(&tmp).unwrap();
        let path = Utf8PathBuf::try_from(tmp.join("settings.json")).unwrap();
        fs::write(
            &path,
            r#"{"editor.tabSize": 4, "rust-analyzer.server.path": "old"}"#,
        )
        .unwrap();
        let merged = merge_file(&path, &vscode_managed_keys(&ctx), None).unwrap();
        let parsed = parse_merged(&merged);
        let obj = parsed.as_object().unwrap();
        // User key preserved
        assert_eq!(obj.get("editor.tabSize"), Some(&json!(4)));
        // Managed key overwritten and points at the launcher shim.
        assert_eq!(
            obj.get(SERVER_PATH_KEY).unwrap().as_str().unwrap(),
            "${workspaceFolder}/.vscode/.rules_rust_analyzer/rust_analyzer.exe"
        );
        // discoverConfig present
        assert!(obj.get(DISCOVER_CONFIG_KEY).is_some());
        let _ = std::fs::remove_dir_all(&tmp);
    }

    #[test]
    fn merge_handles_missing_file() {
        let (ctx, _launcher_dir) = dummy_ctx();
        let tmp = std::env::temp_dir().join(format!("setup_test2_{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&tmp);
        let path = Utf8PathBuf::try_from(tmp.join("settings.json")).unwrap();
        let merged = merge_file(&path, &vscode_managed_keys(&ctx), None).unwrap();
        let parsed = parse_merged(&merged);
        let obj = parsed.as_object().unwrap();
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
        let (mut ctx, _launcher_dir) = dummy_ctx();
        let with_srv = vscode_managed_keys(&ctx);
        ctx.skip_proc_macro_server = true;
        let without_srv = vscode_managed_keys(&ctx);
        // 4 rust-analyzer keys + 3 exclude maps = 7 total.
        assert_eq!(with_srv.len(), 7);
        assert_eq!(without_srv.len(), 6);
        assert!(!without_srv.iter().any(|(k, _)| k == PROC_MACRO_SRV_KEY));
    }

    #[test]
    fn skip_rustfmt_drops_only_the_rustfmt_key() {
        let (mut ctx, _launcher_dir) = dummy_ctx();
        let with_fmt = vscode_managed_keys(&ctx);
        ctx.skip_rustfmt = true;
        let without_fmt = vscode_managed_keys(&ctx);
        assert_eq!(with_fmt.len(), 7);
        assert_eq!(without_fmt.len(), 6);
        assert!(!without_fmt.iter().any(|(k, _)| k == RUSTFMT_OVERRIDE_KEY));
        // The proc-macro key still rides along.
        assert!(without_fmt.iter().any(|(k, _)| k == PROC_MACRO_SRV_KEY));
    }

    #[test]
    fn rustfmt_override_is_argv_array_pointing_at_launcher() {
        let (ctx, _launcher_dir) = dummy_ctx();
        let keys = vscode_managed_keys(&ctx);
        let val = replace_value(&keys, RUSTFMT_OVERRIDE_KEY);
        let arr = val.as_array().unwrap();
        assert_eq!(arr.len(), 1);
        assert_eq!(
            arr[0].as_str().unwrap(),
            "${workspaceFolder}/.vscode/.rules_rust_analyzer/rustfmt.exe"
        );
    }

    #[test]
    fn vscode_managed_keys_emit_workspace_folder_refs_with_exe_suffix() {
        let (ctx, _launcher_dir) = dummy_ctx();
        let keys = vscode_managed_keys(&ctx);
        // All four managed path keys reference the launcher dir via
        // `${workspaceFolder}` so the committed settings file is
        // portable across developers and platforms.
        assert_eq!(
            replace_value(&keys, SERVER_PATH_KEY).as_str().unwrap(),
            "${workspaceFolder}/.vscode/.rules_rust_analyzer/rust_analyzer.exe"
        );
        assert_eq!(
            replace_value(&keys, PROC_MACRO_SRV_KEY).as_str().unwrap(),
            "${workspaceFolder}/.vscode/.rules_rust_analyzer/rust_analyzer_proc_macro_srv.exe"
        );
        let discover_cmd = replace_value(&keys, DISCOVER_CONFIG_KEY)
            .get("command")
            .and_then(|v| v.as_array())
            .expect("command must be an array");
        assert_eq!(
            discover_cmd[0].as_str().unwrap(),
            "${workspaceFolder}/.vscode/.rules_rust_analyzer/discover_bazel_rust_project.exe"
        );
    }

    #[test]
    fn discover_command_is_identical_regardless_of_user_preferences() {
        // The whole point of user_config.json is that the shared,
        // committed settings file must be byte-identical for every
        // developer. So the rendered discover command must never
        // contain per-user opt-ins like `--clippy`, and `{arg}` must
        // always be present so discover can serve either scope on
        // demand — see the comment in `vscode_managed_keys`.
        let (ctx, _launcher_dir) = dummy_ctx();
        let keys = vscode_managed_keys(&ctx);
        let discover_cmd = replace_value(&keys, DISCOVER_CONFIG_KEY)
            .get("command")
            .and_then(|v| v.as_array())
            .expect("command must be an array");
        assert!(
            !discover_cmd.iter().any(|v| v == "--clippy"),
            "shared discover command must not encode --clippy: {discover_cmd:?}",
        );
        assert!(
            discover_cmd.iter().any(|v| v == "{arg}"),
            "shared discover command must always template {{arg}}: {discover_cmd:?}",
        );
    }

    #[test]
    fn apply_user_config_edits_writes_only_named_fields() {
        // `setup --clippy` (no other toggle) must NOT reset
        // per_package_workspaces — the file is a merge target, not a
        // reset target.
        let dir = std::env::temp_dir().join(format!("setup_uc_partial_{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).unwrap();
        let launcher_dir = Utf8PathBuf::try_from(dir.clone()).unwrap();
        user_config::save(
            &launcher_dir,
            &user_config::UserConfig {
                clippy: false,
                per_package_workspaces: true,
                output_user_root: Some(Utf8PathBuf::from("/existing/root")),
            },
        )
        .unwrap();

        apply_user_config_edits(&launcher_dir, Some(true), None, None).unwrap();

        let loaded = user_config::load(&launcher_dir);
        assert!(loaded.clippy, "--clippy must land in the file");
        assert!(
            loaded.per_package_workspaces,
            "unnamed fields must be preserved: got {loaded:?}",
        );
        assert_eq!(
            loaded.output_user_root,
            Some(Utf8PathBuf::from("/existing/root")),
            "unnamed fields must be preserved: got {loaded:?}",
        );
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn apply_user_config_edits_persists_output_user_root() {
        // `setup --output-user-root /some/path` writes the path into
        // the launcher-dir user_config, so flycheck picks it up on
        // future saves without any committed-file change.
        let dir = std::env::temp_dir().join(format!("setup_uc_our_{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).unwrap();
        let launcher_dir = Utf8PathBuf::try_from(dir.clone()).unwrap();
        let path = Utf8PathBuf::from("/custom/flycheck/root");

        apply_user_config_edits(&launcher_dir, None, None, Some(path.clone())).unwrap();

        let loaded = user_config::load(&launcher_dir);
        assert_eq!(loaded.output_user_root, Some(path));
        assert!(!loaded.clippy, "unrelated fields must stay default");
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn apply_user_config_edits_is_a_noop_when_nothing_pending() {
        // Bare `setup` (no toggles) must not create the file — no
        // point committing an all-defaults marker to the launcher
        // dir just because someone re-ran discovery.
        let dir = std::env::temp_dir().join(format!("setup_uc_noop_{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).unwrap();
        let launcher_dir = Utf8PathBuf::try_from(dir.clone()).unwrap();

        apply_user_config_edits(&launcher_dir, None, None, None).unwrap();

        assert!(!launcher_dir
            .join(user_config::USER_CONFIG_FILENAME)
            .exists());
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn watcher_exclude_dict_merges_with_user_entries() {
        let (ctx, _launcher_dir) = dummy_ctx();
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
        let merged = merge_file(&path, &vscode_managed_keys(&ctx), None).unwrap();
        let parsed = parse_merged(&merged);
        let watchers = parsed
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
    fn clean_cache_removes_cache_dir_and_leaves_siblings_alone() {
        let ws = make_workspace(
            "clean_cache",
            &[
                ("user_config.json", r#"{"clippy":true}"#),
                ("rust_analyzer.exe", ""),
            ],
        );
        std::fs::create_dir_all(ws.join("cache")).unwrap();
        std::fs::write(ws.join("cache").join("entry.json"), "{}").unwrap();

        clean_cache(&ws).unwrap();
        assert!(!ws.join("cache").exists(), "cache dir should be gone");
        assert!(
            ws.join("user_config.json").exists(),
            "user_config preserved"
        );
        assert!(ws.join("rust_analyzer.exe").exists(), "launcher preserved");

        // Idempotent: second call on now-missing dir is fine.
        clean_cache(&ws).unwrap();
        let _ = std::fs::remove_dir_all(&ws);
    }

    fn empty_vscode_args() -> VscodeArgs {
        VscodeArgs {
            settings_json: None,
            code_workspace: None,
            no_code_workspace: false,
            settings_key: None,
            dry_run: false,
            replace: false,
        }
    }

    #[test]
    fn launcher_dir_for_picks_editor_specific_subdir() {
        let ws = Utf8PathBuf::from("/workspace");
        let vscode = IdeCmd::Vscode(empty_vscode_args());
        assert_eq!(
            launcher_dir_for(&ws, &vscode),
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
    fn launcher_dir_for_vscode_is_pinned_regardless_of_output() {
        // Whether the user targets `.vscode/settings.json`, a custom
        // path, or a `.code-workspace` at the workspace root, the
        // Vscode launcher dir is always `.vscode/.rules_rust_analyzer/`
        // — the committed settings file references it via
        // `${workspaceFolder}` so all three outputs use the same path.
        let ws = Utf8PathBuf::from("/workspace");
        let expected = Utf8PathBuf::from("/workspace/.vscode/.rules_rust_analyzer");
        assert_eq!(
            launcher_dir_for(&ws, &IdeCmd::Vscode(empty_vscode_args())),
            expected,
        );
    }

    #[test]
    fn neovim_snippet_contains_toolchain_and_discover_paths_and_lens_enable() {
        let (ctx, _) = dummy_ctx();
        let launcher_dir = Utf8PathBuf::from(DUMMY_WORKSPACE).join(LAUNCHER_SUBDIR);
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
        let launcher_dir = Utf8PathBuf::from(DUMMY_WORKSPACE)
            .join(".helix")
            .join(LAUNCHER_SUBDIR);
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
        let launcher_dir = Utf8PathBuf::from(DUMMY_WORKSPACE).join(LAUNCHER_SUBDIR);
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
            let launcher_dir = Utf8PathBuf::from(DUMMY_WORKSPACE).join(LAUNCHER_SUBDIR);
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
        let launcher_dir = Utf8PathBuf::from(DUMMY_WORKSPACE).join(LAUNCHER_SUBDIR);

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
    /// The rendered discover command is per-user-preference agnostic
    /// now: `{arg}` is always present so rust-analyzer can serve the
    /// per-file arg on demand, and discover decides whether to honor it
    /// by consulting `user_config.json`.
    #[test]
    fn discover_command_always_includes_per_package_arg_template() {
        let (ctx, _launcher_dir) = dummy_ctx();
        let keys = vscode_managed_keys(&ctx);
        let cmd = replace_value(&keys, DISCOVER_CONFIG_KEY)
            .get("command")
            .and_then(|v| v.as_array())
            .expect("command must be an array");
        assert_eq!(
            cmd.len(),
            2,
            "discover command should always be [binary, \"{{arg}}\"]; got {cmd:?}"
        );
        assert_eq!(cmd[1].as_str(), Some("{arg}"));
    }

    /// Same coverage but for the Lua/TOML/JSON snippets, since those
    /// go through a totally different substitution path.
    #[test]
    fn snippets_always_include_per_package_arg_template() {
        let (ctx, launcher_dir) = dummy_ctx();
        let lua = generate_neovim_lua(&ctx, &launcher_dir);
        let toml = generate_helix_toml(&ctx, &launcher_dir);
        let json = generate_settings_json(&ctx, &launcher_dir);
        assert!(lua.contains("\"{arg}\""), "lua missing {{arg}}:\n{lua}");
        assert!(toml.contains("\"{arg}\""), "toml missing {{arg}}:\n{toml}");
        assert!(json.contains("\"{arg}\""), "json missing {{arg}}:\n{json}");
        // JSON must still parse.
        serde_json::from_str::<Value>(&json).expect("json snippet stays valid");
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
                TPL_OPT_PROC_MACRO,
                TPL_OPT_RUSTFMT,
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
    }

    // -----------------------------------------------------------------
    // `.code-workspace` support
    // -----------------------------------------------------------------

    /// Build a workspace dir in $TMPDIR, populated with the listed
    /// files. Returns the dir path; caller is responsible for cleanup
    /// (use `remove_dir_all` in a `_guard`-style drop, or accept the
    /// leak — TMPDIR gets cleaned eventually).
    fn make_workspace(tag: &str, files: &[(&str, &str)]) -> Utf8PathBuf {
        let tmp = std::env::temp_dir().join(format!("setup_{tag}_{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&tmp);
        std::fs::create_dir_all(&tmp).unwrap();
        for (name, content) in files {
            std::fs::write(tmp.join(name), content).unwrap();
        }
        Utf8PathBuf::try_from(tmp).unwrap()
    }

    #[test]
    fn merge_under_settings_key_preserves_top_level_keys() {
        let (ctx, _launcher_dir) = dummy_ctx();
        let ws = make_workspace(
            "merge_nest_preserve",
            &[(
                "proj.code-workspace",
                r#"{
                    "folders": [{"path": "."}],
                    "tasks": {"version": "2.0.0"},
                    "settings": {"editor.tabSize": 4}
                }"#,
            )],
        );
        let path = ws.join("proj.code-workspace");
        let merged = merge_file(&path, &vscode_managed_keys(&ctx), Some("settings")).unwrap();
        let parsed = parse_merged(&merged);
        let root = parsed.as_object().unwrap();

        // Top-level sibling keys survived intact.
        assert_eq!(
            root.get("folders").unwrap(),
            &json!([{"path": "."}]),
            "folders must survive a merge under settings_key",
        );
        assert_eq!(
            root.get("tasks").unwrap(),
            &json!({"version": "2.0.0"}),
            "tasks must survive a merge under settings_key",
        );

        // Managed keys landed inside `settings`, NOT at the root.
        assert!(!root.contains_key(SERVER_PATH_KEY));
        let settings = root.get("settings").unwrap().as_object().unwrap();
        assert_eq!(
            settings.get(SERVER_PATH_KEY).unwrap().as_str().unwrap(),
            "${workspaceFolder}/.vscode/.rules_rust_analyzer/rust_analyzer.exe"
        );
        // Pre-existing user setting inside `settings` survived.
        assert_eq!(settings.get("editor.tabSize"), Some(&json!(4)));

        let _ = std::fs::remove_dir_all(&ws);
    }

    #[test]
    fn merge_under_settings_key_creates_settings_when_missing() {
        let (ctx, _launcher_dir) = dummy_ctx();
        let ws = make_workspace(
            "merge_nest_create",
            &[("proj.code-workspace", r#"{"folders": [{"path": "."}]}"#)],
        );
        let path = ws.join("proj.code-workspace");
        let merged = merge_file(&path, &vscode_managed_keys(&ctx), Some("settings")).unwrap();
        let parsed = parse_merged(&merged);
        let settings = parsed
            .as_object()
            .unwrap()
            .get("settings")
            .expect("settings object should have been created")
            .as_object()
            .unwrap();
        assert!(settings.contains_key(DISCOVER_CONFIG_KEY));
        let _ = std::fs::remove_dir_all(&ws);
    }

    #[test]
    fn merge_under_settings_key_errors_on_non_object_settings() {
        let (ctx, _launcher_dir) = dummy_ctx();
        let ws = make_workspace(
            "merge_nest_nonobj",
            &[("proj.code-workspace", r#"{"settings": "not an object"}"#)],
        );
        let path = ws.join("proj.code-workspace");
        let err = merge_file(&path, &vscode_managed_keys(&ctx), Some("settings"))
            .unwrap_err()
            .to_string();
        assert!(
            err.contains("`settings`") && err.contains("not an object"),
            "error should name the bad key and its shape, got: {err}"
        );
        let _ = std::fs::remove_dir_all(&ws);
    }

    #[test]
    fn replace_under_settings_key_preserves_top_level() {
        let (ctx, _launcher_dir) = dummy_ctx();
        let ws = make_workspace(
            "replace_nest",
            &[(
                "proj.code-workspace",
                r#"{
                    "folders": [{"path": "."}],
                    "extensions": {"recommendations": ["rust-lang.rust-analyzer"]},
                    "settings": {"editor.tabSize": 4, "rust-analyzer.server.path": "stale"}
                }"#,
            )],
        );
        let path = ws.join("proj.code-workspace");
        let replaced =
            replace_managed_file(&path, &vscode_managed_keys(&ctx), Some("settings")).unwrap();
        let parsed = parse_merged(&replaced);
        let root = parsed.as_object().unwrap();

        // Siblings survived.
        assert_eq!(root.get("folders").unwrap(), &json!([{"path": "."}]));
        assert_eq!(
            root.get("extensions").unwrap(),
            &json!({"recommendations": ["rust-lang.rust-analyzer"]}),
        );

        // `settings` was fully replaced — user's editor.tabSize is gone
        // (the documented `--replace` semantics).
        let settings = root.get("settings").unwrap().as_object().unwrap();
        assert!(!settings.contains_key("editor.tabSize"));
        assert!(settings.contains_key(SERVER_PATH_KEY));

        let _ = std::fs::remove_dir_all(&ws);
    }

    #[test]
    fn replace_without_settings_key_overwrites_root_as_before() {
        // Backwards-compat: --replace without --settings-key still
        // produces just the managed keys at the root.
        let (ctx, _launcher_dir) = dummy_ctx();
        let ws = make_workspace("replace_root", &[]);
        let path = ws.join("settings.json");
        let replaced = replace_managed_file(&path, &vscode_managed_keys(&ctx), None).unwrap();
        let parsed = parse_merged(&replaced);
        let root = parsed.as_object().unwrap();
        assert!(root.contains_key(SERVER_PATH_KEY));
        assert!(root.contains_key(DISCOVER_CONFIG_KEY));
        // No leftover sibling keys (nothing existed to start with).
        let _ = std::fs::remove_dir_all(&ws);
    }

    #[test]
    fn settings_json_always_resolved_to_default_when_unset() {
        let ws = make_workspace("resolve_default", &[]);
        let resolved = resolve_vscode_targets(&ws, &empty_vscode_args()).unwrap();
        assert_eq!(resolved.settings_json, ws.join(".vscode/settings.json"));
        assert!(resolved.code_workspace.is_none());
        let _ = std::fs::remove_dir_all(&ws);
    }

    #[test]
    fn autodetect_picks_unique_code_workspace_alongside_settings_json() {
        let ws = make_workspace("autodetect_one", &[("myproj.code-workspace", "{}")]);
        let resolved = resolve_vscode_targets(&ws, &empty_vscode_args()).unwrap();
        assert_eq!(resolved.settings_json, ws.join(".vscode/settings.json"));
        let cw = resolved
            .code_workspace
            .expect("autodetect should pick up the .code-workspace");
        assert_eq!(cw.path, ws.join("myproj.code-workspace"));
        // Default nesting key for .code-workspace.
        assert_eq!(cw.settings_key, "settings");
        let _ = std::fs::remove_dir_all(&ws);
    }

    #[test]
    fn autodetect_errors_on_multiple_code_workspaces() {
        let ws = make_workspace(
            "autodetect_multi",
            &[("a.code-workspace", "{}"), ("b.code-workspace", "{}")],
        );
        let err = resolve_vscode_targets(&ws, &empty_vscode_args())
            .unwrap_err()
            .to_string();
        assert!(
            err.contains("a.code-workspace") && err.contains("b.code-workspace"),
            "error should list both candidates, got: {err}"
        );
        // The message must point at BOTH escape hatches.
        assert!(err.contains("--code-workspace"));
        assert!(err.contains("--no-code-workspace"));
        let _ = std::fs::remove_dir_all(&ws);
    }

    #[test]
    fn no_code_workspace_skips_even_if_one_is_present() {
        let ws = make_workspace("skip_flag", &[("myproj.code-workspace", "{}")]);
        let mut args = empty_vscode_args();
        args.no_code_workspace = true;
        let resolved = resolve_vscode_targets(&ws, &args).unwrap();
        assert!(resolved.code_workspace.is_none());
        let _ = std::fs::remove_dir_all(&ws);
    }

    #[test]
    fn explicit_code_workspace_flag_forces_target() {
        // `--code-workspace` accepts a path that doesn't exist yet
        // (setup will create the file on write).
        let ws = Utf8PathBuf::from("/ws");
        let mut args = empty_vscode_args();
        args.code_workspace = Some(Utf8PathBuf::from("/ws/new.code-workspace"));
        let resolved = resolve_vscode_targets(&ws, &args).unwrap();
        let cw = resolved.code_workspace.unwrap();
        assert_eq!(cw.path, Utf8PathBuf::from("/ws/new.code-workspace"));
        assert_eq!(cw.settings_key, "settings");
    }

    #[test]
    fn explicit_settings_key_overrides_default() {
        let ws = Utf8PathBuf::from("/ws");
        let mut args = empty_vscode_args();
        args.code_workspace = Some(Utf8PathBuf::from("/ws/foo.code-workspace"));
        args.settings_key = Some("my_settings".to_owned());
        let resolved = resolve_vscode_targets(&ws, &args).unwrap();
        let cw = resolved.code_workspace.unwrap();
        assert_eq!(cw.settings_key, "my_settings");
    }

    #[test]
    fn explicit_settings_key_nests_under_arbitrary_key() {
        // For non-`.code-workspace` consumers who want nesting under
        // a custom key (e.g., a homegrown wrapper). Confirms the flag
        // works independent of the extension autodetect.
        let (ctx, _launcher_dir) = dummy_ctx();
        let ws = make_workspace("nest_custom", &[("settings.json", "{}")]);
        let path = ws.join("settings.json");
        let merged = merge_file(&path, &vscode_managed_keys(&ctx), Some("rust")).unwrap();
        let parsed = parse_merged(&merged);
        let nested = parsed
            .as_object()
            .unwrap()
            .get("rust")
            .expect("nested key should be created")
            .as_object()
            .unwrap();
        assert!(nested.contains_key(SERVER_PATH_KEY));
        let _ = std::fs::remove_dir_all(&ws);
    }

    // -----------------------------------------------------------------
    // Launcher install
    // -----------------------------------------------------------------

    #[test]
    fn write_launcher_paths_json_emits_three_logical_names() {
        let tmp = std::env::temp_dir().join(format!("setup_launcher_json_{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&tmp);
        std::fs::create_dir_all(&tmp).unwrap();
        let out = Utf8PathBuf::try_from(tmp.join("launcher_paths.json")).unwrap();
        write_launcher_paths_json(&out, &dummy_toolchain()).unwrap();
        let parsed: Value = serde_json::from_str(&fs::read_to_string(&out).unwrap()).unwrap();
        let obj = parsed.as_object().unwrap();
        assert_eq!(
            obj.get("rust_analyzer").unwrap().as_str().unwrap(),
            "/obase/external/ra/rust-analyzer"
        );
        assert_eq!(
            obj.get("rust_analyzer_proc_macro_srv")
                .unwrap()
                .as_str()
                .unwrap(),
            "/obase/external/ra/proc-macro-srv"
        );
        assert_eq!(
            obj.get("rustfmt").unwrap().as_str().unwrap(),
            "/obase/external/rfmt/rustfmt"
        );
        let _ = std::fs::remove_dir_all(&tmp);
    }

    // -----------------------------------------------------------------
    // JSONC support (via `serde_jsonrc`)
    // -----------------------------------------------------------------

    #[test]
    fn read_root_object_accepts_jsonc_file() {
        // End-to-end: a real `.vscode/settings.json`-flavored file
        // with comments + trailing commas parses cleanly through
        // read_root_object, no `--replace` fallback needed.
        let tmp = std::env::temp_dir().join(format!("setup_jsonc_root_{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&tmp);
        std::fs::create_dir_all(&tmp).unwrap();
        let path = Utf8PathBuf::try_from(tmp.join("settings.json")).unwrap();
        fs::write(
            &path,
            r#"{
  // team-wide indent
  "editor.tabSize": 4,
  "rust-analyzer.checkOnSave": true,
}
"#,
        )
        .unwrap();
        // Trivia-preserving round-trip: merging into a file with
        // comments and trailing commas keeps them intact.
        let managed: Vec<(String, ManagedValue)> = vec![];
        let merged = merge_file(&path, &managed, None).unwrap();
        assert!(
            merged.contains("// team-wide indent"),
            "line comment must survive: {merged}"
        );
        // Existing keys still there.
        let parsed = parse_merged(&merged);
        let obj = parsed.as_object().unwrap();
        assert_eq!(obj.get("editor.tabSize"), Some(&json!(4)));
        assert_eq!(obj.get("rust-analyzer.checkOnSave"), Some(&json!(true)));
        let _ = std::fs::remove_dir_all(&tmp);
    }
}
