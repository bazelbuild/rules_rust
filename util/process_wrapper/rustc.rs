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

use tinyjson::JsonValue;

use crate::output::LineOutput;

#[derive(Debug, Copy, Clone)]
pub(crate) enum ErrorFormat {
    Json,
    Rendered,
}

impl Default for ErrorFormat {
    fn default() -> Self {
        Self::Rendered
    }
}

fn get_key(value: &JsonValue, key: &str) -> Option<String> {
    if let JsonValue::Object(map) = value {
        if let JsonValue::String(s) = map.get(key)? {
            Some(s.clone())
        } else {
            None
        }
    } else {
        None
    }
}

/// stop_on_rmeta_completion takes an output line from rustc configured with
/// --error-format=json, parses the json and returns the appropriate output
/// according to the original --error-format supplied to rustc.
/// In addition, it will signal to stop when metadata is emitted
/// so the compiler can be terminated.
/// This is used to implement pipelining in rules_rust, please see
/// https://internals.rust-lang.org/t/evaluating-pipelined-rustc-compilation/10199
pub(crate) fn stop_on_rmeta_completion(
    line: String,
    error_format: ErrorFormat,
    kill: &mut bool,
) -> LineOutput {
    let parsed: JsonValue = line
        .parse()
        .expect("process wrapper error: expected json messages in pipeline mode");
    if let Some(emit) = get_key(&parsed, "emit") {
        // We don't want to print emit messages.
        // If the emit messages is "metadata" we can signal the process to quit
        return if emit == "metadata" {
            *kill = true;
            LineOutput::Terminate
        } else {
            LineOutput::Skip
        };
    };

    match error_format {
        // If the output should be json, we just forward the messages as-is
        ErrorFormat::Json => LineOutput::Message(line),
        // Otherwise we extract the "rendered" attribute.
        // If we don't find it we skip the line.
        _ => get_key(&parsed, "rendered")
            .map(LineOutput::Message)
            .unwrap_or(LineOutput::Skip),
    }
}
