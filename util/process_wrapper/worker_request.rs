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

//! Request parsing and execution context for Bazel work requests.

use std::collections::HashMap;
use std::path::PathBuf;
use std::process::{Command, Stdio};
use std::sync::Arc;

use crate::options::{parse_pw_args, ParsedPwArgs, SubprocessPipeliningMode};

use super::args::{
    build_rustc_env, expand_rustc_args_with_metadata, prepare_rustc_args,
    resolve_pw_args_for_request, rewrite_expanded_rustc_outputs, scan_pipelining_flags,
    strip_pipelining_flags,
};
use super::exec::{
    prepare_expanded_rustc_outputs, prepare_outputs, resolve_request_relative_path, run_request,
};
use super::invocation::{InvocationDirs, MetadataOutput, RustcInvocation};
use super::logging::append_pipeline_log;
use super::pipeline::{
    copy_outputs_unsandboxed, copy_rmeta_unsandboxed, create_pipeline_context,
    maybe_cleanup_pipeline_dir, pipelining_err, PipelineContext, WorkerStateRoots,
};
use super::SharedRequestCoordinator;
use super::rustc_driver::spawn_pipelined_rustc;
use super::sandbox::{copy_all_outputs_to_sandbox, copy_output_to_sandbox, seed_sandbox_cache_root};
use super::types::{OutputDir, PipelineKey, RequestId, SandboxDir};

/// Fields needed to execute one Bazel work request.
#[derive(Clone, Debug)]
pub(crate) struct WorkRequest {
    pub(crate) request_id: RequestId,
    pub(crate) arguments: Vec<String>,
    pub(crate) sandbox_dir: Option<SandboxDir>,
    pub(crate) cancel: bool,
}

impl WorkRequest {
    /// Returns the base directory for this request.
    pub(crate) fn base_dir(&self) -> Result<PathBuf, String> {
        if let Some(sandbox_dir) = self.sandbox_dir.as_ref() {
            if sandbox_dir.as_path().is_absolute() {
                return Ok(sandbox_dir.as_path().to_path_buf());
            }
            return std::env::current_dir()
                .map(|cwd| cwd.join(sandbox_dir.as_path()))
                .map_err(|e| format!("failed to resolve worker cwd: {e}"));
        }
        std::env::current_dir().map_err(|e| format!("failed to resolve worker cwd: {e}"))
    }

