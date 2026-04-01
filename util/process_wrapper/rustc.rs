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

use std::collections::HashMap;

use tinyjson::JsonValue;

use crate::output::{LineOutput, LineResult};

#[derive(Debug, Default, Copy, Clone)]
pub(crate) enum ErrorFormat {
    Json,
    #[default]
    Rendered,
}

pub(crate) fn error_format_from_str(value: &str) -> Option<ErrorFormat> {
    match value {
        "json" => Some(ErrorFormat::Json),
        "rendered" => Some(ErrorFormat::Rendered),
        _ => None,
    }
}

#[derive(Debug, Clone)]
pub(crate) struct RustcStderrProcessor {
    error_format: ErrorFormat,
    raw_passthrough: bool,
}

impl RustcStderrProcessor {
    pub(crate) fn new(error_format: ErrorFormat) -> Self {
        Self {
            error_format,
            raw_passthrough: false,
        }
    }

    pub(crate) fn process_line(&mut self, line: &str) -> Option<String> {
        if self.raw_passthrough {
            return Some(line.to_owned());
        }

        match process_stderr_line(line.to_owned(), self.error_format) {
            Ok(LineOutput::Message(msg)) => Some(msg),
            Ok(LineOutput::Skip) => None,
            Err(_) => {
                self.raw_passthrough = true;
                Some(line.to_owned())
            }
        }
    }
}

#[derive(Debug, Clone)]
pub(crate) enum RustcStderrPolicy {
    Raw,
    Processed(RustcStderrProcessor),
}

impl RustcStderrPolicy {
    #[cfg(test)]
    pub(crate) fn new(error_format: Option<ErrorFormat>) -> Self {
        match error_format {
            Some(format) => Self::Processed(RustcStderrProcessor::new(format)),
            None => Self::Raw,
        }
    }

    pub(crate) fn from_option_str(error_format: Option<&str>) -> Self {
        match error_format {
            Some(value) => Self::Processed(RustcStderrProcessor::new(
                error_format_from_str(value).unwrap_or(ErrorFormat::Rendered),
            )),
            None => Self::Raw,
        }
    }

    pub(crate) fn process_line(&mut self, line: &str) -> Option<String> {
        match self {
            Self::Raw => Some(line.to_owned()),
            Self::Processed(processor) => processor.process_line(line),
        }
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

pub(crate) fn process_stderr_line(mut line: String, error_format: ErrorFormat) -> LineResult {
    if line.contains("is not a recognized feature for this target (ignoring feature)")
        || line.starts_with(" WARN ")
    {
        if let Ok(json_str) = json_warning(&line).stringify() {
            line = json_str;
        } else {
            return Ok(LineOutput::Skip);
        }
    }
    process_json(line, error_format)
}

/// process_rustc_json takes an output line from rustc configured with
/// --error-format=json, parses the json and returns the appropriate output
/// according to the original --error-format supplied.
/// Only diagnostics with a rendered message are returned.
/// Returns an errors if parsing json fails.
pub(crate) fn process_json(line: String, error_format: ErrorFormat) -> LineResult {
    let parsed: JsonValue = line
        .parse()
        .map_err(|_| "error parsing rustc output as json".to_owned())?;
    Ok(if let Some(rendered) = get_key(&parsed, "rendered") {
        output_based_on_error_format(line, rendered, error_format)
    } else {
        // Ignore non-diagnostic messages such as artifact notifications.
        LineOutput::Skip
    })
}

fn output_based_on_error_format(
    line: String,
    rendered: String,
    error_format: ErrorFormat,
) -> LineOutput {
    match error_format {
        // If the output should be json, we just forward the messages as-is
        // using `line`.
        ErrorFormat::Json => LineOutput::Message(line),
        // Otherwise we return the rendered field.
        ErrorFormat::Rendered => LineOutput::Message(rendered),
    }
}

/// Extracts the artifact path from an rmeta artifact notification JSON line.
/// Returns `Some(path)` for `{"artifact":"path/to/lib.rmeta","emit":"metadata"}`,
/// `None` for all other lines.
pub(crate) fn extract_rmeta_path(line: &str) -> Option<String> {
    if let Ok(JsonValue::Object(ref map)) = line.parse::<JsonValue>()
        && let Some(JsonValue::String(artifact)) = map.get("artifact")
        && let Some(JsonValue::String(emit)) = map.get("emit")
        && artifact.ends_with(".rmeta")
        && emit == "metadata"
    {
        Some(artifact.clone())
    } else {
        None
    }
}

#[cfg(test)]
#[path = "test/rustc.rs"]
mod test;
