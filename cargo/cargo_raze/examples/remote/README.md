# Adding new remote examples

The smoke test script generates a WORKSPACE file that looks up the `crates.bzl` functions
and assumes that the function name is `<folder>_fetch_remote_crates`.

In order to make sure that this assertion holds, please make sure set up **Cargo.toml** as such:

**Cargo.toml**
```toml

[package.metadata.raze]
gen_workspace_prefix = "<folder>"
```