// Copyright 2024 The Bazel Authors. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

//! Sandbox helpers for the persistent worker.

use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};

use super::pipeline::OutputMaterializationStats;
use super::protocol::WorkRequestContext;
use crate::ProcessWrapperError;

/// A stable alias root created inside a request sandbox.
///
/// Instead of staging inputs into a worker-owned execroot, this creates a
/// small directory (`__rr/`) inside `sandbox_dir` with symlinks that give
/// rustc stable, sandbox-rooted relative paths:
///
/// ```text
/// <sandbox_dir>/__rr/
///   src -> ..              # resolves to sandbox_dir (all inputs)
///   out -> ../<out_dir>    # resolves to output directory in sandbox
///   cache -> ../cache      # optional, if cache was seeded
///   tmp/                   # for rewritten argfiles
/// ```
///
/// rustc runs with `cwd = sandbox_dir/__rr`, so `src/external/foo/lib.rs`
/// resolves to `sandbox_dir/external/foo/lib.rs` — keeping all reads rooted
/// in the sandbox while removing the unstable absolute sandbox prefix from
/// paths that rustc sees.
#[derive(Debug)]
pub(super) struct AliasRoot {
    /// The `__rr/` directory itself: `<sandbox_dir>/__rr`.
    pub(super) root: PathBuf,
    /// Prefix for rewriting input paths: `src/`.
    pub(super) src_prefix: &'static str,
    /// Prefix for rewriting output paths: `out`.
    pub(super) out_alias: &'static str,
}

/// Creates the alias root directory structure inside a sandbox.
///
/// `sandbox_dir`: The Bazel-provided per-request sandbox directory.
/// `out_dir`: The relative output directory (e.g., `bazel-out/k8-fastbuild/bin/lib/math`).
///
/// Returns the `AliasRoot` on success, with timing information logged.
pub(super) fn create_alias_root(
    sandbox_dir: &str,
    out_dir: &str,
) -> Result<AliasRoot, ProcessWrapperError> {
    let start = std::time::Instant::now();
    let sandbox = Path::new(sandbox_dir);
    let rr_dir = sandbox.join("__rr");

    // Clean up any leftover __rr from a previous request to this sandbox slot.
    if rr_dir.exists() {
        let _ = std::fs::remove_dir_all(&rr_dir);
    }

    std::fs::create_dir_all(&rr_dir).map_err(|e| {
        ProcessWrapperError(format!("alias-root: failed to create __rr/: {e}"))
    })?;

    // src -> .. (sandbox root)
    let src_link = rr_dir.join("src");
    symlink_path(Path::new(".."), &src_link, true).map_err(|e| {
        ProcessWrapperError(format!("alias-root: failed to create src symlink: {e}"))
    })?;

    // out -> ../<out_dir>
    let out_target = Path::new("..").join(out_dir);
    let out_link = rr_dir.join("out");
    symlink_path(&out_target, &out_link, true).map_err(|e| {
        ProcessWrapperError(format!("alias-root: failed to create out symlink: {e}"))
    })?;

    // tmp/ for rewritten argfiles
    std::fs::create_dir_all(rr_dir.join("tmp")).map_err(|e| {
        ProcessWrapperError(format!("alias-root: failed to create tmp/: {e}"))
    })?;

    // Optional: cache -> ../cache (if cache was seeded in the sandbox)
    let sandbox_cache = sandbox.join("cache");
    if sandbox_cache.exists() || sandbox_cache.is_symlink() {
        let cache_link = rr_dir.join("cache");
        let _ = symlink_path(Path::new("../cache"), &cache_link, true);
    }

    let elapsed = start.elapsed();
    eprintln!(
        "alias-root: created in {sandbox_dir}/__rr ({:.1}ms, out_dir={out_dir})",
        elapsed.as_secs_f64() * 1000.0,
    );

    Ok(AliasRoot {
        root: rr_dir,
        src_prefix: "src/",
        out_alias: "out",
    })
}

