//! Bootstrap an editor at the Bazel-provisioned rust-analyzer toolchain.
//!
//! `setup` is split into one subcommand per editor:
//!
//!   * `vscode` — writes/merges `.vscode/settings.json` with the four
//!     `rust-analyzer.*` keys + `files.excludeDirs` auto-populated from
//!     nested `Cargo.toml` discovery + matching `files.exclude` /
//!     `watcherExclude` / `search.exclude` for the Bazel convenience
//!     symlinks. Launcher scripts live in `.vscode/.rules_rust_analyzer/`.
//!   * `neovim` — writes the same launchers to `.rules_rust_analyzer/` at
//!     the workspace root (no `.vscode` references) and prints an
//!     `nvim-lspconfig` Lua snippet to stdout for the user to paste.
//!   * `helix` — writes the launchers to `.helix/.rules_rust_analyzer/`
//!     (Helix already uses `.helix/` for its per-project config) and
//!     prints a `languages.toml` snippet to stdout.
//!   * `print` — writes the launchers to `.rules_rust_analyzer/` and
//!     prints a generic JSON snippet (the same `rust-analyzer.*` keys
//!     VSCode uses; works with coc.nvim, helix-via-JSON, etc.).
//!
//! Common flags (`--workspace`, `--output-user-root`,
//! `--skip-proc-macro-server`, `--skip-rustfmt`) are declared once at the
//! top level with `global = true` and accepted on any subcommand. See the
//! `Cli` struct below.
//!
//! All launchers are template-substituted at install time:
//!
//!   * `__WORKSPACE_ROOT__` — absolute path to the workspace root,
//!     baked in so the launcher works no matter how deep it lives.
//!   * `__RULES_RUST_RA_OUTPUT_USER_ROOT__` — present only in the
//!     flycheck launcher; baked with the dedicated `--output_user_root`
//!     path for the flycheck Bazel server.

use std::{fs, path::Path};

use anyhow::{Context, Result};
use camino::{Utf8Path, Utf8PathBuf};
use clap::{Args, Parser, Subcommand};
use log::info;
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
// Launcher templates
// ---------------------------------------------------------------------------

/// Subdirectory name used (under the per-IDE launcher root) to hold our
/// managed launcher scripts. The leading dot keeps tidy file explorers
/// from surfacing it as workspace content; the rules_rust prefix prevents
/// collisions with anything else that might want to drop files into the
/// same parent dir.
const LAUNCHER_SUBDIR: &str = ".rules_rust_analyzer";

const RA_LAUNCHER_BASENAME: &str = "rust_analyzer";
const PMS_LAUNCHER_BASENAME: &str = "rust_analyzer_proc_macro_srv";
const RUSTFMT_LAUNCHER_BASENAME: &str = "rustfmt";
const FLYCHECK_LAUNCHER_BASENAME: &str = "flycheck";
const DISCOVER_LAUNCHER_BASENAME: &str = "discover_bazel_rust_project";

const RA_LAUNCHER_SH: &str = include_str!("../data/launcher_rust_analyzer.sh");
const PMS_LAUNCHER_SH: &str = include_str!("../data/launcher_rust_analyzer_proc_macro_srv.sh");
const RUSTFMT_LAUNCHER_SH: &str = include_str!("../data/launcher_rustfmt.sh");
const FLYCHECK_LAUNCHER_SH: &str = include_str!("../data/launcher_flycheck.sh");
const DISCOVER_LAUNCHER_SH: &str = include_str!("../data/launcher_discover_bazel_rust_project.sh");
const RA_LAUNCHER_BAT: &str = include_str!("../data/launcher_rust_analyzer.bat");
const PMS_LAUNCHER_BAT: &str = include_str!("../data/launcher_rust_analyzer_proc_macro_srv.bat");
const RUSTFMT_LAUNCHER_BAT: &str = include_str!("../data/launcher_rustfmt.bat");
const FLYCHECK_LAUNCHER_BAT: &str = include_str!("../data/launcher_flycheck.bat");
const DISCOVER_LAUNCHER_BAT: &str =
    include_str!("../data/launcher_discover_bazel_rust_project.bat");

/// Baked at install time with the absolute path to the workspace root.
/// Present in every launcher template — they need to find `bazel-bin/`
/// and where to `cd` for the build-if-missing fallback.
const WORKSPACE_ROOT_PLACEHOLDER: &str = "__WORKSPACE_ROOT__";

/// Baked at install time with the flycheck wrapper's dedicated
/// `--output_user_root`. Only the flycheck launcher templates contain
/// this placeholder — the other launchers don't call Bazel themselves.
const OUTPUT_USER_ROOT_PLACEHOLDER: &str = "__RULES_RUST_RA_OUTPUT_USER_ROOT__";

/// Baked at install time with the directory the discover binary should
/// write its merge cache into. Only the discover launcher templates
/// contain this placeholder — nothing else touches the cache.
const CACHE_DIR_PLACEHOLDER: &str = "__RULES_RUST_RA_CACHE_DIR__";

