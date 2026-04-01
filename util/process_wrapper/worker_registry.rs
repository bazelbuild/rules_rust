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
//! Response arbitration (cancel vs. completion) is handled by the `requests`
//! map: whoever removes a request ID from the map under the lock owns the
//! right to send the `WorkResponse`. No separate claim flags are needed.

use std::collections::HashMap;
use std::sync::{Arc, Mutex};

use super::invocation::RustcInvocation;
use super::types::{PipelineKey, RequestId};

/// Thread-safe shared handle to the `RequestCoordinator`.
pub(crate) type SharedRequestCoordinator = Arc<Mutex<RequestCoordinator>>;

/// Shared state for request threads and rustc threads.
#[derive(Default)]
pub(crate) struct RequestCoordinator {
    /// Pipeline key -> shared invocation.
    pub invocations: HashMap<PipelineKey, Arc<RustcInvocation>>,
    /// All in-flight requests. Value is `Some(key)` for pipelined requests,
    /// `None` for non-pipelined. Presence in this map means the request is
    /// active and no response has been sent yet. Removal IS the atomic claim —
    /// whoever removes the entry owns the right to send the `WorkResponse`.
    pub requests: HashMap<RequestId, Option<PipelineKey>>,
}

impl RequestCoordinator {
    /// Cancels a request and shuts down the associated invocation.
    /// Returns `true` if the cancel was claimed (caller should send the cancel
    /// response), `false` if the request already completed.
    pub fn cancel(&mut self, request_id: RequestId) -> bool {
        if let Some(maybe_key) = self.requests.remove(&request_id) {
            if let Some(key) = maybe_key {
                if let Some(inv) = self.invocations.get(&key) {
                    inv.request_shutdown();
                }
            }
            true
        } else {
            false
        }
    }

    /// Requests shutdown for all tracked invocations and clears the registry.
    pub fn shutdown_all(&mut self) {
        for inv in self.invocations.values() {
            inv.request_shutdown();
        }
        self.invocations.clear();
        self.requests.clear();
    }
}