    /// Like [`base_dir`], but canonicalizes the unsandboxed path.
    pub(crate) fn base_dir_canonicalized(&self) -> Result<PathBuf, String> {
        let dir = self.base_dir()?;
        if self.sandbox_dir.is_some() {
            Ok(dir)
        } else {
            std::fs::canonicalize(&dir)
                .map_err(|e| format!("failed to canonicalize worker CWD: {e}"))
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) enum RequestKind {
    /// Handle as a normal subprocess request.
    NonPipelined,
    /// Start rustc and return once metadata is ready.
    Metadata { key: PipelineKey },
    /// Reuse a metadata invocation and wait for completion.
    Full { key: PipelineKey },
}

impl RequestKind {
    pub(crate) fn parse_in_dir(args: &[String], base_dir: &std::path::Path) -> Self {
        let direct = scan_pipelining_flags(args.iter().map(String::as_str));
        if !matches!(direct, RequestKind::NonPipelined) {
            return direct;
        }

        // No direct pipelining flags; check any expanded paramfiles.
        let mut parts = args.splitn(2, |a| a == "--");
        let pw_raw = parts.next().unwrap();
        let rustc_args = parts.next().unwrap_or(&[]);
        let parsed_pw_args = parse_pw_args(pw_raw, base_dir);
        let nested = expand_rustc_args_with_metadata(
            rustc_args,
            &parsed_pw_args.subst,
            parsed_pw_args.require_explicit_unstable_features,
            base_dir,
        )
        .ok()
        .map(|(_, metadata)| metadata)
        .unwrap_or_default();

        let is_metadata =
            nested.relocated.pipelining_mode == Some(SubprocessPipeliningMode::Metadata);
        let is_full = nested.relocated.pipelining_mode == Some(SubprocessPipeliningMode::Full);
        let key = nested.pipelining_key;

        match (is_metadata, is_full, key) {
            (true, _, Some(k)) => RequestKind::Metadata {
                key: PipelineKey(k),
            },
            (_, true, Some(k)) => RequestKind::Full {
                key: PipelineKey(k),
            },
            _ => RequestKind::NonPipelined,
        }
    }

    /// Returns the pipeline key if this is a pipelined request.
    pub(crate) fn key(&self) -> Option<&PipelineKey> {
        match self {
            RequestKind::Metadata { key } | RequestKind::Full { key } => Some(key),
            RequestKind::NonPipelined => None,
        }
    }
}

/// All prepared state needed to spawn a metadata rustc invocation.
struct MetadataInvocationReady {
    rustc_args: Vec<String>,
    env: HashMap<String, String>,
    ctx: PipelineContext,
    original_out_dir: OutputDir,
    pw_args: ParsedPwArgs,
}

/// Per-request executor owned by a request thread.
pub(super) struct RequestExecutor {
    pub(super) kind: RequestKind,
    /// Shared invocation for pipelined requests.
    pub(super) invocation: Option<Arc<RustcInvocation>>,
}

impl RequestExecutor {
    pub(super) fn new(kind: RequestKind, invocation: Option<Arc<RustcInvocation>>) -> Self {
        Self { kind, invocation }
    }

    /// Executes a metadata request and returns once `.rmeta` is ready.
    pub(super) fn execute_metadata(
        &self,
        request: &WorkRequest,
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

        append_pipeline_log(
            &ready.ctx.root_dir,
            &format!(
                "metadata start request_id={} key={} sandbox_dir={:?} execroot={} outputs={}",
                request.request_id,
                key,
                request.sandbox_dir,
                ready.ctx.execroot_dir.display(),
                ready.ctx.outputs_dir.display(),
            ),
        );

        let (invocation, original_out_dir, ctx, pw_args) =
            match spawn_metadata_rustc(ready, &key, registry) {
                Ok(result) => result,
                Err(e) => return e,
            };

        // The `.rmeta` stays in the worker-owned pipeline dir until we copy it
        // and send the response.
        match invocation.wait_for_metadata() {
            Ok(meta) => materialize_metadata(
                meta,
                &invocation,
                &ctx,
                request,
                &original_out_dir,
                &key,
                &pw_args,
            ),
            Err(failure) => {
                maybe_cleanup_pipeline_dir(&ctx.root_dir, true, "metadata rustc failed");
                if let Some(ref path) = pw_args.output_file {
                    let _ = std::fs::write(path, &failure.diagnostics);
                }
                (failure.exit_code, failure.diagnostics)
            }
        }
    }

    /// Executes a full request, or falls back to a fresh subprocess.
    pub(super) fn execute_full(
        &self,
        request: &WorkRequest,
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
                // Fall back if the shared invocation failed or was shut down.
                self.execute_fallback(request, full_args, self_path, &key)
            }
        }
    }

    fn execute_fallback(
        &self,
        request: &WorkRequest,
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
            Some(dir) => {
                let _ = seed_sandbox_cache_root(dir.as_path());
                run_request(self_path, filtered, Some(dir.as_str()), "sandboxed subprocess")
                    .unwrap_or_else(|e| (1, format!("pipelining fallback error: {e}")))
            }
            None => {
                prepare_outputs(&filtered, None);
                run_request(self_path, filtered, None, "process_wrapper subprocess")
                    .unwrap_or_else(|e| (1, format!("pipelining fallback error: {e}")))
            }
        }
    }

    /// Executes a non-pipelined multiplex request.
    pub(super) fn execute_non_pipelined(
        &self,
        full_args: Vec<String>,
        self_path: &std::path::Path,
        sandbox_dir: Option<&str>,
    ) -> (i32, String) {
        use super::exec::spawn_request;
        use super::rustc_driver::spawn_non_pipelined_rustc;

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

        // This invocation stays local to the request thread. Cancellation only
        // suppresses the response.
        let invocation = spawn_non_pipelined_rustc(child);

        match invocation.wait_for_completion() {
            Ok(completion) => (completion.exit_code, completion.diagnostics),
            Err(failure) => (failure.exit_code, failure.diagnostics),
        }
    }
}