impl AliasRoot {
    /// Rewrites expanded rustc args so relative input paths go through `src/`.
    ///
    /// After `expand_rustc_args` + `prepare_rustc_args`, the arg list is flat.
    /// This prefixes relative paths in input-bearing args with `src/` so they
    /// resolve through the `__rr/src -> ..` symlink back to `sandbox_dir`.
    ///
    /// Leaves `--out-dir` and `--emit=metadata=` untouched — those are rewritten
    /// separately by `rewrite_out_dir_in_expanded` and `rewrite_emit_metadata_path`.
    pub(super) fn rewrite_rustc_args(&self, args: Vec<String>) -> Vec<String> {
        let src = self.src_prefix;
        // Track whether we've seen the source file (first non-flag positional arg
        // that looks like a .rs file path). Everything else non-flag is left alone
        // to avoid prefixing --cfg values, crate names, etc.
        let mut source_seen = false;
        args.into_iter()
            .enumerate()
            .map(|(i, arg)| {
                // args[0] is the rustc binary — prefix if relative.
                if i == 0 {
                    if is_relative_path(&arg) {
                        return format!("{src}{arg}");
                    }
                    return arg;
                }
                // --extern=name=<path>
                if let Some(rest) = arg.strip_prefix("--extern=") {
                    if let Some((name, path)) = rest.split_once('=') {
                        if is_relative_path(path) {
                            return format!("--extern={name}={src}{path}");
                        }
                    }
                    return arg;
                }
                // -Ldependency=<path>
                if let Some(path) = arg.strip_prefix("-Ldependency=") {
                    if is_relative_path(path) {
                        return format!("-Ldependency={src}{path}");
                    }
                    return arg;
                }
                // -Lnative=<path>
                if let Some(path) = arg.strip_prefix("-Lnative=") {
                    if is_relative_path(path) {
                        return format!("-Lnative={src}{path}");
                    }
                    return arg;
                }
                // -L<path> (bare, no qualifier — but NOT -Lframework, etc.)
                if arg.starts_with("-L") && !arg.starts_with("-Lframework") {
                    if let Some(path) = arg.strip_prefix("-L") {
                        if !path.is_empty()
                            && !path.starts_with('-')
                            && is_relative_path(path)
                        {
                            return format!("-L{src}{path}");
                        }
                    }
                    return arg;
                }
                // --out-dir and --emit are handled by separate rewrites — skip.
                if arg.starts_with("--out-dir=") || arg.starts_with("--emit=") {
                    return arg;
                }
                // --remap-path-prefix=<from>=<to> — prefix <from> if relative.
                if let Some(rest) = arg.strip_prefix("--remap-path-prefix=") {
                    if let Some((from, to)) = rest.split_once('=') {
                        if is_relative_path(from) {
                            return format!("--remap-path-prefix={src}{from}={to}");
                        }
                    }
                    return arg;
                }
                // Any flag — pass through unchanged.
                if arg.starts_with('-') {
                    return arg;
                }
                // Source file: the first positional arg ending in .rs.
                // Only prefix this one — other non-flag args (like --cfg values
                // from arg-files) must not be prefixed.
                if !source_seen && arg.ends_with(".rs") && is_relative_path(&arg) {
                    source_seen = true;
                    return format!("{src}{arg}");
                }
                arg
            })
            .collect()
    }

    /// Rewrites path-bearing environment variable values so they resolve from `__rr/`.
    ///
    /// Build scripts produce env vars like `OUT_DIR=bazel-out/.../out_dir` which are
    /// relative to the execroot. When CWD is `__rr/`, these need `src/` prefix.
    pub(super) fn rewrite_env(
        &self,
        env: &mut std::collections::HashMap<String, String>,
    ) {
        let src = self.src_prefix;
        for (key, val) in env.iter_mut() {
            // Only rewrite known path-bearing env vars.
            let is_path_env = matches!(
                key.as_str(),
                "OUT_DIR"
                    | "CARGO_MANIFEST_DIR"
                    | "DEP_Z_INCLUDE"
                    | "DEP_Z_LIB"
            ) || key.starts_with("DEP_");

            if is_path_env && is_relative_path(val) {
                *val = format!("{src}{val}");
            }
        }
    }
}

/// Returns true if the path is relative (not absolute, not empty).
fn is_relative_path(path: &str) -> bool {
    if path.is_empty() {
        return false;
    }
    let p = Path::new(path);
    !p.is_absolute()
}

