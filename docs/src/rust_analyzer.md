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

`.vscode/settings.json` is always written; a `*.code-workspace` at
the workspace root is picked up too. Existing user keys and comments
survive re-runs, so `.vscode/settings.json` and `.code-workspace` are
safe to commit.

Add the launcher dir to `.gitignore`:

```
.vscode/.rules_rust_analyzer/
```

Re-run `setup` after a toolchain change (rustup update, `MODULE.bazel`
edit, `bazel clean --expunge`).

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
| `--skip-proc-macro-server` | Don't manage the proc-macro key. |
| `--skip-rustfmt` | Don't manage the formatter key (use host rustfmt). |
| `--per-package-workspaces` / `--no-per-package-workspaces` | Opt this developer in/out of per-package workspace splitting (see below). |
| `--clippy` / `--no-clippy` | Opt this developer in/out of running clippy on save and streaming its diagnostics alongside rustc's. |
| `--clean` | Delete `<launcher-dir>/cache/` before running the rest of setup. See Troubleshooting. |

The `--clippy` and `--per-package-workspaces` toggles are **per-user**: they mutate `<launcher-dir>/user_config.json` (gitignored) instead of the shared committed settings file. Two developers on the same workspace can hold different preferences without touching the checked-in configuration. Editing `user_config.json` by hand works too.

The `vscode` subcommand adds:

| Flag | Effect |
|---|---|
| `--settings-json <path>` | Override the settings.json output. Defaults to `<workspace>/.vscode/settings.json`. |
| `--code-workspace <path>` | `.code-workspace` file to also update. Required when the workspace root has more than one. |
| `--no-code-workspace` | Skip the `.code-workspace` write. |
| `--settings-key <key>` | Nest managed keys under this key inside the `.code-workspace` (default: `settings`). |
| `--dry-run` | Print each would-be-written file to stdout. |
| `--replace` | Overwrite managed keys instead of merging. Sibling `folders` / `tasks` / `extensions` in a `.code-workspace` survive. |

## What you get

- **`▶ Run Tests` / `▶ Run Test`** codelens on every `#[cfg(test)] mod` and
  individual `#[test]`.
- **On-save squiggles** from rustc diagnostics. Matches `cargo check` —
  errors anywhere in the dep graph surface at their actual file paths.
- **Format-on-save** via the Bazel-toolchain rustfmt.
- **Workspace reload** on watched `BUILD` / `MODULE.bazel` changes.

## Troubleshooting

### Symbols / deps look wrong

Restart rust-analyzer (or save a `BUILD` file). If that doesn't fix
it, re-run setup with `--clean` to nuke the discovery cache:

```
bazel run @rules_rust//tools/rust_analyzer:setup -- --clean vscode
```

Works with any subcommand (`vscode` / `neovim` / `helix` / `print`).

### Diagnostics stopped appearing

Check `<workspace>/.rules_rust_analyzer/flycheck.log`.

### After `bazel clean --expunge` or toolchain changes

Re-run `setup`.

### Noisy `cargo metadata` errors on startup

`setup` does not manage `rust-analyzer.files.excludeDirs`. If your
workspace has stub `Cargo.toml` files that aren't meant to be
auto-loaded (common in `rules_rust` itself under `examples/`,
`crate_universe/`, etc.), rust-analyzer still finds them and logs
errors. Silence them by adding the directory names to `settings.json`
yourself — your entries survive future `setup` runs:

```
"rust-analyzer.files.excludeDirs": ["examples", "some_other_dir"]
```

Trade-off: `files.excludeDirs` also hides those sources from
rust-analyzer's virtual filesystem, so files under those directories
won't get IDE features even if they're part of a Bazel-discovered
crate. Only exclude directories whose sources you're willing to lose
IDE support on.

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
**does not work** for Bazel projects. Use `.vscode/launch.json` + F5
instead:

```
bazel run @rules_rust//tools/vscode:gen_launch_json
```

Install
[CodeLLDB](https://marketplace.visualstudio.com/items?itemName=vadimcn.vscode-lldb)
first. Set a breakpoint inside the test and run the target — one
launch config covers every test in that binary.
