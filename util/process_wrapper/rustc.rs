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
    pub(crate) fn from_option_str(error_format: Option<&str>) -> Self {
        match error_format {
            Some(value) => Self::Processed(RustcStderrProcessor::new(match value {
                "json" => ErrorFormat::Json,
                _ => ErrorFormat::Rendered,
            })),
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

pub(crate) fn process_stderr_line(line: String, error_format: ErrorFormat) -> LineResult {
    if line.contains("is not a recognized feature for this target (ignoring feature)")
        || line.starts_with(" WARN ")
    {
        return match error_format {
            ErrorFormat::Rendered => Ok(LineOutput::Message(line)),
            ErrorFormat::Json => {
                let warning = JsonValue::Object(HashMap::from([
                    (
                        "$message_type".to_string(),
                        JsonValue::String("diagnostic".to_string()),
                    ),
                    ("message".to_string(), JsonValue::String(line.clone())),
                    ("code".to_string(), JsonValue::Null),
                    (
                        "level".to_string(),
                        JsonValue::String("warning".to_string()),
                    ),
                    ("spans".to_string(), JsonValue::Array(Vec::new())),
                    ("children".to_string(), JsonValue::Array(Vec::new())),
                    ("rendered".to_string(), JsonValue::String(line)),
                ]));
                match warning.stringify() {
                    Ok(json_str) => Ok(LineOutput::Message(json_str)),
                    Err(_) => Ok(LineOutput::Skip),
                }
            }
        };
    }
    let parsed: JsonValue = line
        .parse()
        .map_err(|_| "error parsing rustc output as json".to_owned())?;
    let rendered = if let JsonValue::Object(map) = &parsed
        && let Some(JsonValue::String(s)) = map.get("rendered")
    {
        Some(s.clone())
    } else {
        None
    };
    Ok(match rendered {
        Some(rendered) => match error_format {
            ErrorFormat::Json => LineOutput::Message(line),
            ErrorFormat::Rendered => LineOutput::Message(rendered),
        },
        // Ignore non-diagnostic messages such as artifact notifications.
        None => LineOutput::Skip,
    })
}

/// Extracts `.rmeta` artifact paths from rustc JSON notifications.
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