/// Resolves the real Bazel execroot from sandbox symlinks.
///
/// In multiplex sandboxing, the sandbox dir (`__sandbox/N/_main/`) contains
/// symlinks to the real execroot (`<output_base>/execroot/_main/`).
/// For example: `__sandbox/3/_main/external/foo/src/lib.rs` →
///              `/home/.../<hash>/execroot/_main/external/foo/src/lib.rs`
///
/// We resolve any input's symlink target and strip the relative path suffix
/// to recover the real execroot root.
pub(super) fn resolve_real_execroot(
    sandbox_dir: &str,
    request: &WorkRequestContext,
) -> Option<PathBuf> {
    let sandbox_path = std::path::Path::new(sandbox_dir);
    for input in &request.inputs {
        let full_path = sandbox_path.join(&input.path);
        if let Ok(target) = std::fs::read_link(&full_path) {
            // target = <real_execroot>/<relative_path>
            // input.path = <relative_path>
            // Strip the relative path suffix to get the real execroot.
            let target_str = target.to_string_lossy();
            if target_str.ends_with(&input.path) {
                let prefix = &target_str[..target_str.len() - input.path.len()];
                let execroot = PathBuf::from(prefix);
                if execroot.is_dir() {
                    return Some(execroot);
                }
            }
        }
        // Also try following through to the canonical path
        if let Ok(canonical) = full_path.canonicalize() {
            let canonical_str = canonical.to_string_lossy().to_string();
            if canonical_str.ends_with(&input.path) {
                let prefix = &canonical_str[..canonical_str.len() - input.path.len()];
                let execroot = PathBuf::from(prefix);
                if execroot.is_dir() {
                    return Some(execroot);
                }
            }
        }
    }
    None
}

pub(super) fn resolve_relative_to(path: &str, base_dir: &std::path::Path) -> PathBuf {
    let path = std::path::Path::new(path);
    if path.is_absolute() {
        path.to_path_buf()
    } else {
        base_dir.join(path)
    }
}

pub(super) fn materialize_output_file(
    src: &std::path::Path,
    dest: &std::path::Path,
) -> Result<bool, std::io::Error> {
    if let Some(parent) = dest.parent() {
        std::fs::create_dir_all(parent)?;
    }

    // Skip if src and dest resolve to the same file (e.g., when rustc writes
    // directly into the sandbox via --emit=metadata=<relative-path> and the
    // copy destination is the same location). Removing dest would delete src.
    if let (Ok(a), Ok(b)) = (src.canonicalize(), dest.canonicalize()) {
        if a == b {
            return Ok(false);
        }
    }

    if dest.exists() {
        std::fs::remove_file(dest)?;
    }

    match std::fs::hard_link(src, dest) {
        Ok(()) => Ok(true),
        Err(link_err) => match std::fs::copy(src, dest) {
            Ok(_) => Ok(false),
            Err(copy_err) => Err(std::io::Error::new(
                copy_err.kind(),
                format!(
                    "failed to materialize {} at {} via hardlink ({link_err}) or copy ({copy_err})",
                    src.display(),
                    dest.display(),
                ),
            )),
        },
    }
}

#[cfg(unix)]
pub(super) fn symlink_path(
    src: &std::path::Path,
    dest: &std::path::Path,
    _is_dir: bool,
) -> Result<(), std::io::Error> {
    std::os::unix::fs::symlink(src, dest)
}

#[cfg(windows)]
pub(super) fn symlink_path(
    src: &std::path::Path,
    dest: &std::path::Path,
    is_dir: bool,
) -> Result<(), std::io::Error> {
    if is_dir {
        std::os::windows::fs::symlink_dir(src, dest)
    } else {
        std::os::windows::fs::symlink_file(src, dest)
    }
}

pub(super) fn seed_sandbox_cache_root(
    sandbox_dir: &std::path::Path,
) -> Result<(), ProcessWrapperError> {
    let dest = sandbox_dir.join("cache");
    if dest.exists() {
        return Ok(());
    }

    let entries = std::fs::read_dir(sandbox_dir).map_err(|e| {
        ProcessWrapperError(format!(
            "failed to read request sandbox for cache seeding: {e}"
        ))
    })?;

    for entry in entries {
        let entry = entry.map_err(|e| {
            ProcessWrapperError(format!("failed to enumerate request sandbox entry: {e}"))
        })?;
        let source = entry.path();
        let Ok(resolved) = source.canonicalize() else {
            continue;
        };

        let mut cache_root = None;
        for ancestor in resolved.ancestors() {
            if ancestor.file_name().is_some_and(|name| name == "cache") {
                cache_root = Some(ancestor.to_path_buf());
                break;
            }
        }

        let Some(cache_root) = cache_root else {
            continue;
        };
        return symlink_path(&cache_root, &dest, true).map_err(|e| {
            ProcessWrapperError(format!(
                "failed to seed request sandbox cache root {} -> {}: {e}",
                cache_root.display(),
                dest.display(),
            ))
        });
    }

    Ok(())
}

