// Copyright 2020 The Bazel Authors. All rights reserved.
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

mod flags;
mod options;
mod output;
mod rustc;
mod util;
mod worker;

use std::collections::HashMap;
#[cfg(windows)]
use std::collections::VecDeque;
use std::fmt;
use std::fs::{self, copy, OpenOptions};
use std::io;
use std::path::PathBuf;
use std::process::{exit, Command, Stdio};
#[cfg(windows)]
use std::time::{SystemTime, UNIX_EPOCH};

use tinyjson::JsonValue;

use crate::options::{options, SubprocessPipeliningMode};
use crate::output::{process_output, LineOutput};
use crate::rustc::ErrorFormat;
#[cfg(windows)]
use crate::util::read_file_to_array;

#[derive(Debug)]
pub(crate) struct ProcessWrapperError(String);

impl fmt::Display for ProcessWrapperError {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "process wrapper error: {}", self.0)
    }
}

impl std::error::Error for ProcessWrapperError {}

macro_rules! debug_log {
    ($($arg:tt)*) => {
        if std::env::var_os("RULES_RUST_PROCESS_WRAPPER_DEBUG").is_some() {
            eprintln!($($arg)*);
        }
    };
}

#[cfg(windows)]
struct TemporaryFileGuard {
    path: Option<PathBuf>,
}

#[cfg(windows)]
impl TemporaryFileGuard {
    fn new(path: Option<PathBuf>) -> Self {
        Self { path }
    }

    fn take(&mut self) -> Option<PathBuf> {
        self.path.take()
    }
}

#[cfg(windows)]
impl Drop for TemporaryFileGuard {
    fn drop(&mut self) {
        if let Some(path) = self.path.take() {
            // May be a file (argfile) or directory (consolidated deps dir).
            let _ = fs::remove_dir_all(&path);
        }
    }
}

#[cfg(not(windows))]
struct TemporaryFileGuard;

#[cfg(not(windows))]
impl TemporaryFileGuard {
    fn new(_: Option<PathBuf>) -> Self {
        TemporaryFileGuard
    }

    fn take(&mut self) -> Option<PathBuf> {
        None
    }
}

#[cfg(windows)]
struct ParsedDependencyArgs {
    dependency_paths: Vec<PathBuf>,
    filtered_args: Vec<String>,
}

#[cfg(windows)]
fn get_dependency_search_paths_from_args(
    initial_args: &[String],
) -> Result<ParsedDependencyArgs, ProcessWrapperError> {
    let mut dependency_paths = Vec::new();
    let mut filtered_args = Vec::new();
    let mut argfile_contents: HashMap<String, Vec<String>> = HashMap::new();

    let mut queue: VecDeque<(String, Option<String>)> =
        initial_args.iter().map(|arg| (arg.clone(), None)).collect();

    while let Some((arg, parent_argfile)) = queue.pop_front() {
        let target = match &parent_argfile {
            Some(p) => argfile_contents
                .entry(format!("{}.filtered", p))
                .or_default(),
            None => &mut filtered_args,
        };

        if arg == "-L" {
            let next_arg = queue.front().map(|(a, _)| a.as_str());
            if let Some(path) = next_arg.and_then(|n| n.strip_prefix("dependency=")) {
                dependency_paths.push(PathBuf::from(path));
                queue.pop_front();
            } else {
                target.push(arg);
            }
        } else if let Some(path) = arg.strip_prefix("-Ldependency=") {
            dependency_paths.push(PathBuf::from(path));
        } else if let Some(argfile_path) = arg.strip_prefix('@') {
            let lines = read_file_to_array(argfile_path).map_err(|e| {
                ProcessWrapperError(format!("unable to read argfile {}: {}", argfile_path, e))
            })?;

            for line in lines {
                queue.push_back((line, Some(argfile_path.to_string())));
            }

            target.push(format!("@{}.filtered", argfile_path));
        } else {
            target.push(arg);
        }
    }

    for (path, content) in argfile_contents {
        fs::write(&path, content.join("\n")).map_err(|e| {
            ProcessWrapperError(format!("unable to write filtered argfile {}: {}", path, e))
        })?;
    }

    Ok(ParsedDependencyArgs {
        dependency_paths,
        filtered_args,
    })
}

