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

//! Per-request context for Bazel work requests.
//!
//! `RequestExecutor` pairs a request ID with its classified `RequestKind` and an
//! optional shared `RustcInvocation`. It provides `execute_*` methods that use
//! `RustcInvocation` + rustc threads for pipelined requests and delegate to
//! subprocess execution for non-pipelined requests.

use std::collections::HashMap;
use std::process::{Command, Stdio};
use std::sync::Arc;

use super::invocation::{spawn_pipelined_rustc, InvocationDirs, RustcInvocation};
use super::args::{
    build_rustc_env, prepare_expanded_rustc_outputs, prepare_rustc_args,
    resolve_pw_args_for_request, rewrite_emit_metadata_path, rewrite_out_dir_in_expanded,
    strip_pipelining_flags,
};
use crate::options::parse_pw_args;
use super::pipeline::{
    append_pipeline_log, copy_outputs_unsandboxed, copy_rmeta_unsandboxed,
    create_pipeline_context, maybe_cleanup_pipeline_dir, pipelining_err, RequestKind,
    WorkerStateRoots,
};
use super::protocol::ParsedWorkRequest;
use super::registry::SharedRequestCoordinator;
use super::exec::{prepare_outputs, resolve_request_relative_path, run_request};
use super::sandbox::{
    copy_all_outputs_to_sandbox, copy_output_to_sandbox, run_sandboxed_request,
};
use super::types::PipelineKey;
use super::pipeline::PipelineContext;
use super::types::OutputDir;
use crate::options::ParsedPwArgs;

/// All prepared state needed to spawn a metadata rustc invocation.
struct MetadataInvocationReady {
    rustc_args: Vec<String>,
    env: HashMap<String, String>,
    ctx: PipelineContext,
    original_out_dir: OutputDir,
    pw_args: ParsedPwArgs,
}

/// Per-request context, owned by the request thread. Not stored in the registry.
pub(super) struct RequestExecutor {
    pub(super) kind: RequestKind,
    /// Shared invocation for pipelined requests. None for non-pipelined.
    pub(super) invocation: Option<Arc<RustcInvocation>>,
}

impl RequestExecutor {
    pub(super) fn new(kind: RequestKind, invocation: Option<Arc<RustcInvocation>>) -> Self {
        Self { kind, invocation }
    }

