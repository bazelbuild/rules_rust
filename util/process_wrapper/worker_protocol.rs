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

//! Bazel JSON worker wire-format helpers.

use tinyjson::JsonValue;

use super::types::{RequestId, SandboxDir};

#[cfg(test)]
#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) struct WorkRequestInput {
    pub(crate) path: String,
    pub(crate) digest: Option<String>,
}

/// Extracts the `requestId` field from a WorkRequest (defaults to 0).
pub(super) fn extract_request_id(request: &JsonValue) -> RequestId {
    if let JsonValue::Object(map) = request
        && let Some(JsonValue::Number(id)) = map.get("requestId")
    {
        return RequestId(*id as i64);
    }
    RequestId(0)
}

/// Extracts the `arguments` array from a WorkRequest.
pub(super) fn extract_arguments(request: &JsonValue) -> Vec<String> {
    if let JsonValue::Object(map) = request
        && let Some(JsonValue::Array(args)) = map.get("arguments")
    {
        return args
            .iter()
            .filter_map(|v| {
                if let JsonValue::String(s) = v {
                    Some(s.clone())
                } else {
                    None
                }
            })
            .collect();
    }
    vec![]
}

/// Extracts `sandboxDir` and rejects unusable sandbox directories.
///
/// An unusable directory usually means multiplex sandboxing is enabled on a
/// platform without sandbox support.
pub(super) fn extract_sandbox_dir(request: &JsonValue) -> Result<Option<SandboxDir>, String> {
    if let JsonValue::Object(map) = request
        && let Some(JsonValue::String(dir)) = map.get("sandboxDir")
    {
        if dir.is_empty() {
            return Ok(None);
        }
        if std::fs::read_dir(dir).is_ok_and(|mut entries| entries.next().is_some()) {
            return Ok(Some(SandboxDir(dir.clone())));
        }
        return Err(format!(
            "Bazel sent sandboxDir=\"{}\" but the directory {}. \
             This typically means --experimental_worker_multiplex_sandboxing is enabled \
             on a platform without sandbox support (e.g. Windows). \
             Remove this flag or make it platform-specific \
             (e.g. build:linux --experimental_worker_multiplex_sandboxing).",
            dir,
            if std::path::Path::new(dir).exists() {
                "is empty (no symlinks to execroot)"
            } else {
                "does not exist"
            },
        ));
    }
    Ok(None)
}

#[cfg(test)]
/// Extracts the `inputs` array from a WorkRequest.
pub(super) fn extract_inputs(request: &JsonValue) -> Vec<WorkRequestInput> {
    let mut result = Vec::new();
    let JsonValue::Object(map) = request else {
        return result;
    };
    let Some(JsonValue::Array(inputs)) = map.get("inputs") else {
        return result;
    };

    for input in inputs {
        let JsonValue::Object(obj) = input else {
            continue;
        };

        let Some(JsonValue::String(path)) = obj.get("path") else {
            continue;
        };
        let digest = obj.get("digest").and_then(|v| match v {
            JsonValue::String(d) => Some(d.clone()),
            _ => None,
        });
        result.push(WorkRequestInput {
            path: path.clone(),
            digest,
        });
    }

    result
}

/// Extracts the `cancel` field from a WorkRequest (false if absent).
pub(super) fn extract_cancel(request: &JsonValue) -> bool {
    if let JsonValue::Object(map) = request
        && let Some(JsonValue::Boolean(cancel)) = map.get("cancel")
    {
        return *cancel;
    }
    false
}

/// Builds a JSON WorkResponse string.
pub(super) fn build_response(exit_code: i32, output: &str, request_id: RequestId) -> String {
    let output: String = output
        .chars()
        .map(|ch| match ch {
            '\n' | '\r' | '\t' => ch,
            ch if ch.is_control() => ' ',
            ch => ch,
        })
        .collect();
    format!(
        "{{\"exitCode\":{},\"output\":{},\"requestId\":{}}}",
        exit_code,
        json_string_literal(&output),
        request_id.0
    )
}

/// Builds a JSON WorkResponse with `wasCancelled: true`.
pub(super) fn build_cancel_response(request_id: RequestId) -> String {
    format!(
        "{{\"exitCode\":0,\"output\":{},\"requestId\":{},\"wasCancelled\":true}}",
        json_string_literal(""),
        request_id.0
    )
}

pub(super) fn json_string_literal(value: &str) -> String {
    JsonValue::String(value.to_owned())
        .stringify()
        .unwrap_or_else(|_| "\"\"".to_string())
}