// On Windows, rustc's internal search-path buffer appears to be limited to
// ~32K characters. With many transitive dependencies (400+ `-Ldependency`
// entries), the cumulative path length exceeds this limit and rustc silently
// fails to resolve crates, reporting E0463 ("can't find crate"). This applies
// even if the -Ldependencies are passed via @argfile.
//
// Fix: hard-link all rlib/rmeta files from all `-Ldependency` directories
// into a single consolidated directory, replacing hundreds of search paths
// with one. Hard links share the same inode/content so rustc sees identical
// SVH values and E0460 (SVH mismatch) does not occur.
#[cfg(windows)]
fn consolidate_dependency_search_paths(
    args: &[String],
) -> Result<(Vec<String>, Option<PathBuf>), ProcessWrapperError> {
    let parsed = get_dependency_search_paths_from_args(args)?;
    let ParsedDependencyArgs {
        dependency_paths,
        mut filtered_args,
    } = parsed;

    if dependency_paths.is_empty() {
        return Ok((filtered_args, None));
    }

    let unique_suffix = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis();
    let dir_name = format!(
        "rules_rust_process_wrapper_deps_{}_{}",
        std::process::id(),
        unique_suffix
    );

    let base_dir = std::env::current_dir().map_err(|e| {
        ProcessWrapperError(format!("unable to read current working directory: {}", e))
    })?;
    let unified_dir = base_dir.join(&dir_name);
    fs::create_dir_all(&unified_dir).map_err(|e| {
        ProcessWrapperError(format!(
            "unable to create unified dependency directory {}: {}",
            unified_dir.display(),
            e
        ))
    })?;

    crate::util::consolidate_deps_into(&dependency_paths, &unified_dir);

    filtered_args.push(format!("-Ldependency={}", unified_dir.display()));

    Ok((filtered_args, Some(unified_dir)))
}

#[cfg(not(windows))]
fn consolidate_dependency_search_paths(
    args: &[String],
) -> Result<(Vec<String>, Option<PathBuf>), ProcessWrapperError> {
    Ok((args.to_vec(), None))
}

#[cfg(unix)]
fn symlink_dir(src: &std::path::Path, dest: &std::path::Path) -> Result<(), std::io::Error> {
    std::os::unix::fs::symlink(src, dest)
}

#[cfg(windows)]
fn symlink_dir(src: &std::path::Path, dest: &std::path::Path) -> Result<(), std::io::Error> {
    std::os::windows::fs::symlink_dir(src, dest)
}

enum CacheSeedOutcome {
    AlreadyPresent,
    Seeded { _source: PathBuf },
    NotFound,
}

fn cache_root_from_execroot_ancestor(cwd: &std::path::Path) -> Option<PathBuf> {
    // Walk up from cwd looking for a sibling "cache" directory at each level.
    // Skip directories named "execroot" — cache is never inside execroot itself,
    // but its parent (e.g. <output_base>) typically has a sibling "cache" dir.
    // Typical Bazel layout: <output_base>/execroot/_main/ (cwd)
    //                       <output_base>/cache/          (target)
    for ancestor in cwd.ancestors() {
        if ancestor.file_name().is_some_and(|name| name == "execroot") {
            continue;
        }

        let candidate = ancestor.join("cache");
        if candidate.is_dir() {
            return candidate.canonicalize().ok().or(Some(candidate));
        }
    }

    None
}

fn ensure_cache_loopback_for_path(
    resolved_path: &std::path::Path,
    cache_root: &std::path::Path,
) -> Result<Option<PathBuf>, ProcessWrapperError> {
    let Ok(relative) = resolved_path.strip_prefix(cache_root) else {
        return Ok(None);
    };
    let mut components = relative.components();
    if components
        .next()
        .is_none_or(|component| component.as_os_str() != "repos")
    {
        return Ok(None);
    }
    let Some(version) = components.next() else {
        return Ok(None);
    };
    if components
        .next()
        .is_none_or(|component| component.as_os_str() != "contents")
    {
        return Ok(None);
    }

    let version_dir = cache_root.join("repos").join(version.as_os_str());
    let loopback = version_dir.join("cache");
    if loopback.exists() {
        return Ok(Some(loopback));
    }

    symlink_dir(cache_root, &loopback).map_err(|e| {
        ProcessWrapperError(format!(
            "unable to seed cache loopback {} -> {}: {}",
            cache_root.display(),
            loopback.display(),
            e
        ))
    })?;
    Ok(Some(loopback))
}