/// Copies the file at `src` into `<sandbox_dir>/<original_out_dir>/<dest_subdir>/`.
///
/// Used after the metadata action to make the `.rmeta` file visible to Bazel
/// inside the sandbox before the sandbox is cleaned up.
pub(super) fn copy_output_to_sandbox(
    src: &str,
    sandbox_dir: &str,
    original_out_dir: &str,
    dest_subdir: &str,
) -> OutputMaterializationStats {
    let mut stats = OutputMaterializationStats::default();
    let src_path = std::path::Path::new(src);
    let filename = match src_path.file_name() {
        Some(n) => n,
        None => return stats,
    };
    let dest_dir = std::path::Path::new(sandbox_dir)
        .join(original_out_dir)
        .join(dest_subdir);
    if let Ok(hardlinked) = materialize_output_file(src_path, &dest_dir.join(filename)) {
        stats.files = 1;
        if hardlinked {
            stats.hardlinked_files = 1;
        } else {
            stats.copied_files = 1;
        }
    }
    stats
}

/// Copies all regular files from `pipeline_dir` into `<sandbox_dir>/<original_out_dir>/`.
///
/// Used by the full action to move the `.rlib` (and `.d`, etc.) from the
/// persistent directory into the sandbox before responding to Bazel.
pub(super) fn copy_all_outputs_to_sandbox(
    pipeline_dir: &PathBuf,
    sandbox_dir: &str,
    original_out_dir: &str,
) -> OutputMaterializationStats {
    let dest_dir = std::path::Path::new(sandbox_dir).join(original_out_dir);
    let mut stats = OutputMaterializationStats::default();
    if let Ok(entries) = std::fs::read_dir(pipeline_dir) {
        for entry in entries.flatten() {
            if let Ok(meta) = entry.metadata() {
                if meta.is_file() {
                    if let Ok(hardlinked) =
                        materialize_output_file(&entry.path(), &dest_dir.join(entry.file_name()))
                    {
                        stats.files += 1;
                        if hardlinked {
                            stats.hardlinked_files += 1;
                        } else {
                            stats.copied_files += 1;
                        }
                    }
                }
            }
        }
    }
    stats
}

/// Like `run_request` but sets `current_dir(sandbox_dir)` on the subprocess.
///
/// When Bazel provides a `sandboxDir`, setting the subprocess CWD to it makes
/// all relative paths in arguments resolve correctly within the sandbox.
pub(super) fn run_sandboxed_request(
    self_path: &std::path::Path,
    arguments: Vec<String>,
    sandbox_dir: &str,
) -> Result<(i32, String), ProcessWrapperError> {
    let _ = seed_sandbox_cache_root(std::path::Path::new(sandbox_dir));
    let output = Command::new(self_path)
        .args(&arguments)
        .current_dir(sandbox_dir)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .output()
        .map_err(|e| ProcessWrapperError(format!("failed to spawn sandboxed subprocess: {e}")))?;

    let exit_code = output.status.code().unwrap_or(1);
    let mut combined = String::from_utf8_lossy(&output.stdout).into_owned();
    combined.push_str(&String::from_utf8_lossy(&output.stderr));
    Ok((exit_code, combined))
}

/// Resolves `path` relative to `sandbox_dir` if it is not absolute.
pub(super) fn resolve_sandbox_path(path: &str, sandbox_dir: &str) -> String {
    let p = std::path::Path::new(path);
    if p.is_absolute() {
        path.to_string()
    } else {
        std::path::Path::new(sandbox_dir)
            .join(p)
            .to_string_lossy()
            .into_owned()
    }
}