    /// Execute a pipelined metadata request.
    ///
    /// Spawns rustc, starts a rustc thread, waits for metadata readiness,
    /// copies the .rmeta output, and returns diagnostics.
    pub(super) fn execute_metadata(
        &self,
        request: &ParsedWorkRequest,
        full_args: Vec<String>,
        state_roots: &WorkerStateRoots,
        registry: &SharedRequestCoordinator,
    ) -> (i32, String) {
        let key = match &self.kind {
            RequestKind::Metadata { key } => key.clone(),
            _ => {
                return (
                    1,
                    "execute_metadata called for non-metadata request".to_string(),
                )
            }
        };

        let ready = match prepare_metadata_invocation(&key, full_args, request, state_roots) {
            Ok(r) => r,
            Err(e) => return e,
        };
        let MetadataInvocationReady {
            rustc_args,
            env,
            ctx,
            original_out_dir,
            pw_args,
        } = ready;

        append_pipeline_log(
            &ctx.root_dir,
            &format!(
                "metadata start request_id={} key={} sandbox_dir={:?} execroot={} outputs={}",
                request.request_id,
                key,
                request.sandbox_dir,
                ctx.execroot_dir.display(),
                ctx.outputs_dir.display(),
            ),
        );

        // --- Windows response file handling ---
        #[cfg(windows)]
        let _consolidated_dir_guard: Option<std::path::PathBuf>;
        #[cfg(windows)]
        let mut rustc_args = rustc_args;
        #[cfg(windows)]
        {
            let unified_dir = ctx.root_dir.join("deps");
            let _ = std::fs::remove_dir_all(&unified_dir);
            if let Err(e) = std::fs::create_dir_all(&unified_dir) {
                return (1, format!("pipelining: failed to create deps dir: {e}"));
            }
            let dep_dirs: Vec<std::path::PathBuf> = rustc_args
                .iter()
                .filter_map(|a| {
                    a.strip_prefix("-Ldependency=")
                        .map(std::path::PathBuf::from)
                })
                .collect();
            crate::util::consolidate_deps_into(&dep_dirs, &unified_dir);
            rustc_args.retain(|a| !a.starts_with("-Ldependency="));
            rustc_args.push(format!("-Ldependency={}", unified_dir.display()));
            _consolidated_dir_guard = Some(unified_dir);
        }

        // --- Spawn rustc ---
        let mut cmd = Command::new(&rustc_args[0]);
        #[cfg(windows)]
        {
            let response_file_path = ctx.root_dir.join("metadata_rustc.args");
            let content = rustc_args[1..].join("\n");
            if let Err(e) = std::fs::write(&response_file_path, &content) {
                return (1, format!("pipelining: failed to write response file: {e}"));
            }
            cmd.arg(format!("@{}", response_file_path.display()));
        }
        #[cfg(not(windows))]
        {
            cmd.args(&rustc_args[1..]);
        }
        cmd.env_clear()
            .envs(&env)
            .stdout(Stdio::null())
            .stderr(Stdio::piped())
            .current_dir(&ctx.execroot_dir);
        let child = match cmd.spawn() {
            Ok(c) => c,
            Err(e) => return (1, format!("pipelining: failed to spawn rustc: {e}")),
        };

        // --- Start rustc thread ---
        let dirs = InvocationDirs {
            pipeline_output_dir: ctx.outputs_dir.clone(),
            pipeline_root_dir: ctx.root_dir.clone(),
            original_out_dir,
        };

        let original_out_dir = dirs.original_out_dir.clone();
        let invocation =
            spawn_pipelined_rustc(child, dirs, pw_args.rustc_output_format.clone());

        // Insert into registry so the full request can find it.
        // This is the only point where an invocation enters the registry,
        // guaranteeing that any invocation found by register_full has a
        // running rustc behind it (no stuck-Pending deadlocks).
        registry
            .lock()
            .expect("request registry mutex poisoned")
            .insert_invocation(key.clone(), Arc::clone(&invocation));

        // --- Wait for metadata readiness ---
        // The rustc thread detects the rmeta artifact notification and
        // transitions to MetadataReady. We then copy the .rmeta file here
        // in the request thread. There is a small timing gap between
        // detection and copy, but this is safe because:
        //   1. The rmeta lives in _pw_state/pipeline/<key>/, which is
        //      worker-owned and not subject to Bazel sandbox cleanup.
        //   2. We haven't sent the WorkResponse yet, so Bazel doesn't
        //      know metadata is ready and can't act on it.
        //   3. Rustc doesn't overwrite .rmeta after emitting the artifact
        //      notification — post-rmeta work is codegen only.
        match invocation.wait_for_metadata() {
            Ok(meta) => {
                if let Some(rmeta_path_str) = &meta.rmeta_path {
                    let rmeta_resolved =
                        resolve_request_relative_path(rmeta_path_str, Some(&ctx.execroot_dir));
                    let rmeta_resolved_str = rmeta_resolved.display().to_string();
                    append_pipeline_log(
                        &ctx.root_dir,
                        &format!("metadata rmeta ready: {}", rmeta_resolved_str),
                    );
                    let copy_err = match request.sandbox_dir.as_ref() {
                        Some(dir) => copy_output_to_sandbox(
                            &rmeta_resolved,
                            dir.as_path(),
                            original_out_dir.as_str(),
                            "_pipeline",
                        )
                        .err()
                        .map(|e| format!("pipelining: rmeta materialization failed: {e}")),
                        None => copy_rmeta_unsandboxed(
                            &rmeta_resolved,
                            original_out_dir.as_str(),
                            &ctx.root_dir,
                        ),
                    };
                    if let Some(err_msg) = copy_err {
                        invocation.request_shutdown();
                        return (1, err_msg);
                    }
                }
                append_pipeline_log(&ctx.root_dir, &format!("metadata stored key={}", key));
                if let Some(ref path) = pw_args.output_file {
                    let _ = std::fs::write(path, &meta.diagnostics_before);
                }
                (0, meta.diagnostics_before)
            }
            Err(failure) => {
                maybe_cleanup_pipeline_dir(&ctx.root_dir, true, "metadata rustc failed");
                if let Some(ref path) = pw_args.output_file {
                    let _ = std::fs::write(path, &failure.diagnostics);
                }
                (failure.exit_code, failure.diagnostics)
            }
        }
    }

    /// Execute a pipelined full (codegen) request.
    ///
    /// Waits for the invocation to complete, copies outputs, returns diagnostics.
    /// Falls back to a full subprocess if no invocation exists.
    pub(super) fn execute_full(
        &self,
        request: &ParsedWorkRequest,
        full_args: Vec<String>,
        self_path: &std::path::Path,
    ) -> (i32, String) {
        let key = match &self.kind {
            RequestKind::Full { key } => key.clone(),
            _ => return (1, "execute_full called for non-full request".to_string()),
        };

        let invocation = match &self.invocation {
            Some(inv) => Arc::clone(inv),
            None => {
                return self.execute_fallback(request, full_args, self_path, &key);
            }
        };

        match invocation.wait_for_completion() {
            Ok(completion) => {
                if completion.exit_code == 0 {
                    let copy_result = match request.sandbox_dir.as_ref() {
                        Some(dir) => copy_all_outputs_to_sandbox(
                            &completion.dirs.pipeline_output_dir,
                            dir.as_path(),
                            completion.dirs.original_out_dir.as_str(),
                        )
                        .map(|_| ())
                        .map_err(|e| format!("pipelining: output materialization failed: {e}")),
                        None => copy_outputs_unsandboxed(
                            &completion.dirs.pipeline_output_dir,
                            completion.dirs.original_out_dir.as_path(),
                        ),
                    };
                    if let Err(e) = copy_result {
                        append_pipeline_log(
                            &completion.dirs.pipeline_root_dir,
                            &format!("full output copy error: {e}"),
                        );
                        return (1, format!("{}\n{e}", completion.diagnostics));
                    }
                }
                append_pipeline_log(
                    &completion.dirs.pipeline_root_dir,
                    &format!("full done key={} exit_code={}", key, completion.exit_code),
                );
                maybe_cleanup_pipeline_dir(
                    &completion.dirs.pipeline_root_dir,
                    completion.exit_code != 0,
                    "full action failed",
                );
                (completion.exit_code, completion.diagnostics)
            }
            Err(_) => {
                // Invocation failed or was shut down — try fallback.
                self.execute_fallback(request, full_args, self_path, &key)
            }
        }
    }