/// Prepares args, environment, and directories for a metadata rustc invocation.
fn prepare_metadata_invocation(
    key: &PipelineKey,
    full_args: Vec<String>,
    request: &WorkRequest,
    state_roots: &WorkerStateRoots,
) -> Result<MetadataInvocationReady, (i32, String)> {
    let filtered = strip_pipelining_flags(&full_args);
    let mut parts = filtered.splitn(2, |a| a == "--");
    let pw_raw = parts.next().unwrap();
    let rustc_and_after = parts
        .next()
        .ok_or_else(|| pipelining_err("no '--' separator in args"))?;
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

    let (rustc_args, writable_outputs) =
        rewrite_expanded_rustc_outputs(rustc_args, &ctx.outputs_dir);
    prepare_expanded_rustc_outputs(&writable_outputs);

    Ok(MetadataInvocationReady {
        rustc_args,
        env,
        ctx,
        original_out_dir,
        pw_args,
    })
}

/// Spawns rustc for a metadata request and registers the running invocation.
fn spawn_metadata_rustc(
    ready: MetadataInvocationReady,
    key: &PipelineKey,
    registry: &SharedRequestCoordinator,
) -> Result<
    (
        Arc<RustcInvocation>,
        OutputDir,
        PipelineContext,
        ParsedPwArgs,
    ),
    (i32, String),
> {
    let MetadataInvocationReady {
        rustc_args,
        env,
        ctx,
        original_out_dir,
        pw_args,
    } = ready;

    #[cfg(windows)]
    let _consolidated_dir_guard: Option<std::path::PathBuf>;
    #[cfg(windows)]
    let mut rustc_args = rustc_args;
    #[cfg(windows)]
    {
        let unified_dir = ctx.root_dir.join("deps");
        let _ = std::fs::remove_dir_all(&unified_dir);
        if let Err(e) = std::fs::create_dir_all(&unified_dir) {
            return Err((1, format!("pipelining: failed to create deps dir: {e}")));
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

    let mut cmd = Command::new(&rustc_args[0]);
    #[cfg(windows)]
    {
        let response_file_path = ctx.root_dir.join("metadata_rustc.args");
        let content = rustc_args[1..].join("\n");
        if let Err(e) = std::fs::write(&response_file_path, &content) {
            return Err((1, format!("pipelining: failed to write response file: {e}")));
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
        Err(e) => return Err((1, format!("pipelining: failed to spawn rustc: {e}"))),
    };

    let dirs = InvocationDirs {
        pipeline_output_dir: ctx.outputs_dir.clone(),
        pipeline_root_dir: ctx.root_dir.clone(),
        original_out_dir,
    };

    let original_out_dir = dirs.original_out_dir.clone();
    let invocation = spawn_pipelined_rustc(child, dirs, pw_args.rustc_output_format.clone());

    // Publish the running invocation so full requests can find it.
    registry
        .lock()
        .expect("request registry mutex poisoned")
        .invocations
        .insert(key.clone(), Arc::clone(&invocation));

    Ok((invocation, original_out_dir, ctx, pw_args))
}

/// Copies `.rmeta` and returns metadata diagnostics.
fn materialize_metadata(
    meta: MetadataOutput,
    invocation: &RustcInvocation,
    ctx: &PipelineContext,
    request: &WorkRequest,
    original_out_dir: &OutputDir,
    key: &PipelineKey,
    pw_args: &ParsedPwArgs,
) -> (i32, String) {
    if let Some(rmeta_path_str) = &meta.rmeta_path {
        let rmeta_resolved = resolve_request_relative_path(rmeta_path_str, Some(&ctx.execroot_dir));
        append_pipeline_log(
            &ctx.root_dir,
            &format!("metadata rmeta ready: {}", rmeta_resolved.display()),
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
            None => {
                copy_rmeta_unsandboxed(&rmeta_resolved, original_out_dir.as_str(), &ctx.root_dir)
            }
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
