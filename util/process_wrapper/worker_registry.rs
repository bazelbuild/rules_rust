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

//! Central registry of all in-flight requests and shared invocations.
//!
//! `RequestCoordinator` replaces the old `PipelineState` as the single owner of
//! invocation lifecycles, claim flags, and request-to-pipeline mappings. It is
//! wrapped in `Arc<Mutex<..>>` (`SharedRequestCoordinator`) for thread-safe access
//! from the reader thread, request threads, and signal handlers.

use std::collections::HashMap;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};

use super::invocation::RustcInvocation;
use super::types::{PipelineKey, RequestId};

/// Thread-safe shared handle to the `RequestCoordinator`.
pub(crate) type SharedRequestCoordinator = Arc<Mutex<RequestCoordinator>>;

/// Central owner of all invocations and request metadata.
///
/// Thread handles (both request threads and rustc threads) are detached at
/// spawn rather than stored here. Bazel shuts down workers via SIGTERM with no
/// drain phase, so there is no opportunity to join threads gracefully — process
/// exit is the only cleanup that matters. This avoids unbounded `JoinHandle`
/// accumulation in long-lived workers that persist across many builds.
#[derive(Default)]
pub(crate) struct RequestCoordinator {
    /// Pipeline key -> shared invocation.
    invocations: HashMap<PipelineKey, Arc<RustcInvocation>>,
    /// request_id -> pipeline key (pipelined requests, for O(1) cancel lookup).
    request_index: HashMap<RequestId, PipelineKey>,
    /// Claim flags for ALL in-flight requests (cancel/completion race prevention).
    claim_flags: HashMap<RequestId, Arc<AtomicBool>>,
}

impl RequestCoordinator {
    /// Register a metadata request. Records the key mapping and claim flag.
    /// The invocation is NOT created here — it is created by
    /// `spawn_pipelined_rustc` and inserted via `insert_invocation` after
    /// rustc is successfully spawned. This ensures no invocation exists in
    /// the registry unless rustc is actually running, preventing deadlocks
    /// where a full request waits on a Pending invocation that will never
    /// transition.
    pub fn register_metadata(
        &mut self,
        request_id: RequestId,
        key: PipelineKey,
    ) -> Arc<AtomicBool> {
        let claim = Arc::new(AtomicBool::new(false));
        self.claim_flags.insert(request_id, Arc::clone(&claim));
        self.request_index.insert(request_id, key);
        claim
    }

    /// Insert an invocation into the registry after rustc has been spawned.
    pub fn insert_invocation(&mut self, key: PipelineKey, inv: Arc<RustcInvocation>) {
        self.invocations.insert(key, inv);
    }

    /// Look up an invocation by key (e.g. for shutdown on panic).
    pub fn get_invocation(&self, key: &PipelineKey) -> Option<Arc<RustcInvocation>> {
        self.invocations.get(key).map(Arc::clone)
    }

    /// Register a full (codegen) request. Returns the existing invocation if
    /// one was created by a prior metadata request, or `None` if no invocation
    /// exists yet (the full request will need to spawn its own).
    pub fn register_full(
        &mut self,
        request_id: RequestId,
        key: PipelineKey,
    ) -> (Arc<AtomicBool>, Option<Arc<RustcInvocation>>) {
        let claim = Arc::new(AtomicBool::new(false));
        self.claim_flags.insert(request_id, Arc::clone(&claim));
        self.request_index.insert(request_id, key.clone());

        let inv = self.invocations.get(&key).map(Arc::clone);
        (claim, inv)
    }

    /// Register a non-pipelined request. Only creates a claim flag (no
    /// invocation or pipeline key mapping).
    pub fn register_non_pipelined(&mut self, request_id: RequestId) -> Arc<AtomicBool> {
        let claim = Arc::new(AtomicBool::new(false));
        self.claim_flags.insert(request_id, Arc::clone(&claim));
        claim
    }

    /// Cancel a request: swap its claim flag, shut down the associated
    /// invocation (if pipelined), and remove request mappings.
    pub fn cancel(&mut self, request_id: RequestId) {
        // Swap claim flag to prevent the request thread from sending a response.
        if let Some(flag) = self.claim_flags.get(&request_id) {
            flag.store(true, Ordering::SeqCst);
        }

        // If this is a pipelined request, shut down the invocation.
        if let Some(key) = self.request_index.get(&request_id) {
            if let Some(inv) = self.invocations.get(key) {
                inv.request_shutdown();
            }
        }

        // Clean up request-level mappings (but NOT the invocation itself).
        self.request_index.remove(&request_id);
        self.claim_flags.remove(&request_id);
    }

    /// Shut down all invocations. Rustc threads are detached and will
    /// exit when their rustc process terminates (via SIGTERM from
    /// `request_shutdown`). Process exit handles final cleanup.
    pub fn shutdown_all(&mut self) {
        for inv in self.invocations.values() {
            inv.request_shutdown();
        }
        self.invocations.clear();
        self.request_index.clear();
        self.claim_flags.clear();
    }

    /// Remove request-level mappings (request_index + claim_flags) but NOT
    /// the invocation. Called when a request completes normally.
    pub fn remove_request(&mut self, request_id: RequestId) {
        self.request_index.remove(&request_id);
        self.claim_flags.remove(&request_id);
    }

    /// Remove an invocation from the map. Called when both metadata and full
    /// requests for a pipeline key have completed.
    pub fn remove_invocation(&mut self, key: &PipelineKey) {
        self.invocations.remove(key);
    }

    /// Get the claim flag for a request, if it exists.
    pub fn get_claim_flag(&self, request_id: RequestId) -> Option<Arc<AtomicBool>> {
        self.claim_flags.get(&request_id).map(Arc::clone)
    }

    /// Test helper: check whether an invocation exists for the given key.
    #[cfg(test)]
    pub fn has_invocation(&self, key: &str) -> bool {
        self.invocations
            .contains_key(&PipelineKey(key.to_string()))
    }
}