fn ensure_cache_loopback_from_args(
    cwd: &std::path::Path,
    child_arguments: &[String],
    cache_root: &std::path::Path,
) -> Result<Option<PathBuf>, ProcessWrapperError> {
    for arg in child_arguments {
        let candidate = cwd.join(arg);
        let Ok(resolved) = candidate.canonicalize() else {
            continue;
        };
        if let Some(loopback) = ensure_cache_loopback_for_path(&resolved, cache_root)? {
            return Ok(Some(loopback));
        }
    }

    Ok(None)
}

fn seed_cache_root_for_current_dir() -> Result<CacheSeedOutcome, ProcessWrapperError> {
    let cwd = std::env::current_dir().map_err(|e| {
        ProcessWrapperError(format!("unable to read current working directory: {e}"))
    })?;
    let dest = cwd.join("cache");
    if dest.exists() {
        return Ok(CacheSeedOutcome::AlreadyPresent);
    }

    if let Some(cache_root) = cache_root_from_execroot_ancestor(&cwd) {
        symlink_dir(&cache_root, &dest).map_err(|e| {
            ProcessWrapperError(format!(
                "unable to seed cache root {} -> {}: {}",
                cache_root.display(),
                dest.display(),
                e
            ))
        })?;
        return Ok(CacheSeedOutcome::Seeded {
            _source: cache_root,
        });
    }

    for entry in fs::read_dir(&cwd).map_err(|e| {
        ProcessWrapperError(format!("unable to read current working directory: {e}"))
    })? {
        let entry = entry.map_err(|e| {
            ProcessWrapperError(format!(
                "unable to enumerate current working directory: {e}"
            ))
        })?;
        let Ok(resolved) = entry.path().canonicalize() else {
            continue;
        };

        for ancestor in resolved.ancestors() {
            if ancestor.file_name().is_some_and(|name| name == "cache") {
                symlink_dir(ancestor, &dest).map_err(|e| {
                    ProcessWrapperError(format!(
                        "unable to seed cache root {} -> {}: {}",
                        ancestor.display(),
                        dest.display(),
                        e
                    ))
                })?;
                return Ok(CacheSeedOutcome::Seeded {
                    _source: ancestor.to_path_buf(),
                });
            }
        }
    }

    Ok(CacheSeedOutcome::NotFound)
}

fn json_warning(line: &str) -> JsonValue {
    JsonValue::Object(HashMap::from([
        (
            "$message_type".to_string(),
            JsonValue::String("diagnostic".to_string()),
        ),
        ("message".to_string(), JsonValue::String(line.to_string())),
        ("code".to_string(), JsonValue::Null),
        (
            "level".to_string(),
            JsonValue::String("warning".to_string()),
        ),
        ("spans".to_string(), JsonValue::Array(Vec::new())),
        ("children".to_string(), JsonValue::Array(Vec::new())),
        ("rendered".to_string(), JsonValue::String(line.to_string())),
    ]))
}

fn process_line(mut line: String, format: ErrorFormat) -> Result<LineOutput, String> {
    // LLVM can emit lines that look like the following, and these will be interspersed
    // with the regular JSON output. Arguably, rustc should be fixed not to emit lines
    // like these (or to convert them to JSON), but for now we convert them to JSON
    // ourselves.
    if line.contains("is not a recognized feature for this target (ignoring feature)")
        || line.starts_with(" WARN ")
    {
        if let Ok(json_str) = json_warning(&line).stringify() {
            line = json_str;
        } else {
            return Ok(LineOutput::Skip);
        }
    }
    rustc::process_json(line, format)
}

