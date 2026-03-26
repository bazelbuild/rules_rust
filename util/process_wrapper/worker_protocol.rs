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

//! JSON worker protocol types and helpers.

use tinyjson::JsonValue;

#[derive(Clone, Debug, PartialEq, Eq)]
pub(super) struct WorkRequestInput {
    pub(super) path: String,
    pub(super) digest: Option<String>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub(super) struct WorkRequestContext {
    pub(super) request_id: i64,
    pub(super) arguments: Vec<String>,
    pub(super) sandbox_dir: Option<String>,
    pub(super) inputs: Vec<WorkRequestInput>,
    pub(super) cancel: bool,
}

impl WorkRequestContext {
    pub(super) fn from_json(request: &JsonValue) -> Result<Self, String> {
        Ok(Self {
            request_id: extract_request_id(request),
            arguments: extract_arguments(request),
            sandbox_dir: extract_sandbox_dir(request)?,
            inputs: extract_inputs(request),
            cancel: extract_cancel(request),
        })
    }
}

pub(super) fn extract_request_id_from_raw_line(line: &str) -> Option<i64> {
    let key_pos = line.find("\"requestId\"")?;
    let after_key = &line[key_pos + "\"requestId\"".len()..];
    let colon = after_key.find(':')?;
    let after_colon = after_key[colon + 1..].trim_start();
    let digits: String = after_colon
        .chars()
        .take_while(|ch| ch.is_ascii_digit())
        .collect();
    if digits.is_empty() {
        None
    } else {
        digits.parse().ok()
    }
}

/// Extracts the `requestId` field from a WorkRequest (defaults to 0).
pub(super) fn extract_request_id(request: &JsonValue) -> i64 {
    if let JsonValue::Object(map) = request {
        if let Some(JsonValue::Number(id)) = map.get("requestId") {
            return *id as i64;
        }
    }
    0
}

/// Extracts the `arguments` array from a WorkRequest.
pub(super) fn extract_arguments(request: &JsonValue) -> Vec<String> {
    if let JsonValue::Object(map) = request {
        if let Some(JsonValue::Array(args)) = map.get("arguments") {
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
    }
    vec![]
}

/// Extracts the `sandboxDir` field from a WorkRequest.
///
/// Returns `Ok(Some(dir))` if a usable sandbox directory is provided,
/// `Ok(None)` if the field is absent, or `Err` if a `sandboxDir` was provided
/// but the directory does not exist or is empty (unpopulated).
///
/// The error case indicates a misconfiguration: `--experimental_worker_multiplex_sandboxing`
/// is enabled but the platform has no sandbox support (e.g. Windows). Rather than
/// silently falling back — which would cause subtle pipelining failures when
/// rustc's CWD is set to an empty sandbox — we surface a clear error directing
/// the user to fix their Bazel configuration.
pub(super) fn extract_sandbox_dir(request: &JsonValue) -> Result<Option<String>, String> {
    if let JsonValue::Object(map) = request {
        if let Some(JsonValue::String(dir)) = map.get("sandboxDir") {
            if dir.is_empty() {
                return Ok(None);
            }
            if sandbox_dir_is_usable(dir) {
                return Ok(Some(dir.clone()));
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
    }
    Ok(None)
}

/// A sandbox directory is usable if it exists and contains at least one entry.
///
/// On platforms with real sandbox support (Linux), Bazel populates the directory
/// with symlinks into the real execroot before sending the WorkRequest. On
/// Windows, the directory may be created but left empty because there is no
/// sandboxing implementation — an empty directory is not a usable sandbox.
fn sandbox_dir_is_usable(dir: &str) -> bool {
    match std::fs::read_dir(dir) {
        Ok(mut entries) => entries.next().is_some(),
        Err(_) => false,
    }
}

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

        let path = obj.get("path").and_then(|value| match value {
            JsonValue::String(path) => Some(path.clone()),
            _ => None,
        });
        let digest = obj.get("digest").and_then(|value| match value {
            JsonValue::String(digest) => Some(digest.clone()),
            _ => None,
        });

        if let Some(path) = path {
            result.push(WorkRequestInput { path, digest });
        }
    }

    result
}

/// Extracts the `cancel` field from a WorkRequest (false if absent).
pub(super) fn extract_cancel(request: &JsonValue) -> bool {
    if let JsonValue::Object(map) = request {
        if let Some(JsonValue::Boolean(cancel)) = map.get("cancel") {
            return *cancel;
        }
    }
    false
}

/// Builds a JSON WorkResponse string.
pub(super) fn build_response(exit_code: i32, output: &str, request_id: i64) -> String {
    let output = sanitize_response_output(output);
    format!(
        "{{\"exitCode\":{},\"output\":{},\"requestId\":{}}}",
        exit_code,
        json_string_literal(&output),
        request_id
    )
}

/// Builds a JSON WorkResponse with `wasCancelled: true`.
pub(super) fn build_cancel_response(request_id: i64) -> String {
    format!(
        "{{\"exitCode\":0,\"output\":{},\"requestId\":{},\"wasCancelled\":true}}",
        json_string_literal(""),
        request_id
    )
}

pub(super) fn build_shutdown_response(request_id: i64) -> String {
    build_response(1, "worker shutting down", request_id)
}

pub(super) fn sanitize_response_output(output: &str) -> String {
    output
        .chars()
        .map(|ch| match ch {
            '\n' | '\r' | '\t' => ch,
            ch if ch.is_control() => ' ',
            ch => ch,
        })
        .collect()
}

pub(super) fn json_string_literal(value: &str) -> String {
    JsonValue::String(value.to_owned())
        .stringify()
        .unwrap_or_else(|_| "\"\"".to_string())
}