// ---------------------------------------------------------------------------
// Launcher flavor (POSIX vs Windows)
// ---------------------------------------------------------------------------

/// Shell flavor the host OS expects. Picked at runtime so a user on
/// macOS / Linux gets a POSIX shell script and a user on Windows gets a
/// `cmd.exe` batch file.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum LauncherFlavor {
    Posix,
    Windows,
}

impl LauncherFlavor {
    fn detect() -> Self {
        if std::env::consts::OS == "windows" {
            Self::Windows
        } else {
            Self::Posix
        }
    }

    fn extension(self) -> &'static str {
        match self {
            Self::Posix => "sh",
            Self::Windows => "bat",
        }
    }

    fn template_for(self, basename: &str) -> &'static str {
        match (self, basename) {
            (Self::Posix, b) if b == RA_LAUNCHER_BASENAME => RA_LAUNCHER_SH,
            (Self::Posix, b) if b == PMS_LAUNCHER_BASENAME => PMS_LAUNCHER_SH,
            (Self::Posix, b) if b == RUSTFMT_LAUNCHER_BASENAME => RUSTFMT_LAUNCHER_SH,
            (Self::Posix, b) if b == FLYCHECK_LAUNCHER_BASENAME => FLYCHECK_LAUNCHER_SH,
            (Self::Posix, b) if b == DISCOVER_LAUNCHER_BASENAME => DISCOVER_LAUNCHER_SH,
            (Self::Windows, b) if b == RA_LAUNCHER_BASENAME => RA_LAUNCHER_BAT,
            (Self::Windows, b) if b == PMS_LAUNCHER_BASENAME => PMS_LAUNCHER_BAT,
            (Self::Windows, b) if b == RUSTFMT_LAUNCHER_BASENAME => RUSTFMT_LAUNCHER_BAT,
            (Self::Windows, b) if b == FLYCHECK_LAUNCHER_BASENAME => FLYCHECK_LAUNCHER_BAT,
            (Self::Windows, b) if b == DISCOVER_LAUNCHER_BASENAME => DISCOVER_LAUNCHER_BAT,
            _ => panic!("no launcher template for {basename:?}"),
        }
    }
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

    /// `--output_user_root` to bake into the flycheck launcher (the
    /// dedicated Bazel server for on-save diagnostics, isolated from the
    /// user's primary `bazel build`). Picks a HOME-rooted default when
    /// unset — see [`default_output_user_root`]. Required on Windows for
    /// any non-trivial workspace: Bazel's path-length budget vs MAX_PATH.
    #[arg(long, global = true)]
    output_user_root: Option<Utf8PathBuf>,

    /// Directory the discover binary writes its merge cache into. Baked
    /// into the discover launcher as `$RULES_RUST_RA_CACHE_DIR`.
    /// Defaults to `<workspace>/.rules_rust_analyzer/cache/`.
    #[arg(long, global = true)]
    cache_dir: Option<Utf8PathBuf>,

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
    /// Write/merge `.vscode/settings.json` and install launchers under
    /// `.vscode/.rules_rust_analyzer/`.
    Vscode(VscodeArgs),

    /// Install launchers under `.rules_rust_analyzer/` (no `.vscode/`
    /// references) and print an `nvim-lspconfig` Lua snippet to stdout.
    Neovim,

    /// Install launchers under `.helix/.rules_rust_analyzer/` and print a
    /// `languages.toml` snippet to stdout.
    Helix,

    /// Install launchers under `.rules_rust_analyzer/` and print the
    /// editor-agnostic JSON snippet (same `rust-analyzer.*` keys VSCode
    /// uses; works with coc.nvim and similar JSON-config LSP clients).
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
        output_user_root,
        cache_dir,
        per_package_workspaces,
        ide,
    } = Cli::parse();

    let workspace = workspace.unwrap_or_else(|| Utf8PathBuf::from("."));
    let output_user_root = output_user_root.unwrap_or_else(|| default_output_user_root(&workspace));
    let cache_dir = cache_dir.unwrap_or_else(|| default_cache_dir(&workspace));
    let flavor = LauncherFlavor::detect();
    info!("Using --output_user_root = {output_user_root}");
    info!("Using --cache-dir = {cache_dir}");

    let ctx = SetupCtx {
        workspace,
        output_user_root,
        cache_dir,
        flavor,
        skip_proc_macro_server,
        skip_rustfmt,
        per_package_workspaces,
    };

    match ide {
        IdeCmd::Vscode(args) => run_vscode(&ctx, args),
        IdeCmd::Neovim => run_neovim(&ctx),
        IdeCmd::Helix => run_helix(&ctx),
        IdeCmd::Print => run_print(&ctx),
    }
}

