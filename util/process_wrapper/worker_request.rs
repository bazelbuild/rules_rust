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

//! Thread-local request context for Bazel work requests.
//!
//! `BazelRequest` wraps a `WorkRequestContext` with its classified `RequestKind`
//! and an optional `RustcInvocation` reference. It provides `execute_*` methods
//! that dispatch to the appropriate handler.
//!
//! **Current state (delegation layer):** The execute methods delegate to the
//! existing handler functions in `worker_pipeline.rs`. These will be migrated
//! to use `RustcInvocation` + monitor threads in a follow-up.

use std::sync::{Arc, Mutex};

use super::invocation::RustcInvocation;
use super::pipeline::{
    handle_pipelining_full, handle_pipelining_metadata, RequestKind, WorkerStateRoots,
};
use super::protocol::WorkRequestContext;
use super::registry::RequestRegistry;
use super::sandbox::{run_request, run_sandboxed_request};
use super::types::{PipelineKey, RequestId, SandboxDir};

/// Thread-local request context. Not stored in the registry.
///
/// Created on the main thread when a work request arrives, then moved to the
/// request thread. Holds an optional reference to the `RustcInvocation` for
/// pipelined requests.
pub(super) struct BazelRequest {
    pub(super) request_id: RequestId,
    pub(super) kind: RequestKind,
    /// Shared invocation for pipelined requests. None for non-pipelined.
    pub(super) invocation: Option<Arc<RustcInvocation>>,
}

impl BazelRequest {
    pub(super) fn new(
        request_id: RequestId,
        kind: RequestKind,
        invocation: Option<Arc<RustcInvocation>>,
    ) -> Self {
        Self {
            request_id,
            kind,
            invocation,
        }
    }

    /// Execute a pipelined metadata request.
    ///
    /// CLEANUP: Currently delegates to `handle_pipelining_metadata` which uses
    /// the old `PipelineState` + `BackgroundRustc` path. Will be migrated to
    /// use `spawn_pipelined_monitor` + `invocation.wait_for_metadata()`.
    pub(super) fn execute_metadata(
        &self,
        request: &WorkRequestContext,
        full_args: Vec<String>,
        state_roots: &WorkerStateRoots,
        pipeline_state: &Arc<Mutex<super::pipeline::PipelineState>>,
    ) -> (i32, String) {
        let key = match &self.kind {
            RequestKind::Metadata { key } => key.clone(),
            _ => return (1, "execute_metadata called for non-metadata request".to_string()),
        };
        let result = handle_pipelining_metadata(request, full_args, key.clone(), state_roots, pipeline_state);
        if result.0 != 0 {
            super::lock_or_recover(pipeline_state).cleanup(&key, request.request_id);
        }
        result
    }

    /// Execute a pipelined full (codegen) request.
    ///
    /// CLEANUP: Currently delegates to `handle_pipelining_full` which uses
    /// `claim_for_full` + `BackgroundRustc` extraction. Will be migrated to
    /// use `invocation.wait_for_completion()`.
    pub(super) fn execute_full(
        &self,
        request: &WorkRequestContext,
        full_args: Vec<String>,
        pipeline_state: &Arc<Mutex<super::pipeline::PipelineState>>,
        self_path: &std::path::Path,
    ) -> (i32, String) {
        let key = match &self.kind {
            RequestKind::Full { key } => key.clone(),
            _ => return (1, "execute_full called for non-full request".to_string()),
        };
        handle_pipelining_full(request, full_args, key, pipeline_state, self_path)
    }

    /// Execute a non-pipelined multiplex request.
    ///
    /// CLEANUP: Currently delegates to the existing `Command::output()` pattern.
    /// Will be migrated to use `spawn_non_pipelined_monitor` +
    /// `invocation.wait_for_completion()` for cancellability.
    pub(super) fn execute_non_pipelined(
        &self,
        full_args: Vec<String>,
        self_path: &std::path::Path,
        sandbox_dir: Option<&str>,
    ) -> (i32, String) {
        match sandbox_dir {
            Some(dir) => run_sandboxed_request(self_path, full_args, dir)
                .unwrap_or_else(|e| (1, format!("sandboxed worker error: {e}"))),
            None => run_request(self_path, full_args)
                .unwrap_or_else(|e| (1, format!("worker thread error: {e}"))),
        }
    }
}