fn main() -> Result<(), ProcessWrapperError> {
    // Check if Bazel is invoking us as a persistent worker.
    if std::env::args().any(|a| a == "--persistent_worker") {
        return worker::worker_main();
    }

    let opts = options().map_err(|e| ProcessWrapperError(e.to_string()))?;

    // Worker pipelining local-mode no-op optimization.
    //
    // When the process_wrapper runs outside a persistent worker (local or
    // sandboxed-without-sandbox fallback) and the action is --pipelining-full,
    // the metadata action has already run a complete rustc invocation that
    // produced both the .rmeta (declared output) and the .rlib (side-effect).
    // If the .rlib exists on disk, we can skip the redundant second rustc
    // invocation entirely. This guarantees SVH consistency because the .rmeta
    // and .rlib came from the same compilation.
    //
    // If the .rlib does NOT exist (e.g. sandboxed execution discarded the
    // side-effect, or the metadata action was an action-cache hit), we fall
    // through to running rustc normally.
    if opts.pipelining_mode == Some(SubprocessPipeliningMode::Full) {
        if let Some(ref rlib_path) = opts.pipelining_rlib_path {
            if std::path::Path::new(rlib_path).exists() {
                debug_log!(
                    "pipelining no-op: .rlib already exists at {}, skipping rustc",
                    rlib_path
                );
                // Handle post-success actions that the normal path would do.
                if let Some(ref tf) = opts.touch_file {
                    OpenOptions::new()
                        .create(true)
                        .truncate(true)
                        .write(true)
                        .open(tf)
                        .map_err(|e| {
                            ProcessWrapperError(format!("failed to create touch file: {}", e))
                        })?;
                }
                if let Some((ref copy_source, ref copy_dest)) = opts.copy_output {
                    copy(copy_source, copy_dest).map_err(|e| {
                        ProcessWrapperError(format!(
                            "failed to copy {} into {}: {}",
                            copy_source, copy_dest, e
                        ))
                    })?;
                }
                exit(0);
            }
            eprintln!(concat!(
                "WARNING: [rules_rust] Worker pipelining full action executing outside a worker.\n",
                "The metadata action's .rlib side-effect was not found, so a redundant second\n",
                "rustc invocation will run. This happens when Bazel falls back from worker to\n",
                "sandboxed execution (sandbox discards undeclared outputs). The build may still\n",
                "succeed if all proc macros are deterministic, but nondeterministic proc macros\n",
                "will cause E0460 (SVH mismatch).\n",
                "\n",
                "To fix: set --@rules_rust//rust/settings:experimental_worker_pipelining=false\n",
                "        to use hollow-rlib pipelining (safe for all execution strategies).\n",
            ));
        }
    }

    let (child_arguments, dep_argfile_cleanup) =
        consolidate_dependency_search_paths(&opts.child_arguments)?;
    let mut temp_file_guard = TemporaryFileGuard::new(dep_argfile_cleanup);
    let cwd = std::env::current_dir().map_err(|e| {
        ProcessWrapperError(format!("unable to read current working directory: {e}"))
    })?;
    let _ = seed_cache_root_for_current_dir();
    if let Some(cache_root) = cache_root_from_execroot_ancestor(&cwd) {
        let _ = ensure_cache_loopback_from_args(&cwd, &child_arguments, &cache_root);
    }

    let mut command = Command::new(opts.executable);
    command
        .args(child_arguments)
        .env_clear()
        .envs(opts.child_environment)
        .stdout(if let Some(stdout_file) = opts.stdout_file {
            OpenOptions::new()
                .create(true)
                .truncate(true)
                .write(true)
                .open(stdout_file)
                .map_err(|e| ProcessWrapperError(format!("unable to open stdout file: {}", e)))?
                .into()
        } else {
            Stdio::inherit()
        })
        .stderr(Stdio::piped());
    debug_log!("{:#?}", command);
    let mut child = command
        .spawn()
        .map_err(|e| ProcessWrapperError(format!("failed to spawn child process: {}", e)))?;

    let mut stderr: Box<dyn io::Write> = if let Some(stderr_file) = opts.stderr_file {
        Box::new(
            OpenOptions::new()
                .create(true)
                .truncate(true)
                .write(true)
                .open(stderr_file)
                .map_err(|e| ProcessWrapperError(format!("unable to open stderr file: {}", e)))?,
        )
    } else {
        Box::new(io::stderr())
    };

    let mut child_stderr = child.stderr.take().ok_or(ProcessWrapperError(
        "unable to get child stderr".to_string(),
    ))?;

    let mut output_file: Option<std::fs::File> = if let Some(output_file_name) = opts.output_file {
        Some(
            OpenOptions::new()
                .create(true)
                .truncate(true)
                .write(true)
                .open(output_file_name)
                .map_err(|e| ProcessWrapperError(format!("Unable to open output_file: {}", e)))?,
        )
    } else {
        None
    };

    let result = if let Some(format) = opts.rustc_output_format {
        process_output(
            &mut child_stderr,
            stderr.as_mut(),
            output_file.as_mut(),
            move |line| process_line(line, format),
        )
    } else {
        // Process output normally by forwarding stderr
        process_output(
            &mut child_stderr,
            stderr.as_mut(),
            output_file.as_mut(),
            move |line| Ok(LineOutput::Message(line)),
        )
    };
    result.map_err(|e| ProcessWrapperError(format!("failed to process stderr: {}", e)))?;

    let status = child
        .wait()
        .map_err(|e| ProcessWrapperError(format!("failed to wait for child process: {}", e)))?;
    let code = status.code().unwrap_or(1);
    if code == 0 {
        if let Some(tf) = opts.touch_file {
            OpenOptions::new()
                .create(true)
                .truncate(true)
                .write(true)
                .open(tf)
                .map_err(|e| ProcessWrapperError(format!("failed to create touch file: {}", e)))?;
        }
        if let Some((copy_source, copy_dest)) = opts.copy_output {
            copy(&copy_source, &copy_dest).map_err(|e| {
                ProcessWrapperError(format!(
                    "failed to copy {} into {}: {}",
                    copy_source, copy_dest, e
                ))
            })?;
        }
    }

    // When a pipelining-full action fails outside a worker (the warning above
    // was already printed), repeat the fix suggestion next to the error output.
    if code != 0
        && opts.pipelining_mode == Some(SubprocessPipeliningMode::Full)
        && opts
            .pipelining_rlib_path
            .as_ref()
            .is_some_and(|p| !std::path::Path::new(p).exists())
    {
        eprintln!(concat!(
            "\nERROR: [rules_rust] Redundant rustc invocation failed (see warning above).\n",
            "If the error is E0460 (SVH mismatch), set:\n",
            "  --@rules_rust//rust/settings:experimental_worker_pipelining=false\n",
        ));
    }

    if let Some(path) = temp_file_guard.take() {
        // Consolidated dependency dir: remove the whole directory tree.
        let _ = fs::remove_dir_all(&path);
    }

    exit(code)
}