/// Shared state computed once at startup and threaded through every
/// per-IDE runner. Keeping this in one struct avoids passing the same 5
/// arguments to every helper function.
struct SetupCtx {
    workspace: Utf8PathBuf,
    output_user_root: Utf8PathBuf,
    cache_dir: Utf8PathBuf,
    flavor: LauncherFlavor,
    skip_proc_macro_server: bool,
    skip_rustfmt: bool,
    per_package_workspaces: bool,
}

impl SetupCtx {
    /// List of (basename, write?) tuples for the launchers this run should
    /// emit. Flycheck and discover are always written — without them the
    /// runnable / discoverConfig commands point at non-existent paths.
    fn launchers(&self) -> Vec<&'static str> {
        let mut v = vec![RA_LAUNCHER_BASENAME];
        if !self.skip_proc_macro_server {
            v.push(PMS_LAUNCHER_BASENAME);
        }
        if !self.skip_rustfmt {
            v.push(RUSTFMT_LAUNCHER_BASENAME);
        }
        v.push(FLYCHECK_LAUNCHER_BASENAME);
        v.push(DISCOVER_LAUNCHER_BASENAME);
        v
    }
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
    let vscode_dir = output_path
        .parent()
        .map(|p| p.to_owned())
        .unwrap_or_else(|| ctx.workspace.join(".vscode"));
    let launcher_dir = vscode_dir.join(LAUNCHER_SUBDIR);

    let managed = vscode_managed_keys(ctx, &launcher_dir);
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
    write_all_launchers(ctx, &launcher_dir)?;

    info!(
        "{} {} key(s) in {} (+ {:?} launcher scripts in {})",
        if args.replace { "Wrote" } else { "Merged" },
        key_count,
        output_path,
        ctx.flavor,
        launcher_dir,
    );
    Ok(())
}

// ---------------------------------------------------------------------------
// Neovim subcommand
// ---------------------------------------------------------------------------

fn run_neovim(ctx: &SetupCtx) -> Result<()> {
    // Neovim has no canonical per-project dotdir — drop launchers at the
    // workspace root in `.rules_rust_analyzer/`.
    let launcher_dir = ctx.workspace.join(LAUNCHER_SUBDIR);
    write_all_launchers(ctx, &launcher_dir)?;
    let snippet = generate_neovim_lua(ctx, &launcher_dir);
    print_snippet_with_banner("Add this to your init.lua (nvim-lspconfig):", &snippet);
    info!(
        "Wrote {} launcher script(s) to {}",
        ctx.launchers().len(),
        launcher_dir,
    );
    Ok(())
}

// ---------------------------------------------------------------------------
// Helix subcommand
// ---------------------------------------------------------------------------

fn run_helix(ctx: &SetupCtx) -> Result<()> {
    // Helix already conventionally uses `.helix/` for per-project config
    // (`.helix/languages.toml` etc.), so nest the launchers there.
    let launcher_dir = ctx.workspace.join(".helix").join(LAUNCHER_SUBDIR);
    write_all_launchers(ctx, &launcher_dir)?;
    let snippet = generate_helix_toml(ctx, &launcher_dir);
    print_snippet_with_banner(
        "Add this to .helix/languages.toml at the workspace root:",
        &snippet,
    );
    info!(
        "Wrote {} launcher script(s) to {}",
        ctx.launchers().len(),
        launcher_dir,
    );
    Ok(())
}

// ---------------------------------------------------------------------------
// Print subcommand
// ---------------------------------------------------------------------------

fn run_print(ctx: &SetupCtx) -> Result<()> {
    let launcher_dir = ctx.workspace.join(LAUNCHER_SUBDIR);
    write_all_launchers(ctx, &launcher_dir)?;
    let snippet = generate_settings_json(ctx, &launcher_dir);
    print_snippet_with_banner(
        "Add this to your editor's rust-analyzer settings (coc-settings.json, etc.):",
        &snippet,
    );
    info!(
        "Wrote {} launcher script(s) to {}",
        ctx.launchers().len(),
        launcher_dir,
    );
    Ok(())
}

// ---------------------------------------------------------------------------
// Shared launcher writing
// ---------------------------------------------------------------------------

/// Write the full set of launchers `ctx` calls for to `dir`.
fn write_all_launchers(ctx: &SetupCtx, dir: &Utf8Path) -> Result<()> {
    for basename in ctx.launchers() {
        write_launcher(
            dir,
            basename,
            ctx.flavor,
            ctx.flavor.template_for(basename),
            &ctx.workspace,
            &ctx.output_user_root,
            &ctx.cache_dir,
        )?;
    }
    Ok(())
}

/// Compute the full launcher filename (basename + flavor extension).
fn launcher_filename(basename: &str, flavor: LauncherFlavor) -> String {
    format!("{basename}.{}", flavor.extension())
}

