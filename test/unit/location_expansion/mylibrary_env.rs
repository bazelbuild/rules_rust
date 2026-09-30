// The byte content of `MY_DATA` is included at compile time. The
// path is plumbed via a `$(execpaths ...)` location expansion in
// `rustc_env`, so it points at a generated file under `bazel-out`.
//
// When Bazel path mapping (`--experimental_output_paths=strip`) is
// active, the rustc action's sandbox sees files at
// `bazel-out/cfg/bin/...` only. The expanded env value, however, is
// a plain string set at analysis time and is NOT rewritten by path
// mapping. So if the action wrongly advertises
// `supports-path-mapping`, the env path stays at
// `bazel-out/<config>/bin/...` while the file only exists at
// `bazel-out/cfg/bin/...` inside the sandbox, and this
// `include_bytes!` fails at compile time. PR #4117 disables path
// mapping for actions whose `rustc_env` contains location
// expansions; this `const` exercises that contract.
pub const MY_DATA: &[u8] = include_bytes!(env!("MY_DATA"));