#[cfg(test)]
mod test {
    use super::*;

    fn parse_json(json_str: &str) -> Result<JsonValue, String> {
        json_str.parse::<JsonValue>().map_err(|e| e.to_string())
    }

    #[test]
    fn test_process_line_diagnostic_json() -> Result<(), String> {
        let LineOutput::Message(msg) = process_line(
            r#"
                {
                    "$message_type": "diagnostic",
                    "rendered": "Diagnostic message"
                }
            "#
            .to_string(),
            ErrorFormat::Json,
        )?
        else {
            return Err("Expected a LineOutput::Message".to_string());
        };
        assert_eq!(
            parse_json(&msg)?,
            parse_json(
                r#"
                {
                    "$message_type": "diagnostic",
                    "rendered": "Diagnostic message"
                }
            "#
            )?
        );
        Ok(())
    }

    #[test]
    fn test_process_line_diagnostic_rendered() -> Result<(), String> {
        let LineOutput::Message(msg) = process_line(
            r#"
                {
                    "$message_type": "diagnostic",
                    "rendered": "Diagnostic message"
                }
            "#
            .to_string(),
            ErrorFormat::Rendered,
        )?
        else {
            return Err("Expected a LineOutput::Message".to_string());
        };
        assert_eq!(msg, "Diagnostic message");
        Ok(())
    }