/// Ensures output files in rustc's `--out-dir` are writable before each request.
///
/// Workers run in execroot without sandboxing. Bazel marks action outputs
/// read-only after each successful action, and the disk cache hardlinks them
/// as read-only. With pipelined compilation, two separate actions (RustcMetadata
/// and Rustc) both write to the same `.rmeta` path. After the first succeeds,
/// Bazel makes its output read-only; the second worker request then fails with
/// "output file ... is not writeable".
///
/// This function scans `args` for `--out-dir=<dir>` — both inline and inside any
/// `--arg-file <path>` (process_wrapper's own arg-file mechanism) or `@flagfile`
/// (Bazel's param file convention) — and makes all regular files in those
/// directories writable.
pub(super) fn prepare_outputs(args: &[String]) {
    let mut out_dirs: Vec<String> = Vec::new();

    let mut i = 0;
    while i < args.len() {
        let arg = &args[i];
        if let Some(dir) = arg.strip_prefix("--out-dir=") {
            out_dirs.push(dir.to_string());
        } else if let Some(flagfile_path) = arg.strip_prefix('@') {
            // Bazel @flagfile: one arg per line.
            scan_file_for_out_dir(flagfile_path, None, &mut out_dirs);
        } else if arg == "--arg-file" {
            // process_wrapper's --arg-file <path>: reads child (rustc) args from file.
            if let Some(path) = args.get(i + 1) {
                scan_file_for_out_dir(path, None, &mut out_dirs);
                i += 1; // skip the path argument
            }
        }
        i += 1;
    }

    for out_dir in out_dirs {
        make_dir_files_writable(&out_dir);
        // Also make writable any _pipeline/ subdir (worker-pipelining .rmeta files
        // from previous runs may be read-only after Bazel marks outputs immutable).
        let pipeline_dir = format!("{out_dir}/_pipeline");
        make_dir_files_writable(&pipeline_dir);
    }
}

/// Like `prepare_outputs` but resolves relative `--out-dir` paths against
/// `sandbox_dir` before making files writable.
pub(super) fn prepare_outputs_sandboxed(args: &[String], sandbox_dir: &str) {
    let mut out_dirs: Vec<String> = Vec::new();

    let mut i = 0;
    while i < args.len() {
        let arg = &args[i];
        if let Some(dir) = arg.strip_prefix("--out-dir=") {
            out_dirs.push(resolve_sandbox_path(dir, sandbox_dir));
        } else if let Some(flagfile_path) = arg.strip_prefix('@') {
            scan_file_for_out_dir(flagfile_path, Some(sandbox_dir), &mut out_dirs);
        } else if arg == "--arg-file" {
            if let Some(path) = args.get(i + 1) {
                scan_file_for_out_dir(path, Some(sandbox_dir), &mut out_dirs);
                i += 1;
            }
        }
        i += 1;
    }

    for out_dir in out_dirs {
        make_dir_files_writable(&out_dir);
        let pipeline_dir = format!("{out_dir}/_pipeline");
        make_dir_files_writable(&pipeline_dir);
    }
}

/// Reads `path` line-by-line, collecting any `--out-dir=<dir>` values.
/// When `sandbox_dir` is `Some`, resolves found paths against it.
pub(super) fn scan_file_for_out_dir(
    path: &str,
    sandbox_dir: Option<&str>,
    out_dirs: &mut Vec<String>,
) {
    let Ok(content) = std::fs::read_to_string(path) else {
        return;
    };
    for line in content.lines() {
        if let Some(dir) = line.strip_prefix("--out-dir=") {
            match sandbox_dir {
                Some(sd) => out_dirs.push(resolve_sandbox_path(dir, sd)),
                None => out_dirs.push(dir.to_string()),
            }
        }
    }
}

/// Makes all regular files in `dir` writable (removes read-only bit).
pub(super) fn make_dir_files_writable(dir: &str) {
    let Ok(entries) = std::fs::read_dir(dir) else {
        return;
    };
    for entry in entries.flatten() {
        if let Ok(meta) = entry.metadata() {
            if meta.is_file() {
                let mut perms = meta.permissions();
                if perms.readonly() {
                    perms.set_readonly(false);
                    let _ = std::fs::set_permissions(entry.path(), perms);
                }
            }
        }
    }
}

