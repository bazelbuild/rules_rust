# Rust Analyzer

[rust-analyzer](https://rust-analyzer.github.io/) needs a project model to do its job.
For [non-Cargo projects](https://rust-analyzer.github.io/manual.html#non-cargo-based-projects),
that comes from [project auto-discovery](https://rust-analyzer.github.io/manual.html#rust-analyzer.workspace.discoverConfig):
rust-analyzer invokes a build-system-specific command and reads the project description
from its stdout. `rules_rust` provides that command (`discover_bazel_rust_project`) and
a one-shot installer (`setup`) that wires it up for you.

Performance is good enough on large monorepos: the discover binary reads the per-crate
spec files Bazel's already producing via the [Build Event Protocol][bep] (no separate
`bazel aquery` round-trip), and the assembled project JSON is memoized in a local
content-addressed cache.

[bep]: https://bazel.build/remote/bep

## Quick start (VSCode)

Two steps from a clean checkout to a working IDE:

1. Install the [rust-analyzer extension](https://marketplace.visualstudio.com/items?itemName=rust-lang.rust-analyzer).
2. Write the `.vscode/settings.json` keys that wire everything together:
   ```
   bazel run @rules_rust//tools/rust_analyzer:setup -- vscode
   ```

Reload the VSCode window. rust-analyzer will run the Bazel-bundled LSP server, discover
the project on the fly via `discover_bazel_rust_project`, run on-save flycheck via
`flycheck`, and auto-reload when any of the watched BUILD files change.

`setup` is the one entry point for every editor — `vscode`, `neovim`, `helix`, `print`
are subcommands; see [Editors other than VSCode](#editors-other-than-vscode) below for
the other three. The shared flags (`--workspace`, `--output-user-root`,
`--skip-proc-macro-server`, `--skip-rustfmt`) accept on any subcommand.

`setup vscode` writes two artifacts:

- Managed keys in `.vscode/settings.json`:
  `rust-analyzer.workspace.discoverConfig`, `rust-analyzer.server.path`,
  `rust-analyzer.procMacro.server`, `rust-analyzer.rustfmt.overrideCommand`,
  `rust-analyzer.files.excludeDirs` (auto-populated with every immediate
  subdirectory that contains a `Cargo.toml`, so rust-analyzer doesn't load
  those as parallel cargo workspaces in addition to the discoverConfig
  project), and matching `files.exclude` / `files.watcherExclude` /
  `search.exclude` entries for the Bazel convenience symlinks. User keys are
  preserved on re-runs.
- Five small launcher scripts under `.vscode/.rules_rust_analyzer/`
  (`rust_analyzer`, `rust_analyzer_proc_macro_srv`, `rustfmt`, `flycheck`,
  `discover_bazel_rust_project`; `.sh` on POSIX, `.bat` on Windows). The
  launchers — not `bazel-bin/` — are what the LSP / proc-macro /
  rustfmt / discover / flycheck settings point at, so `bazel clean` doesn't
  break the IDE: if the underlying wrapper binary is missing, the next launch
  rebuilds it on demand; otherwise the launcher exec's it directly without
  touching Bazel at all. That fast path matters because **Bazel serializes
  commands per output_base** — wrapping every LSP / discover / format call
  in `bazel run` would deadlock the IDE behind any concurrent
  `bazel build` / CI run.

With all keys wired up, **users do not need a host rust install**: rust-analyzer,
proc-macro-srv, and rustfmt all come from the Bazel toolchain. `editor.formatOnSave`
calls rust-analyzer's LSP formatting request, which spawns the rustfmt launcher,
which exec's the Bazel-built rustfmt wrapper.

Re-run `setup vscode` any time. Flags:

- `--dry-run` previews the settings JSON. (vscode subcommand only)
- `--replace` starts from scratch. (vscode subcommand only)
- `--skip-proc-macro-server` leaves the proc-macro key alone.
- `--skip-rustfmt` leaves the formatter key alone (use the host rustfmt instead).
- `--output-user-root <abs-path>` overrides where the flycheck wrapper's
  dedicated Bazel server lives (its `--output_user_root`). Default:
  `${HOME}/.vscode-server/.rules_rust_analyzer/output_user_root` when that
  directory exists (remote-SSH / Codespaces), else
  `${HOME}/.vscode/.rules_rust_analyzer/output_user_root`. Required on
  Windows for any non-trivial workspace: Bazel's path-length budget plus
  the deepest `external/+...//bin/...` paths it generates can blow MAX_PATH;
  point this at something short like `C:\ra-ob` or `D:\bzl\ra`.
- `--per-package-workspaces` opts into rust-analyzer's per-package
  workspace switching. Off by default — the whole workspace gets indexed
  as one project, which is the simpler / less surprising default and
  what most users want. Turn it on for monorepos where indexing the
  whole graph hurts LSP responsiveness; the trade-off is that
  rust-analyzer reloads (and re-runs discover) every time you jump to a
  file in a different package, AND that dependents of the package you're
  working on aren't indexed.

### What you get in the editor

- **`▶ Run Tests`** codelens on every `#[cfg(test)] mod ...` (runs all
  tests in the module via `bazel test`).
- **`▶ Run Test`** codelens on every individual `#[test]` function (runs
  exactly that test via `bazel test --test_arg=--exact --test_arg=<id>`).
- **On-save squiggles** from rustc diagnostics, via the flycheck wrapper.
- **Format-on-save** via the Bazel-toolchain rustfmt.
- **Workspace reload** when any watched BUILD / MODULE.bazel file changes.

### Debugging

The `▶ Debug` codelens that VSCode displays next to `#[test]` functions
**does not work** with this setup, and we can't fix it from the
rules_rust side. The VSCode rust-analyzer extension's debug handler
([`editors/code/src/debug.ts`][ra-debug] in upstream) hard-bails on
shell runnables — it only knows how to debug crates whose runnable is
shaped as a cargo invocation, because it shells out to cargo with
`--message-format=json --no-run` to discover the test binary path.
Bazel projects emit shell runnables (`bazel test ...`), so the extension
silently returns `undefined` and no debug session starts. Lifting this
would need a PR upstream to teach the extension how to extract a binary
path from a shell runnable.

**The supported debug path is `.vscode/launch.json` + F5**, via the
[`gen_launch_json` tool][gen-launch-json] this repository ships:

```
bazel run @rules_rust//tools/vscode:gen_launch_json
```

It queries Bazel for every `rust_binary` / `rust_test` target in the
workspace and writes a `.vscode/launch.json` where each entry uses
CodeLLDB's `targetCreateCommands` with a Python script that runs
`bazel run --compilation_mode=dbg --strip=never --run_under=...
<target>` to build + extract the binary path, then attaches LLDB. Pure
Bazel invocation under the hood; works for any target without
custom config. Re-run when targets change. Install
[CodeLLDB][codelldb] (or `lldb-dap` / `vscode-lldb`) first.

Caveat: per-target only, not per-`#[test]`-fn. Once a debug session is
attached, set a breakpoint in the test you care about and re-run the
target — libtest's test selection happens inside the binary, so a single
launch config covers every test in the target.

[ra-debug]: https://github.com/rust-lang/rust-analyzer/blob/master/editors/code/src/debug.ts
[gen-launch-json]: https://github.com/bazelbuild/rules_rust/blob/main/tools/vscode/src/bin/gen_launch_json.rs
[codelldb]: https://marketplace.visualstudio.com/items?itemName=vadimcn.vscode-lldb

## On-save diagnostics (flycheck)

The assembled `rust-project.json` wires a `flycheck` runnable that
rust-analyzer invokes whenever a file is saved. The runnable points at the
flycheck launcher script (`.vscode/.rules_rust_analyzer/flycheck.sh` on
POSIX, `.bat` on Windows), which exec's the `flycheck` wrapper binary —
`setup` writes both.

The wrapper runs `bazel build` on the saved file's owning crate with
`error_format=json` and `--keep_going`, harvests every action's
stderr from the build's Build Event Protocol stream, filters for rustc
JSON messages, and streams them to stdout for rust-analyzer to render
as inline diagnostics.

The wrapper uses a **dedicated `--output_user_root`** (the path baked into
the flycheck launcher at `setup` time; see `--output-user-root`
above) so its `error_format=json` / `rustc_output_diagnostics=true` flags
don't thrash the user's primary `bazel build` analysis cache. The two
Bazel servers — yours and the flycheck one — are fully isolated.

Failed actions are deliberately supported: rustc still emits its
diagnostics to stderr before exiting non-zero, and BEP captures that
stderr regardless of action outcome. The wrapper forwards Bazel's exit
code so rust-analyzer can distinguish "build succeeded with no errors"
from "build tool itself broke" (e.g. a BUILD-file syntax error).

Downstream targets of a failed action don't get rebuilt — `--keep_going`
lets other *independent* targets in the graph continue, but anything
that depends on the failed crate is skipped. The user sees diagnostics
on the broken crate; the cascade further down the graph is invisible
until they fix the root cause and save again. This matches cargo's
flycheck behavior (a `cargo check` that fails on `foo` doesn't go on to
check `foo`'s dependents either) and is what users expect.

No `rust-analyzer.check.overrideCommand` configuration is needed —
flycheck is on by default.

## Bazel-provided rust-analyzer

The registered `rust_analyzer_toolchain` ships the rust-analyzer binary and
proc-macro server matched to the toolchain's rustc/sysroot. Pointing your
editor at those binaries — instead of the rust-analyzer extension's bundled
copy — guarantees the LSP behavior agrees with `bazel build` and avoids
proc-macro ABI mismatches.

Two stable wrapper targets are provided:

```
bazel build @rules_rust//tools/rust_analyzer:rust_analyzer
bazel build @rules_rust//tools/rust_analyzer:rust_analyzer_proc_macro_srv
```

VSCode users should NOT point `server.path` directly at `bazel-bin/...` —
`bazel clean` would silently break the LSP until the next manual rebuild.
**Use `setup` (see Quick Start above) instead.** It writes a launcher
script at `.vscode/.rules_rust_analyzer/rust_analyzer.sh` that exec's the
wrapper if it's already built and rebuilds it on demand if not, so the IDE
keeps working across `bazel clean`s.

For editors `setup` doesn't target, the same launcher pattern is the
right shape. A minimal `rust_analyzer.sh`:

```sh
#!/bin/sh
set -e
WORKSPACE="$(cd "$(dirname "$0")/.." && pwd)"
WRAPPER="$WORKSPACE/bazel-bin/tools/rust_analyzer/rust_analyzer"
if [ ! -x "$WRAPPER" ]; then
    cd "$WORKSPACE" && bazel build @rules_rust//tools/rust_analyzer:rust_analyzer >&2
fi
# rust-analyzer is itself a rules_rust binary when it spawns us — strip its
# RUNFILES_* env so our wrapper resolves its OWN runfiles via argv[0].
unset RUNFILES_DIR RUNFILES_MANIFEST_FILE
exec "$WRAPPER" "$@"
```

Point your editor's `server.path` at that script. Setting `server.path` alone is
usually sufficient because rust-analyzer uses itself as the proc-macro server
when no explicit one is configured — the separate `rust_analyzer_proc_macro_srv`
wrapper is only needed when an editor pins a different rust-analyzer version and
you want the proc-macro ABI to track the Bazel rustc.

## Editors other than VSCode

Each non-VSCode IDE has its own subcommand. The subcommand:

1. Installs the launcher scripts at an IDE-appropriate location (no
   `.vscode/` references for non-VSCode editors).
2. Prints a ready-to-paste config snippet to stdout with the launcher
   paths baked in.

You paste the snippet into the editor's config file. The launchers are
self-contained — re-running setup updates them with current workspace /
output-user-root paths but doesn't change the snippet shape, so the
config in your editor file keeps working unless paths actually move.

### Neovim

```
bazel run @rules_rust//tools/rust_analyzer:setup -- neovim
```

Installs launchers under `<workspace>/.rules_rust_analyzer/` and prints
an `nvim-lspconfig` Lua snippet to stdout. Pipe it into your config or
copy-paste:

```
bazel run @rules_rust//tools/rust_analyzer:setup -- neovim > /tmp/ra.lua
```

The snippet looks like:

```lua
require("lspconfig").rust_analyzer.setup({
  cmd = { "/abs/workspace/.rules_rust_analyzer/rust_analyzer.sh" },
  settings = {
    ["rust-analyzer"] = {
      workspace = {
        discoverConfig = {
          command = { "/abs/workspace/.rules_rust_analyzer/discover_bazel_rust_project.sh", "{arg}" },
          progressLabel = "rules_rust",
          filesToWatch = { "BUILD", "BUILD.bazel", "MODULE.bazel", "WORKSPACE", "WORKSPACE.bazel" },
        },
      },
      procMacro = { server = "/abs/workspace/.rules_rust_analyzer/rust_analyzer_proc_macro_srv.sh" },
      rustfmt = { overrideCommand = { "/abs/workspace/.rules_rust_analyzer/rustfmt.sh" } },
      files = { excludeDirs = { "cargo", "crate_universe" } },
      lens = { enable = true },
    },
  },
})
```

Drop into your `init.lua` (or a plugin module). Absolute paths are
baked at install time — re-run `setup neovim` if the workspace moves.

For users on [`rustaceanvim`](https://github.com/mrcjkb/rustaceanvim)
instead: pass the same `cmd` and `settings` table via its `server`
option (`vim.g.rustaceanvim = { server = { cmd = ..., settings = ... } }`).

### Helix

```
bazel run @rules_rust//tools/rust_analyzer:setup -- helix
```

Installs launchers under `<workspace>/.helix/.rules_rust_analyzer/`
(Helix already conventionally uses `.helix/` for per-project config) and
prints a `languages.toml` snippet for you to paste into
`<workspace>/.helix/languages.toml`:

```toml
[language-server.rust-analyzer]
command = "/abs/workspace/.helix/.rules_rust_analyzer/rust_analyzer.sh"

[language-server.rust-analyzer.config.rust-analyzer.workspace.discoverConfig]
command = ["/abs/workspace/.helix/.rules_rust_analyzer/discover_bazel_rust_project.sh", "{arg}"]
progressLabel = "rules_rust"
filesToWatch = ["BUILD", "BUILD.bazel", "MODULE.bazel", "WORKSPACE", "WORKSPACE.bazel"]
# ...etc
```

### Vim (classic) and other JSON-config LSP clients

```
bazel run @rules_rust//tools/rust_analyzer:setup -- print
```

Installs launchers under `<workspace>/.rules_rust_analyzer/` and prints
a generic JSON snippet using the `rust-analyzer.*` keys VSCode uses —
[`coc.nvim`](https://github.com/neoclide/coc.nvim) reads the same
namespace via `coc-settings.json` (open with `:CocConfig`); `vim-lsp` /
`ALE` / `LanguageClient-neovim` settings are configured in plugin-
specific ways but accept the same keys. Paste the snippet into the
relevant settings file:

```json
{
  "rust-analyzer.server.path": "/abs/workspace/.rules_rust_analyzer/rust_analyzer.sh",
  "rust-analyzer.workspace.discoverConfig": {
    "command": ["/abs/workspace/.rules_rust_analyzer/discover_bazel_rust_project.sh", "{arg}"],
    "progressLabel": "rules_rust",
    "filesToWatch": ["BUILD", "BUILD.bazel", "MODULE.bazel", "WORKSPACE", "WORKSPACE.bazel"]
  },
  "rust-analyzer.procMacro.server": "/abs/workspace/.rules_rust_analyzer/rust_analyzer_proc_macro_srv.sh",
  "rust-analyzer.rustfmt.overrideCommand": ["/abs/workspace/.rules_rust_analyzer/rustfmt.sh"],
  "rust-analyzer.files.excludeDirs": ["cargo", "crate_universe"],
  "rust-analyzer.lens.enable": true
}
```

## How it works

### Project model

The discover binary reads each Bazel rust target's per-crate spec file
(produced by `rust_analyzer_aspect` as a side effect of `bazel build`),
consolidates duplicates, absolutizes the `__WORKSPACE__` / `__EXEC_ROOT__`
/ `__OUTPUT_BASE__` templates, and streams a JSON document with the shape
rust-analyzer expects to stdout. The document is the in-memory equivalent
of the `rust-project.json` file rust-analyzer would read from disk in the
manual-config flow.

### Crate model (cycles, lib/test pairs)

Each Bazel rust target produces exactly one rust-analyzer crate, keyed by
the target's label. A `rust_library(name = "lib")` and its
`rust_test(name = "lib_test", crate = ":lib")` show up as **two** distinct
crates that share a `root_module` — exactly how cargo models a lib and its
integrated tests. They are not merged into one crate with a union of deps.

This eliminates the only way Bazel-built projects could exhibit "cycles"
in the rust-analyzer graph: the previous heuristic keyed crates by
`root_module` path, so the lib and test specs would merge, and the test's
test-only deps would end up on the merged "lib" crate. When two packages'
test-only deps reached back into each other's libs, the merged graph
contained a cycle that Bazel's own build graph never had. Project loading
would then fail with `"Failed to make progress on building crate
dependency graph"` and rust-analyzer would show nothing.

Under the label-keyed scheme this can't happen — the test crate carries
its own deps directly, no merge is performed, and the assembly step
tolerates forward references, missing deps, and even genuine cycles by
silently dropping unresolvable edges instead of bailing out.

### Performance

Auto-discovery uses Bazel's [Build Event Protocol][bep] to learn the paths of the per-crate spec
files produced by `rust_analyzer_aspect` — a side-effect of the `bazel build` that's already
running, so there's no separate `bazel aquery` round-trip. Discovery only includes spec files
that the **current** build's action graph actually produced; stale `*.rust_analyzer_crate_spec.json`
files left behind in `bazel-out/` by deleted targets or no-longer-reachable configurations are
correctly ignored.

The assembled `rust-project.json` is then memoized in a content-addressed local cache under
`<workspace>/.vscode/.rules_rust_analyzer/cache/`. The key includes the contents of every
input spec, a version constant that's bumped whenever the assembled JSON shape changes, the
toolchain info, and the bazel/workspace/execution-root paths, so the cache is only served
when every input matches byte-for-byte. Living under `.vscode/` (not the Bazel output base)
means it survives `bazel clean` — but clearing it is a single `rm -rf
.vscode/.rules_rust_analyzer/cache/` if a hand-edit ever leaves it inconsistent.

In practice, a warm-cache discovery on a large workspace runs in the time it takes Bazel to
report its action-cache hits — typically a few seconds.

### Workspace splitting

By default, `setup` configures rust-analyzer to treat the whole
project as a single workspace — simpler to reason about, no surprise
context switches when you jump between files. The discover command is
invoked with just the launcher path and no per-file argument.

For monorepos where indexing the whole graph is too slow, pass
`--per-package-workspaces` to setup. That appends `"{arg}"` to the
discover command array; rust-analyzer fills it with the path of the
file you opened, and discover scopes the project to that file's package
+ deps. rust-analyzer reloads (and re-runs discover) whenever you jump
to a file in a different package.

Caveat of per-package mode: _dependents_ of the package you're working
on are not indexed and won't be tracked by `rust-analyzer`. If you go
fix a callee, then re-open a caller in a different package, the caller's
view of the callee is whatever the caller's own discover saw.

You can switch modes any time by re-running `setup vscode` (or your
editor's subcommand) with or without `--per-package-workspaces`.
