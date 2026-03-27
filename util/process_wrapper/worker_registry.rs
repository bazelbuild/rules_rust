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
//! `RequestRegistry` replaces the old `PipelineState` as the single owner of
//! invocation lifecycles, claim flags, and request-to-pipeline mappings. It is
//! wrapped in `Arc<Mutex<..>>` (`SharedRequestRegistry`) for thread-safe access
//! from the reader thread, request threads, and signal handlers.

use std::collections::HashMap;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::thread;

use super::invocation::RustcInvocation;
use super::types::{PipelineKey, RequestId};

/// Thread-safe shared handle to the `RequestRegistry`.
pub(crate) type SharedRequestRegistry = Arc<Mutex<RequestRegistry>>;

/// Central owner of all invocations and request metadata.
pub(crate) struct RequestRegistry {
    /// Pipeline key -> shared invocation.
    invocations: HashMap<PipelineKey, Arc<RustcInvocation>>,
    /// Monitor thread handles for join during shutdown.
    monitors: Vec<thread::JoinHandle<()>>,
    /// request_id -> pipeline key (pipelined requests, for O(1) cancel lookup).
    request_index: HashMap<RequestId, PipelineKey>,
    /// Claim flags for ALL in-flight requests (cancel/completion race prevention).
    claim_flags: HashMap<RequestId, Arc<AtomicBool>>,
}

impl RequestRegistry {
    pub fn new() -> Self {
        RequestRegistry {
            invocations: HashMap::new(),
            monitors: Vec::new(),
            request_index: HashMap::new(),
            claim_flags: HashMap::new(),
        }
    }

    /// Register a metadata request. Creates the invocation if it doesn't exist.
    /// Returns the claim flag and the shared invocation.
    pub fn register_metadata(
        &mut self,
        request_id: RequestId,
        key: PipelineKey,
    ) -> (Arc<AtomicBool>, Arc<RustcInvocation>) {
        let claim = Arc::new(AtomicBool::new(false));
        self.claim_flags.insert(request_id, Arc::clone(&claim));
        self.request_index.insert(request_id, key.clone());

        let inv = self
            .invocations
            .entry(key)
            .or_insert_with(|| Arc::new(RustcInvocation::new()));

        (claim, Arc::clone(inv))
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

    /// Store an invocation and its monitor thread handle.
    pub fn store_invocation(
        &mut self,
        key: PipelineKey,
        invocation: Arc<RustcInvocation>,
        monitor: thread::JoinHandle<()>,
    ) {
        self.invocations.insert(key, invocation);
        self.monitors.push(monitor);
    }

    /// Store a monitor thread handle only (for non-pipelined requests).
    pub fn store_monitor(&mut self, monitor: thread::JoinHandle<()>) {
        self.monitors.push(monitor);
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

    /// Shut down all invocations and join all monitor threads.
    pub fn shutdown_all(&mut self) {
        for inv in self.invocations.values() {
            inv.request_shutdown();
        }
        for handle in self.monitors.drain(..) {
            let _ = handle.join();
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