fn write_launcher(
    dir: &Utf8Path,
    basename: &str,
    flavor: LauncherFlavor,
    content: &str,
    workspace_root: &Utf8Path,
    output_user_root: &Utf8Path,
    cache_dir: &Utf8Path,
) -> Result<()> {
    let path = dir.join(launcher_filename(basename, flavor));
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).with_context(|| format!("creating directory {parent}"))?;
    }
    let body = bake_placeholders(
        content,
        workspace_root.as_str(),
        output_user_root.as_str(),
        cache_dir.as_str(),
    );
    fs::write(&path, body).with_context(|| format!("writing launcher {path}"))?;
    if flavor == LauncherFlavor::Posix {
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let mut perms = fs::metadata(&path)
                .with_context(|| format!("stat {path}"))?
                .permissions();
            // rwxr-xr-x: rust-analyzer (and the user from a shell) must be
            // able to exec this; group/other read+exec is harmless.
            perms.set_mode(0o755);
            fs::set_permissions(&path, perms).with_context(|| format!("chmod {path}"))?;
        }
    }
    Ok(())
}

/// Substitute the launcher template placeholders. `WORKSPACE_ROOT_PLACEHOLDER`
/// is present in every template; `OUTPUT_USER_ROOT_PLACEHOLDER` only in the
/// flycheck templates; `CACHE_DIR_PLACEHOLDER` only in the discover templates.
/// `replace` is a no-op when a placeholder is absent, so a single function
/// handles every template.
///
/// All substituted paths are normalized to forward slashes — see
/// [`to_forward_slashes`] for why.
fn bake_placeholders(
    template: &str,
    workspace_root: &str,
    output_user_root: &str,
    cache_dir: &str,
) -> String {
    template
        .replace(
            WORKSPACE_ROOT_PLACEHOLDER,
            &to_forward_slashes(workspace_root),
        )
        .replace(
            OUTPUT_USER_ROOT_PLACEHOLDER,
            &to_forward_slashes(output_user_root),
        )
        .replace(CACHE_DIR_PLACEHOLDER, &to_forward_slashes(cache_dir))
}

/// Normalize backslashes to forward slashes. Applied to every path we
/// hand to an editor's config file (settings.json, languages.toml, init.lua,
/// coc-settings.json) AND to every path we bake into a launcher script.
///
/// Why everywhere:
///   * In JSON / Lua / TOML, `\` is an escape character — Windows-native
///     paths (`C:\Users\me\...`) embed as invalid escape sequences and
///     break the parser.
///   * In shell launchers, `.sh` is POSIX (needs forward slashes), and
///     `.bat` on Windows accepts forward slashes everywhere we use them
///     (`set`, `if exist`, `cd`, child-process exec).
///   * Modern Windows tooling — VSCode, rust-analyzer, bazel.exe — all
///     accept forward slashes universally.
///
/// Applying one rule everywhere is simpler than per-context branching
/// and avoids the surprise of "snippet works, launcher doesn't" or vice
/// versa.
fn to_forward_slashes(path: &str) -> String {
    if cfg!(windows) {
        path.replace('\\', "/")
    } else {
        path.to_owned()
    }
}

// ---------------------------------------------------------------------------
// Output_user_root default + HOME resolution
// ---------------------------------------------------------------------------

/// Pick where the dedicated rules_rust Bazel server should live when the
/// user didn't pass `--output-user-root` explicitly.
///
/// Default search order:
///   1. `${HOME}/.vscode-server/.rules_rust_analyzer/output_user_root` —
///      preferred when that directory exists, which is the signal that
///      we're running inside VSCode Remote-SSH / Codespaces / WSL on the
///      remote side.
///   2. `${HOME}/.vscode/.rules_rust_analyzer/output_user_root` — the
///      local-VSCode case. `.vscode/` is created lazily on first run.
///   3. `<workspace>/.vscode/.rules_rust_analyzer/output_user_root` —
///      fallback when neither `HOME` nor `USERPROFILE` is set (CI shells,
///      bare containers). Workspace-local means it loses the per-user
///      cache-sharing property but at least keeps the shim from
///      exploding.
///
/// Per-workspace isolation is handled by Bazel itself: under
/// `--output_user_root`, Bazel hashes the workspace path into a subdir,
/// so multiple workspaces pointing at the same root each get their own
/// server / cache and never collide.
///
/// The default still uses `.vscode-server` / `.vscode` even for non-VSCode
/// IDEs — those directories are simply convenient HOME-relative places to
/// stash a Bazel output root, and they already get gitignored on most
/// machines. Override with `--output-user-root` if you'd rather keep it
/// elsewhere.
fn default_output_user_root(workspace: &Utf8Path) -> Utf8PathBuf {
    if let Some(home) = home_dir() {
        let server = home.join(".vscode-server");
        if server.is_dir() {
            return server.join(".rules_rust_analyzer").join("output_user_root");
        }
        return home
            .join(".vscode")
            .join(".rules_rust_analyzer")
            .join("output_user_root");
    }
    workspace
        .join(".vscode")
        .join(".rules_rust_analyzer")
        .join("output_user_root")
}