    #[test]
    fn test_process_line_noise() -> Result<(), String> {
        for text in [
            "'+zaamo' is not a recognized feature for this target (ignoring feature)",
            " WARN rustc_errors::emitter Invalid span...",
        ] {
            let LineOutput::Message(msg) = process_line(text.to_string(), ErrorFormat::Json)?
            else {
                return Err("Expected a LineOutput::Message".to_string());
            };
            assert_eq!(
                parse_json(&msg)?,
                parse_json(&format!(
                    r#"{{
                        "$message_type": "diagnostic",
                        "message": "{0}",
                        "code": null,
                        "level": "warning",
                        "spans": [],
                        "children": [],
                        "rendered": "{0}"
                    }}"#,
                    text
                ))?
            );
        }
        Ok(())
    }

    #[test]
    fn test_process_line_emit_link() -> Result<(), String> {
        assert!(matches!(
            process_line(
                r#"
                {
                    "$message_type": "artifact",
                    "emit": "link"
                }
            "#
                .to_string(),
                ErrorFormat::Rendered,
            )?,
            LineOutput::Skip
        ));
        Ok(())
    }

    #[test]
    fn test_process_line_emit_metadata() -> Result<(), String> {
        assert!(matches!(
            process_line(
                r#"
                {
                    "$message_type": "artifact",
                    "emit": "metadata"
                }
            "#
                .to_string(),
                ErrorFormat::Rendered,
            )?,
            LineOutput::Skip
        ));
        Ok(())
    }

    #[test]
    #[cfg(unix)]
    fn test_seed_cache_root_for_current_dir() -> Result<(), String> {
        let tmp = std::env::temp_dir().join("pw_test_seed_cache_root_for_current_dir");
        let sandbox_dir = tmp.join("sandbox");
        let cache_repo = tmp.join("cache/repos/v1/contents/hash/repo");
        fs::create_dir_all(&sandbox_dir).map_err(|e| e.to_string())?;
        fs::create_dir_all(cache_repo.join("tool/src")).map_err(|e| e.to_string())?;
        symlink_dir(&cache_repo, &sandbox_dir.join("external_repo")).map_err(|e| e.to_string())?;

        let old_cwd = std::env::current_dir().map_err(|e| e.to_string())?;
        std::env::set_current_dir(&sandbox_dir).map_err(|e| e.to_string())?;
        let result = seed_cache_root_for_current_dir().map_err(|e| e.to_string());
        let restore = std::env::set_current_dir(old_cwd).map_err(|e| e.to_string());
        let seeded_target = sandbox_dir
            .join("cache")
            .canonicalize()
            .map_err(|e| e.to_string());

        let _ = fs::remove_dir_all(&tmp);

        result?;
        restore?;
        assert_eq!(seeded_target?, tmp.join("cache"));
        Ok(())
    }

    #[test]
    #[cfg(unix)]
    fn test_seed_cache_root_from_execroot_ancestor() -> Result<(), String> {
        let tmp = std::env::temp_dir().join("pw_test_seed_cache_root_from_execroot_ancestor");
        let cwd = tmp.join("output-base/execroot/_main");
        fs::create_dir_all(tmp.join("output-base/cache/repos")).map_err(|e| e.to_string())?;
        fs::create_dir_all(&cwd).map_err(|e| e.to_string())?;

        let old_cwd = std::env::current_dir().map_err(|e| e.to_string())?;
        std::env::set_current_dir(&cwd).map_err(|e| e.to_string())?;
        let result = seed_cache_root_for_current_dir().map_err(|e| e.to_string());
        let restore = std::env::set_current_dir(old_cwd).map_err(|e| e.to_string());
        let seeded_target = cwd.join("cache").canonicalize().map_err(|e| e.to_string());

        let _ = fs::remove_dir_all(&tmp);

        result?;
        restore?;
        assert_eq!(seeded_target?, tmp.join("output-base/cache"));
        Ok(())
    }

    #[test]
    #[cfg(unix)]
    fn test_ensure_cache_loopback_from_args() -> Result<(), String> {
        let tmp = std::env::temp_dir().join("pw_test_ensure_cache_loopback_from_args");
        let cwd = tmp.join("output-base/execroot/_main");
        let cache_root = tmp.join("output-base/cache");
        let source = cache_root.join("repos/v1/contents/hash/repo/.tmp_git_root/tool/src/lib.rs");
        fs::create_dir_all(source.parent().unwrap()).map_err(|e| e.to_string())?;
        fs::create_dir_all(&cwd).map_err(|e| e.to_string())?;
        fs::write(&source, "").map_err(|e| e.to_string())?;
        symlink_dir(
            &cache_root.join("repos/v1/contents/hash/repo"),
            &cwd.join("external_repo"),
        )
        .map_err(|e| e.to_string())?;

        let loopback = ensure_cache_loopback_from_args(
            &cwd,
            &[String::from("external_repo/.tmp_git_root/tool/src/lib.rs")],
            &cache_root,
        )
        .map_err(|e| e.to_string())?;
        let loopback_target = cache_root
            .join("repos/v1/cache")
            .canonicalize()
            .map_err(|e| e.to_string())?;

        let _ = fs::remove_dir_all(&tmp);

        assert_eq!(loopback, Some(cache_root.join("repos/v1/cache")));
        assert_eq!(loopback_target, cache_root);
        Ok(())
    }
}