    fn execute_fallback(
        &self,
        request: &ParsedWorkRequest,
        args: Vec<String>,
        self_path: &std::path::Path,
        key: &PipelineKey,
    ) -> (i32, String) {
        let worker_state_root = std::env::current_dir()
            .ok()
            .map(|cwd| cwd.join("_pw_state").join("fallback.log"));
        if let Some(path) = worker_state_root {
            if let Ok(mut file) = std::fs::OpenOptions::new()
                .create(true)
                .append(true)
                .open(path)
            {
                use std::io::Write;
                let _ = writeln!(
                    file,
                    "full missing bg request_id={} key={} sandbox_dir={:?}",
                    request.request_id, key, request.sandbox_dir
                );
            }
        }
        let filtered = strip_pipelining_flags(&args);
        match request.sandbox_dir.as_ref() {
            Some(dir) => run_sandboxed_request(self_path, filtered, dir.as_str())
                .unwrap_or_else(|e| (1, format!("pipelining fallback error: {e}"))),
            None => {
                prepare_outputs(&filtered);
                run_request(self_path, filtered)
                    .unwrap_or_else(|e| (1, format!("pipelining fallback error: {e}")))
            }
        }
    }

    /// Execute a non-pipelined multiplex request.
    ///
    /// Spawns the subprocess, starts a rustc thread for cancellability,
    /// waits for completion, and returns the output.
    pub(super) fn execute_non_pipelined(
        &self,
        full_args: Vec<String>,
        self_path: &std::path::Path,
        sandbox_dir: Option<&str>,
    ) -> (i32, String) {
        use super::exec::spawn_request;
        use super::invocation::spawn_non_pipelined_rustc;

        let context = if sandbox_dir.is_some() {
            "sandboxed subprocess"
        } else {
            "subprocess"
        };
        if let Some(dir) = sandbox_dir {
            let _ = super::sandbox::seed_sandbox_cache_root(std::path::Path::new(dir));
        }

        let child = match spawn_request(self_path, full_args, sandbox_dir, context) {
            Ok(c) => c,
            Err(e) => return (1, format!("worker thread error: {e}")),
        };

        // This invocation is local to the request thread — not stored in the
        // registry. Cancellation only prevents the response (via claim flag);
        // the child process runs to completion.
        let invocation = spawn_non_pipelined_rustc(child);

        match invocation.wait_for_completion() {
            Ok(completion) => (completion.exit_code, completion.diagnostics),
            Err(failure) => (failure.exit_code, failure.diagnostics),
        }
    }
}

/// Prepares all arguments, environment, and pipeline context for a metadata
/// rustc invocation. Extracts the arg-parsing phase from execute_metadata.
fn prepare_metadata_invocation(
    key: &PipelineKey,
    full_args: Vec<String>,
    request: &ParsedWorkRequest,
    state_roots: &WorkerStateRoots,
) -> Result<MetadataInvocationReady, (i32, String)> {
    let filtered = strip_pipelining_flags(&full_args);
    let sep = filtered.iter().position(|a| a == "--");
    let (pw_raw, rustc_and_after) = match sep {
        Some(pos) => (&filtered[..pos], &filtered[pos + 1..]),
        None => return Err(pipelining_err("no '--' separator in args")),
    };
    if rustc_and_after.is_empty() {
        return Err(pipelining_err("no rustc executable after '--'"));
    }

    let ctx = create_pipeline_context(state_roots, key, request)?;

    let mut pw_args = parse_pw_args(pw_raw, &ctx.execroot_dir);
    let (rustc_args, original_out_dir, relocated) =
        prepare_rustc_args(rustc_and_after, &pw_args, &ctx.execroot_dir)?;
    pw_args.merge_relocated(relocated);
    let pw_args = resolve_pw_args_for_request(pw_args, request, &ctx.execroot_dir);
    let env = build_rustc_env(
        &pw_args.env_files,
        pw_args.stable_status_file.as_deref(),
        pw_args.volatile_status_file.as_deref(),
        &pw_args.subst,
    )
    .map_err(|e| pipelining_err(e))?;

    let rustc_args = rewrite_out_dir_in_expanded(rustc_args, &ctx.outputs_dir);
    let rustc_args = rewrite_emit_metadata_path(rustc_args, &ctx.outputs_dir);
    prepare_expanded_rustc_outputs(&rustc_args);

    Ok(MetadataInvocationReady {
        rustc_args,
        env,
        ctx,
        original_out_dir,
        pw_args,
    })
}
