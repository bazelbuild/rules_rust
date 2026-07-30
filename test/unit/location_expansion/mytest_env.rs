// Same contract as `mylibrary_env.rs`, but exercised through
// `rust_test` rather than `rust_library`. This surfaces a code path
// PR #4117 missed: for `rust_test`, location expansion in `rustc_env`
// is performed inside the rule implementation (see `rust.bzl`)
// BEFORE the values reach `CrateInfo.rustc_env`. By the time
// `construct_arguments` in `rustc.bzl` inspects
// `crate_info.rustc_env.values()` looking for `$(location ...)`
// markers, they've already been replaced with concrete paths — so
// the check finds nothing and `supports-path-mapping` stays enabled.
// Under `--experimental_output_paths=strip`, that leaves the env
// value pointing at the un-mapped `bazel-out/<config>/bin/...` path
// while the sandbox only has the file at `bazel-out/cfg/bin/...`.
//
// The bug is caught at compile time by `include_bytes!(env!(...))`:
// rustc has to read the file at the env path inside the sandbox, so
// a path-mapping mismatch fails the build outright. No runtime
// assertion is needed — declaring the const is the whole test.
const _MY_DATA: &[u8] = include_bytes!(env!("MY_DATA"));