/// Default merge-cache directory: workspace-local
/// `.rules_rust_analyzer/cache/`. Mirrored from `cache::CACHE_DIR_REL`
/// (we don't depend on `gen_rust_project_lib` here just for that one
/// constant — it's small enough to duplicate, and a test catches any
/// drift if either side moves).
fn default_cache_dir(workspace: &Utf8Path) -> Utf8PathBuf {
    workspace.join(".rules_rust_analyzer").join("cache")
}

/// Cross-platform user home. Reads `HOME` on POSIX-y systems and
/// `USERPROFILE` on Windows — the same two variables `dirs::home_dir`
/// consults, without taking the dep.
fn home_dir() -> Option<Utf8PathBuf> {
    let var = if cfg!(windows) { "USERPROFILE" } else { "HOME" };
    std::env::var(var)
        .ok()
        .filter(|s| !s.is_empty())
        .map(Utf8PathBuf::from)
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
    let ra_rel = launcher_workspace_path(
        &ctx.workspace,
        launcher_dir,
        &launcher_filename(RA_LAUNCHER_BASENAME, ctx.flavor),
    );
    let pms_rel = launcher_workspace_path(
        &ctx.workspace,
        launcher_dir,
        &launcher_filename(PMS_LAUNCHER_BASENAME, ctx.flavor),
    );
    let rustfmt_rel = launcher_workspace_path(
        &ctx.workspace,
        launcher_dir,
        &launcher_filename(RUSTFMT_LAUNCHER_BASENAME, ctx.flavor),
    );
    let discover_rel = launcher_workspace_path(
        &ctx.workspace,
        launcher_dir,
        &launcher_filename(DISCOVER_LAUNCHER_BASENAME, ctx.flavor),
    );
    let bazel_outputs = || vec![(BAZEL_OUTPUTS_GLOB.to_string(), Value::Bool(true))];
    // `{arg}` opts into per-package workspace switching. See `--per-package-workspaces`.
    let discover_command = if ctx.per_package_workspaces {
        json!([discover_rel, "{arg}"])
    } else {
        json!([discover_rel])
    };
    let mut out = vec![
        (
            DISCOVER_CONFIG_KEY.to_string(),
            ManagedValue::Replace(json!({
                // Point at the launcher script (not `bazel run`) — see
                // launcher_discover_bazel_rust_project.sh for why.
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
            ManagedValue::Replace(Value::String(ra_rel)),
        ),
    ];
    if !ctx.skip_proc_macro_server {
        out.push((
            PROC_MACRO_SRV_KEY.to_string(),
            ManagedValue::Replace(Value::String(pms_rel)),
        ));
    }
    if !ctx.skip_rustfmt {
        // overrideCommand is an argv array; the launcher takes file contents
        // on stdin and writes formatted output to stdout, which is the
        // contract rust-analyzer expects.
        out.push((
            RUSTFMT_OVERRIDE_KEY.to_string(),
            ManagedValue::Replace(json!([rustfmt_rel])),
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

/// Compute the `${workspaceFolder}`-relative path for a launcher script
/// that will be written under the launcher directory. Falls back to an
/// absolute path when the launcher is outside the workspace (unusual but
/// possible if the caller passes a custom `--output`).
///
/// Always returns a forward-slash path: VSCode accepts both separators
/// on Windows but the JSON we emit needs to be portable, and `\` is a
/// JSON escape character.
fn launcher_workspace_path(
    workspace_root: &Utf8Path,
    launcher_dir: &Utf8Path,
    name: &str,
) -> String {
    let abs = launcher_dir.join(name);
    let raw = match abs.strip_prefix(workspace_root) {
        Ok(rel) => format!("${{workspaceFolder}}/{rel}"),
        Err(_) => abs.to_string(),
    };
    to_forward_slashes(&raw)
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

/// Build the absolute path to a launcher script inside `launcher_dir`.
/// Non-VSCode snippets use absolute paths because their config formats
/// don't have a `${workspaceFolder}` equivalent (Lua / coc-settings.json
/// / Helix TOML all expand only env vars at most).
///
/// Always returns a forward-slash path so the result is safe to embed
/// in JSON / Lua / TOML on Windows. See [`to_forward_slashes`].
fn launcher_abs_path(launcher_dir: &Utf8Path, basename: &str, flavor: LauncherFlavor) -> String {
    let raw = launcher_dir
        .join(launcher_filename(basename, flavor))
        .to_string();
    to_forward_slashes(&raw)
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

/// `nvim-lspconfig` Lua snippet. The user pastes this into their
/// `init.lua` (or similar). Absolute paths are baked in at install
/// time — re-run `setup neovim` if the workspace moves.
fn generate_neovim_lua(ctx: &SetupCtx, launcher_dir: &Utf8Path) -> String {
    let ra = launcher_abs_path(launcher_dir, RA_LAUNCHER_BASENAME, ctx.flavor);
    let discover = launcher_abs_path(launcher_dir, DISCOVER_LAUNCHER_BASENAME, ctx.flavor);
    let proc_macro = opt_block(!ctx.skip_proc_macro_server, NEOVIM_LUA_PROC_MACRO, |t| {
        let pms = launcher_abs_path(launcher_dir, PMS_LAUNCHER_BASENAME, ctx.flavor);
        t.replace(TPL_PMS_LAUNCHER, &pms)
    });
    let rustfmt = opt_block(!ctx.skip_rustfmt, NEOVIM_LUA_RUSTFMT, |t| {
        let path = launcher_abs_path(launcher_dir, RUSTFMT_LAUNCHER_BASENAME, ctx.flavor);
        t.replace(TPL_RUSTFMT_LAUNCHER, &path)
    });
    let excludes = match cargo_excludes_as_quoted_list(ctx) {
        Some(entries) => NEOVIM_LUA_EXCLUDES.replace(TPL_EXCLUDE_ENTRIES, &entries),
        None => String::new(),
    };
    NEOVIM_LUA_TEMPLATE
        .replace(TPL_RA_LAUNCHER, &ra)
        .replace(TPL_DISCOVER_LAUNCHER, &discover)
        .replace(TPL_DISCOVER_PER_PACKAGE_ARG, per_package_suffix(ctx))
        .replace(TPL_OPT_PROC_MACRO, &proc_macro)
        .replace(TPL_OPT_RUSTFMT, &rustfmt)
        .replace(TPL_OPT_EXCLUDES, &excludes)
}

/// Helix `languages.toml` snippet. Pasted under
/// `.helix/languages.toml`. Absolute paths baked in (Helix's TOML
/// parser doesn't expand env or workspace vars).
fn generate_helix_toml(ctx: &SetupCtx, launcher_dir: &Utf8Path) -> String {
    let ra = launcher_abs_path(launcher_dir, RA_LAUNCHER_BASENAME, ctx.flavor);
    let discover = launcher_abs_path(launcher_dir, DISCOVER_LAUNCHER_BASENAME, ctx.flavor);
    let proc_macro = opt_block(!ctx.skip_proc_macro_server, HELIX_TOML_PROC_MACRO, |t| {
        let pms = launcher_abs_path(launcher_dir, PMS_LAUNCHER_BASENAME, ctx.flavor);
        t.replace(TPL_PMS_LAUNCHER, &pms)
    });
    let rustfmt = opt_block(!ctx.skip_rustfmt, HELIX_TOML_RUSTFMT, |t| {
        let path = launcher_abs_path(launcher_dir, RUSTFMT_LAUNCHER_BASENAME, ctx.flavor);
        t.replace(TPL_RUSTFMT_LAUNCHER, &path)
    });
    let excludes = match cargo_excludes_as_quoted_list(ctx) {
        Some(entries) => HELIX_TOML_EXCLUDES.replace(TPL_EXCLUDE_ENTRIES, &entries),
        None => String::new(),
    };
    HELIX_TOML_TEMPLATE
        .replace(TPL_RA_LAUNCHER, &ra)
        .replace(TPL_DISCOVER_LAUNCHER, &discover)
        .replace(TPL_DISCOVER_PER_PACKAGE_ARG, per_package_suffix(ctx))
        .replace(TPL_OPT_PROC_MACRO, &proc_macro)
        .replace(TPL_OPT_RUSTFMT, &rustfmt)
        .replace(TPL_OPT_EXCLUDES, &excludes)
}

/// Editor-agnostic JSON snippet using the standard `rust-analyzer.*`
/// keys. Works with coc.nvim (`coc-settings.json`), helix-via-JSON,
/// vim-lsp, etc. — anything that lets you set `rust-analyzer` settings
/// as JSON.
fn generate_settings_json(ctx: &SetupCtx, launcher_dir: &Utf8Path) -> String {
    let ra = launcher_abs_path(launcher_dir, RA_LAUNCHER_BASENAME, ctx.flavor);
    let discover = launcher_abs_path(launcher_dir, DISCOVER_LAUNCHER_BASENAME, ctx.flavor);
    let proc_macro = opt_block(!ctx.skip_proc_macro_server, SETTINGS_JSON_PROC_MACRO, |t| {
        let pms = launcher_abs_path(launcher_dir, PMS_LAUNCHER_BASENAME, ctx.flavor);
        t.replace(TPL_PMS_LAUNCHER, &pms)
    });
    let rustfmt = opt_block(!ctx.skip_rustfmt, SETTINGS_JSON_RUSTFMT, |t| {
        let path = launcher_abs_path(launcher_dir, RUSTFMT_LAUNCHER_BASENAME, ctx.flavor);
        t.replace(TPL_RUSTFMT_LAUNCHER, &path)
    });
    let excludes = match cargo_excludes_as_quoted_list(ctx) {
        Some(entries) => SETTINGS_JSON_EXCLUDES.replace(TPL_EXCLUDE_ENTRIES, &entries),
        None => String::new(),
    };
    SETTINGS_JSON_TEMPLATE
        .replace(TPL_RA_LAUNCHER, &ra)
        .replace(TPL_DISCOVER_LAUNCHER, &discover)
        .replace(TPL_DISCOVER_PER_PACKAGE_ARG, per_package_suffix(ctx))
        .replace(TPL_OPT_PROC_MACRO, &proc_macro)
        .replace(TPL_OPT_RUSTFMT, &rustfmt)
        .replace(TPL_OPT_EXCLUDES, &excludes)
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    fn dummy_ctx() -> (SetupCtx, Utf8PathBuf) {
        let workspace = Utf8PathBuf::from("/ws");
        let launcher_dir = workspace.join(".vscode").join(LAUNCHER_SUBDIR);
        let ctx = SetupCtx {
            cache_dir: default_cache_dir(&workspace),
            workspace,
            output_user_root: Utf8PathBuf::from(
                "/home/u/.vscode/.rules_rust_analyzer/output_user_root",
            ),
            flavor: LauncherFlavor::Posix,
            skip_proc_macro_server: false,
            skip_rustfmt: false,
            per_package_workspaces: false,
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
        // Managed key overwritten and points at the namespaced launcher dir.
        assert_eq!(
            obj.get(SERVER_PATH_KEY).unwrap().as_str().unwrap(),
            "${workspaceFolder}/.vscode/.rules_rust_analyzer/rust_analyzer.sh"
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
    fn rustfmt_override_is_argv_array_pointing_at_launcher() {
        let (ctx, launcher_dir) = dummy_ctx();
        let keys = vscode_managed_keys(&ctx, &launcher_dir);
        let val = replace_value(&keys, RUSTFMT_OVERRIDE_KEY);
        let arr = val.as_array().unwrap();
        assert_eq!(arr.len(), 1);
        assert_eq!(
            arr[0].as_str().unwrap(),
            "${workspaceFolder}/.vscode/.rules_rust_analyzer/rustfmt.sh"
        );
    }

    #[test]
    fn launcher_path_falls_back_to_absolute_when_outside_workspace() {
        let workspace = Utf8PathBuf::from("/ws");
        let outside = Utf8PathBuf::from("/elsewhere/.vscode/.rules_rust_analyzer");
        let path = launcher_workspace_path(&workspace, &outside, "rust_analyzer.sh");
        assert!(path.starts_with("/elsewhere"));
        assert!(!path.contains("workspaceFolder"));
    }

    #[test]
    fn windows_flavor_emits_bat_extension() {
        let (mut ctx, launcher_dir) = dummy_ctx();
        ctx.flavor = LauncherFlavor::Windows;
        let keys = vscode_managed_keys(&ctx, &launcher_dir);
        let server = replace_value(&keys, SERVER_PATH_KEY).as_str().unwrap();
        assert!(
            server.ends_with("/rust_analyzer.bat"),
            "expected .bat extension on Windows; got {server}"
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
    fn bake_placeholders_substitutes_all_three_placeholders() {
        let template = "WS=\"__WORKSPACE_ROOT__\"\nOUR=\"__RULES_RUST_RA_OUTPUT_USER_ROOT__\"\nCACHE=\"__RULES_RUST_RA_CACHE_DIR__\"\n";
        let baked = bake_placeholders(template, "/abs/ws", "/home/u/out", "/abs/ws/cache");
        assert!(baked.contains("WS=\"/abs/ws\""));
        assert!(baked.contains("OUR=\"/home/u/out\""));
        assert!(baked.contains("CACHE=\"/abs/ws/cache\""));
        assert!(!baked.contains(WORKSPACE_ROOT_PLACEHOLDER));
        assert!(!baked.contains(OUTPUT_USER_ROOT_PLACEHOLDER));
        assert!(!baked.contains(CACHE_DIR_PLACEHOLDER));
    }

    #[test]
    fn cache_dir_placeholder_is_present_only_in_discover_launchers() {
        // Discover launchers need the cache-dir env var baked in; nothing
        // else interacts with the cache. A regression that leaks the
        // placeholder into another template would ship a launcher that
        // silently sets a bogus env var on every invocation.
        assert!(DISCOVER_LAUNCHER_SH.contains(CACHE_DIR_PLACEHOLDER));
        assert!(DISCOVER_LAUNCHER_BAT.contains(CACHE_DIR_PLACEHOLDER));
        for (name, body) in [
            ("ra.sh", RA_LAUNCHER_SH),
            ("ra.bat", RA_LAUNCHER_BAT),
            ("pms.sh", PMS_LAUNCHER_SH),
            ("pms.bat", PMS_LAUNCHER_BAT),
            ("rustfmt.sh", RUSTFMT_LAUNCHER_SH),
            ("rustfmt.bat", RUSTFMT_LAUNCHER_BAT),
            ("flycheck.sh", FLYCHECK_LAUNCHER_SH),
            ("flycheck.bat", FLYCHECK_LAUNCHER_BAT),
        ] {
            assert!(
                !body.contains(CACHE_DIR_PLACEHOLDER),
                "{name} unexpectedly contains the cache-dir placeholder"
            );
        }
    }

    #[test]
    fn every_launcher_template_contains_workspace_root_placeholder() {
        // WORKSPACE_ROOT is in EVERY launcher (they all need to find
        // bazel-bin). A regression that dropped it would result in a
        // launcher that fails with `cd: __WORKSPACE_ROOT__: No such file`.
        for (name, body) in [
            ("ra.sh", RA_LAUNCHER_SH),
            ("ra.bat", RA_LAUNCHER_BAT),
            ("pms.sh", PMS_LAUNCHER_SH),
            ("pms.bat", PMS_LAUNCHER_BAT),
            ("rustfmt.sh", RUSTFMT_LAUNCHER_SH),
            ("rustfmt.bat", RUSTFMT_LAUNCHER_BAT),
            ("flycheck.sh", FLYCHECK_LAUNCHER_SH),
            ("flycheck.bat", FLYCHECK_LAUNCHER_BAT),
            ("discover.sh", DISCOVER_LAUNCHER_SH),
            ("discover.bat", DISCOVER_LAUNCHER_BAT),
        ] {
            assert!(
                body.contains(WORKSPACE_ROOT_PLACEHOLDER),
                "{name} missing {WORKSPACE_ROOT_PLACEHOLDER}"
            );
        }
    }

    #[test]
    fn only_flycheck_launchers_contain_output_user_root_placeholder() {
        // The flycheck wrapper spawns `bazel build` internally and needs
        // a dedicated output_user_root; setup bakes the path in via the
        // placeholder. The other launchers exec their target directly and
        // never call Bazel themselves, so they MUST NOT contain the
        // placeholder — if one snuck in, the unsubstituted string would
        // survive into the on-disk launcher and break the user's setup
        // with a cryptic Bazel path error.
        assert!(FLYCHECK_LAUNCHER_SH.contains(OUTPUT_USER_ROOT_PLACEHOLDER));
        assert!(FLYCHECK_LAUNCHER_BAT.contains(OUTPUT_USER_ROOT_PLACEHOLDER));
        for (name, body) in [
            ("ra.sh", RA_LAUNCHER_SH),
            ("ra.bat", RA_LAUNCHER_BAT),
            ("pms.sh", PMS_LAUNCHER_SH),
            ("pms.bat", PMS_LAUNCHER_BAT),
            ("rustfmt.sh", RUSTFMT_LAUNCHER_SH),
            ("rustfmt.bat", RUSTFMT_LAUNCHER_BAT),
            ("discover.sh", DISCOVER_LAUNCHER_SH),
            ("discover.bat", DISCOVER_LAUNCHER_BAT),
        ] {
            assert!(
                !body.contains(OUTPUT_USER_ROOT_PLACEHOLDER),
                "{name} unexpectedly contains the output_user_root placeholder"
            );
        }
    }

    #[test]
    fn default_output_user_root_falls_back_to_workspace_without_home() {
        // Isolate from the test runner's real HOME / USERPROFILE so the
        // fallback branch is actually exercised. We restore both because
        // other tests in this binary may rely on them.
        let saved_home = std::env::var("HOME").ok();
        let saved_userprofile = std::env::var("USERPROFILE").ok();
        // SAFETY: tests are single-threaded with --test-threads=1 in
        // Bazel's default rust_test config, so env mutation is fine.
        unsafe {
            std::env::remove_var("HOME");
            std::env::remove_var("USERPROFILE");
        }
        let ws = Utf8PathBuf::from("/workspace");
        let resolved = default_output_user_root(&ws);
        assert_eq!(
            resolved,
            Utf8PathBuf::from("/workspace/.vscode/.rules_rust_analyzer/output_user_root"),
        );
        unsafe {
            if let Some(v) = saved_home {
                std::env::set_var("HOME", v);
            }
            if let Some(v) = saved_userprofile {
                std::env::set_var("USERPROFILE", v);
            }
        }
    }

    #[test]
    fn neovim_snippet_contains_launcher_paths_and_lens_enable() {
        let (ctx, _) = dummy_ctx();
        let launcher_dir = ctx.workspace.join(LAUNCHER_SUBDIR);
        let snippet = generate_neovim_lua(&ctx, &launcher_dir);
        assert!(snippet.contains("require(\"lspconfig\").rust_analyzer.setup"));
        assert!(snippet.contains("/ws/.rules_rust_analyzer/rust_analyzer.sh"));
        assert!(snippet.contains("/ws/.rules_rust_analyzer/discover_bazel_rust_project.sh"));
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
        assert!(snippet.contains("/ws/.helix/.rules_rust_analyzer/rust_analyzer.sh"));
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

    /// Sanity-check that the templates ARE actually template-shaped: an
    /// edit that drops a placeholder would otherwise silently produce
    /// snippets with `__OPT_FOO__` literal text baked in.
    /// Default (per-package off) → discover command has only the launcher
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
            "default: discover command should be [launcher]; got {cmd:?}"
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
            "per-package on: discover command should be [launcher, \"{{arg}}\"]; got {cmd:?}"
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
