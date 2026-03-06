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

use crate::output::{LineOutput, LineResult};

#[derive(Debug, Default, Copy, Clone)]
pub(crate) enum ErrorFormat {
    Json,
    #[default]
    Rendered,
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
