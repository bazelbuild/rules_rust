# Rust Analyzer

`rules_rust` ships a one-shot installer that configures
[rust-analyzer](https://rust-analyzer.github.io/) to use the project's Bazel
toolchain. After setup, rust-analyzer, the proc-macro server, and rustfmt
all come from Bazel — no host Rust install required.

## Quick start

Pick your editor below. Each runs the same `setup` tool with a different
subcommand — `setup` is re-runnable any time.

### VSCode

1. Install the
   [rust-analyzer extension](https://marketplace.visualstudio.com/items?itemName=rust-lang.rust-analyzer).
2. ```
   bazel run @rules_rust//tools/rust_analyzer:setup -- vscode
   ```
3. Reload the VSCode window.

Existing user keys in `.vscode/settings.json` are preserved on re-runs.
Pass `--dry-run` to preview the JSON without writing it; `--replace` to
overwrite all managed keys (destroys user keys).

#### Committable settings

Managed `rust-analyzer.*` paths use VSCode's `${workspaceFolder}`
variable and point at small launcher shims under
`<workspace>/.rules_rust_analyzer/`, e.g.:

```jsonc
"rust-analyzer.server.path":
    "${workspaceFolder}/.rules_rust_analyzer/rust_analyzer.exe"
```

The shims are byte-identical copies of a tiny dispatcher binary;
they read a sibling `launcher_paths.json` (also in the launcher dir)
and `exec` the absolute toolchain binary in the Bazel cache. **The
settings file is safe to commit** — it contains no per-developer or
per-platform paths. Each developer just runs `setup` once on their
machine to populate the launcher dir.

Add the launcher dir to `.gitignore`:

```
.rules_rust_analyzer/
```

Re-run `setup` after a toolchain bump (rustup update, `MODULE.bazel`
change, `bazel clean --expunge`) to refresh the launcher dir's
`launcher_paths.json`. The committed settings file is untouched.

The `.exe` extension on every platform is deliberate: it's the only
extension Node's `child_process.spawn` handles on Windows without
`shell: true`, and POSIX kernels ignore file extensions for `execve`
(a Linux ELF or macOS Mach-O binary named `foo.exe` runs fine).
That's what lets the same committed path work across Linux, macOS,
and Windows.

#### `.code-workspace` files

Projects opened via a `.code-workspace` file need the rust-analyzer
keys inside the workspace file's `settings` object — VSCode answers
rust-analyzer's window-scoped config requests from there, **not** from
any folder's `.vscode/settings.json`. `setup vscode` handles this
automatically: if exactly one `*.code-workspace` exists at the
workspace root, it targets that file and nests under `settings`. Pass
`--output <file>.code-workspace` to disambiguate when multiple exist,
or `--settings-key <key>` to nest under a custom key. With
`--settings-key`, `--replace` overwrites only that nested object —
sibling top-level keys (`folders`, `tasks`, `extensions`) survive
intact.

### Neovim

```
bazel run @rules_rust//tools/rust_analyzer:setup -- neovim
```

Prints an `nvim-lspconfig` Lua snippet to stdout. Paste it into your
`init.lua` (or pipe to a file you `require`). Restart Neovim.

For [`rustaceanvim`](https://github.com/mrcjkb/rustaceanvim) users:
pass the printed `cmd` and `settings` table through its `server`
option (`vim.g.rustaceanvim = { server = { cmd = ..., settings = ... } }`).

### Helix

```
bazel run @rules_rust//tools/rust_analyzer:setup -- helix
```

Prints a `languages.toml` snippet. Paste it into
`<workspace>/.helix/languages.toml`. Restart Helix.

### Other editors (`coc.nvim`, `vim-lsp`, ALE, etc.)

```
bazel run @rules_rust//tools/rust_analyzer:setup -- print
```

Prints a generic JSON snippet using the `rust-analyzer.*` keys VSCode
uses. `coc.nvim` reads them via `coc-settings.json` (open with
`:CocConfig`); `vim-lsp` / ALE / `LanguageClient-neovim` accept the
same keys via plugin-specific config files.

## Flags

Re-runnable at any time. Global flags work on any subcommand.

| Flag | Effect |
|---|---|
| `--workspace <path>` | Workspace root. Defaults to `$BUILD_WORKSPACE_DIRECTORY` (set by `bazel run`). |
| `--skip-proc-macro-server` | Don't manage the proc-macro key. |
| `--skip-rustfmt` | Don't manage the formatter key (use host rustfmt). |
| `--per-package-workspaces` | Opt in to per-package workspace splitting (see below). |

The `vscode` subcommand adds:

| Flag | Effect |
|---|---|
| `--output <path>` | Settings file to write. Defaults to the unique `*.code-workspace` at the workspace root, falling back to `.vscode/settings.json`. |
| `--settings-key <key>` | Nest the managed `rust-analyzer.*` keys under this top-level key. Auto-defaults to `settings` for `.code-workspace` outputs. |
| `--dry-run` | Preview the JSON without writing. |
| `--replace` | Replace the managed keys instead of merging. With `--settings-key`, only that nested object is replaced — sibling keys (`folders`, `tasks`, `extensions`) survive. |

## What you get

- **`▶ Run Tests` / `▶ Run Test`** codelens on every `#[cfg(test)] mod` and
  individual `#[test]`.
- **On-save squiggles** from rustc diagnostics. Matches `cargo check` —
  errors anywhere in the dep graph surface at their actual file paths.
- **Format-on-save** via the Bazel-toolchain rustfmt.
- **Workspace reload** on watched `BUILD` / `MODULE.bazel` changes.

## Troubleshooting

### Stale or wrong project model

Discovery memoizes the assembled `rust-project.json` in a local cache
keyed on every input. If the IDE shows symbols / deps that don't match
what `bazel build` actually produces — and re-running discovery
(restart rust-analyzer, or save a `BUILD` file) doesn't fix it — nuke
the cache and try again:

```
rm -rf <workspace>/<editor-dir>/.rules_rust_analyzer/cache
```

Where `<editor-dir>` is `.vscode` for VSCode, `.helix` for Helix, or
empty for Neovim / `print` (cache sits at `<workspace>/.rules_rust_analyzer/cache`).

The cache survives `bazel clean` by design (it lives in the workspace,
not the Bazel output base) so a full Bazel rebuild won't invalidate
stale entries — that's what the manual `rm -rf` is for.

### Diagnostics stopped appearing

Check `<workspace>/.rules_rust_analyzer/flycheck.log` — the on-save
wrapper appends one line per internal failure.

### After `bazel clean --expunge` or toolchain changes

Re-run `setup`. The launcher shims dispatch through
`<launcher_dir>/launcher_paths.json`, which records absolute paths to
the rust-analyzer / rustfmt / proc-macro-srv binaries at install
time. Those binaries live in Bazel's output_base; `--expunge` clears
that, and toolchain changes move them to new paths. Re-running setup
re-resolves and rewrites the JSON.

## Workspace splitting

By default the whole project is treated as a single workspace.

For monorepos where indexing the whole graph is too slow, pass
`--per-package-workspaces`. Discover then scopes to the saved file's
package + deps; rust-analyzer reloads when you jump to a different
package. Caveat: _dependents_ of the package you're working on aren't
indexed, so "find usages" can miss callers in other packages.

Switch any time by re-running `setup` with or without the flag.

## Debugging

The `▶ Debug` codelens VSCode renders next to `#[test]` functions
**does not work** — the VSCode rust-analyzer extension's debug handler
only supports cargo-shaped runnables, and Bazel projects emit shell
runnables. Lifting this needs an upstream PR.

The supported debug path is `.vscode/launch.json` + F5:

```
bazel run @rules_rust//tools/vscode:gen_launch_json
```

Writes a per-target launch config that uses CodeLLDB's
`targetCreateCommands` to build with `--compilation_mode=dbg
--strip=never` and attach LLDB. Install
[CodeLLDB](https://marketplace.visualstudio.com/items?itemName=vadimcn.vscode-lldb)
first. Set a breakpoint inside the test you care about and re-run the
target — libtest selects tests inside the binary, so one launch config
covers every test in the target.
