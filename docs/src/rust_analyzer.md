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

Re-runnable at any time. All flags work on any subcommand.

| Flag | Effect |
|---|---|
| `--skip-proc-macro-server` | Don't manage the proc-macro key. |
| `--skip-rustfmt` | Don't manage the formatter key (use host rustfmt). |
| `--output-user-root <abs-path>` | `--output_user_root` for flycheck's dedicated Bazel server. Required on Windows for non-trivial workspaces (MAX_PATH). |
| `--cache-dir <abs-path>` | Where discover writes its merged-JSON cache. |
| `--per-package-workspaces` | Opt in to per-package workspace splitting (see below). |

VSCode subcommand also accepts `--dry-run` (preview JSON without writing) and
`--replace` (overwrite all managed keys, destroying user keys).

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

If you passed `--cache-dir` at setup time, the cache is wherever you
pointed it instead.

The cache survives `bazel clean` by design (it lives in the workspace,
not the Bazel output base) so a full Bazel rebuild won't invalidate
stale entries — that's what the manual `rm -rf` is for.

### Diagnostics stopped appearing

Check `<workspace>/.rules_rust_analyzer/flycheck.log` — the on-save
wrapper appends one line per internal failure.

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