pub(super) fn make_path_writable(path: &std::path::Path) {
    let Ok(meta) = std::fs::metadata(path) else {
        return;
    };
    if !meta.is_file() {
        return;
    }

    let mut perms = meta.permissions();
    if perms.readonly() {
        perms.set_readonly(false);
        let _ = std::fs::set_permissions(path, perms);
    }
}

/// Executes a single WorkRequest by spawning process_wrapper with the given
/// arguments. Returns (exit_code, combined_output).
///
/// The spawned process runs with the worker's environment and working directory
/// (Bazel's execroot), so incremental compilation caches see stable paths.
pub(super) fn run_request(
    self_path: &std::path::Path,
    arguments: Vec<String>,
) -> Result<(i32, String), ProcessWrapperError> {
    let output = Command::new(self_path)
        .args(&arguments)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .output()
        .map_err(|e| {
            ProcessWrapperError(format!("failed to spawn process_wrapper subprocess: {e}"))
        })?;

    let exit_code = output.status.code().unwrap_or(1);

    // Combine stdout and stderr for the WorkResponse output field.
    // process_wrapper normally writes rustc diagnostics to its stderr,
    // so this captures compilation errors/warnings for display in Bazel.
    let mut combined = String::from_utf8_lossy(&output.stdout).into_owned();
    combined.push_str(&String::from_utf8_lossy(&output.stderr));

    Ok((exit_code, combined))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn make_test_dir(name: &str) -> PathBuf {
        let dir = std::env::temp_dir()
            .join("rules_rust_test")
            .join(name)
            .join(format!("{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).unwrap();
        dir
    }

    #[test]
    fn test_create_alias_root_creates_structure() {
        let tmp = make_test_dir("alias_root_structure");
        let sandbox = tmp.join("sandbox");
        std::fs::create_dir_all(&sandbox).unwrap();
        let out_rel = "bazel-out/k8/bin/lib/math";
        std::fs::create_dir_all(sandbox.join(out_rel)).unwrap();

        let alias = create_alias_root(&sandbox.display().to_string(), out_rel).unwrap();

        assert!(alias.root.is_dir());
        let src_link = alias.root.join("src");
        assert!(src_link.is_symlink());
        assert_eq!(std::fs::read_link(&src_link).unwrap(), Path::new(".."));
        let out_link = alias.root.join("out");
        assert!(out_link.is_symlink());
        assert_eq!(
            std::fs::read_link(&out_link).unwrap(),
            Path::new("..").join(out_rel)
        );
        assert!(alias.root.join("tmp").is_dir());
        assert!(alias.root.join("src").join(out_rel).is_dir());
        assert!(alias.root.join("out").is_dir());
        let _ = std::fs::remove_dir_all(&tmp);
    }

    #[test]
    fn test_create_alias_root_with_cache() {
        let tmp = make_test_dir("alias_root_cache");
        let sandbox = tmp.join("sandbox");
        std::fs::create_dir_all(&sandbox).unwrap();
        std::fs::create_dir_all(sandbox.join("bazel-out/bin")).unwrap();
        let cache_target = tmp.join("real_cache");
        std::fs::create_dir_all(&cache_target).unwrap();
        symlink_path(&cache_target, &sandbox.join("cache"), true).unwrap();

        let alias = create_alias_root(&sandbox.display().to_string(), "bazel-out/bin").unwrap();

        assert!(alias.root.join("cache").is_symlink());
        let _ = std::fs::remove_dir_all(&tmp);
    }

    #[test]
    fn test_rewrite_rustc_args_prefixes_inputs() {
        let alias = AliasRoot {
            root: PathBuf::from("/sandbox/__rr"),
            src_prefix: "src/",
            out_alias: "out",
        };
        let args = vec![
            "/abs/path/to/rustc".to_string(),
            "lib/math/src/lib.rs".to_string(),
            "--crate-name=math".to_string(),
            "--crate-type=rlib".to_string(),
            "--extern=serde=bazel-out/k8/bin/external/serde/libserde.rmeta".to_string(),
            "--extern=log=bazel-out/k8/bin/external/log/liblog.rmeta".to_string(),
            "-Ldependency=bazel-out/k8/bin/external/serde".to_string(),
            "-Ldependency=bazel-out/k8/bin/external/log".to_string(),
            "--out-dir=bazel-out/k8/bin/lib/math".to_string(),
            "--emit=dep-info,metadata,link".to_string(),
            "--edition=2021".to_string(),
            "-Copt-level=2".to_string(),
        ];
        let rewritten = alias.rewrite_rustc_args(args);
        assert_eq!(rewritten[0], "/abs/path/to/rustc"); // absolute binary unchanged
        assert_eq!(rewritten[1], "src/lib/math/src/lib.rs"); // source prefixed
        assert_eq!(rewritten[2], "--crate-name=math"); // flag unchanged
        assert_eq!(
            rewritten[4],
            "--extern=serde=src/bazel-out/k8/bin/external/serde/libserde.rmeta"
        );
        assert_eq!(
            rewritten[6],
            "-Ldependency=src/bazel-out/k8/bin/external/serde"
        );
        assert_eq!(rewritten[8], "--out-dir=bazel-out/k8/bin/lib/math"); // out-dir untouched
        assert_eq!(rewritten[9], "--emit=dep-info,metadata,link"); // emit untouched
    }

    #[test]
    fn test_rewrite_rustc_args_relative_binary() {
        let alias = AliasRoot {
            root: PathBuf::from("/sandbox/__rr"),
            src_prefix: "src/",
            out_alias: "out",
        };
        let args = vec![
            "bazel-out/k8-opt-exec/bin/external/rustc".to_string(),
            "lib/math/src/lib.rs".to_string(),
        ];
        let rewritten = alias.rewrite_rustc_args(args);
        assert_eq!(rewritten[0], "src/bazel-out/k8-opt-exec/bin/external/rustc");
        assert_eq!(rewritten[1], "src/lib/math/src/lib.rs");
    }

    #[test]
    fn test_rewrite_rustc_args_absolute_paths_unchanged() {
        let alias = AliasRoot {
            root: PathBuf::from("/sandbox/__rr"),
            src_prefix: "src/",
            out_alias: "out",
        };
        let args = vec![
            "/abs/rustc".to_string(),
            "/abs/source.rs".to_string(),
            "--extern=std=/abs/libstd.rmeta".to_string(),
            "-Ldependency=/abs/sysroot/lib".to_string(),
            "-Lnative=/abs/native/lib".to_string(),
        ];
        let rewritten = alias.rewrite_rustc_args(args);
        assert_eq!(rewritten[1], "/abs/source.rs"); // absolute: unchanged
        assert_eq!(rewritten[2], "--extern=std=/abs/libstd.rmeta"); // absolute: unchanged
        assert_eq!(rewritten[3], "-Ldependency=/abs/sysroot/lib"); // absolute: unchanged
        assert_eq!(rewritten[4], "-Lnative=/abs/native/lib"); // absolute: unchanged
    }

    #[test]
    fn test_rewrite_rustc_args_remap_path_prefix() {
        let alias = AliasRoot {
            root: PathBuf::from("/sandbox/__rr"),
            src_prefix: "src/",
            out_alias: "out",
        };
        let args = vec![
            "/rustc".to_string(),
            "--remap-path-prefix=bazel-out/k8=/stable".to_string(),
            "--remap-path-prefix=/abs/path=/other".to_string(),
        ];
        let rewritten = alias.rewrite_rustc_args(args);
        assert_eq!(
            rewritten[1],
            "--remap-path-prefix=src/bazel-out/k8=/stable"
        );
        assert_eq!(rewritten[2], "--remap-path-prefix=/abs/path=/other"); // absolute: unchanged
    }

    #[test]
    fn test_create_alias_root_cleans_previous() {
        let tmp = make_test_dir("alias_root_clean");
        let sandbox = tmp.join("sandbox");
        std::fs::create_dir_all(&sandbox).unwrap();
        std::fs::create_dir_all(sandbox.join("bazel-out/bin")).unwrap();
        let old_rr = sandbox.join("__rr");
        std::fs::create_dir_all(old_rr.join("stale")).unwrap();
        std::fs::write(old_rr.join("stale/file.txt"), "old").unwrap();

        let alias = create_alias_root(&sandbox.display().to_string(), "bazel-out/bin").unwrap();

        assert!(!alias.root.join("stale").exists());
        assert!(alias.root.join("src").is_symlink());
        let _ = std::fs::remove_dir_all(&tmp);
    }
}
