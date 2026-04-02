use crate::output::LineOutput;

use super::*;
use tinyjson::JsonValue;

fn parse_json(json_str: &str) -> Result<JsonValue, String> {
    json_str.parse::<JsonValue>().map_err(|e| e.to_string())
}

#[test]
fn test_stderr_policy_normalizes_llvm_warning_in_json_mode() -> Result<(), String> {
    let mut policy = RustcStderrPolicy::from_option_str(Some("json"));
    let text = " WARN rustc_errors::emitter Invalid span...";
    let Some(message) = policy.process_line(text) else {
        return Err("Expected a processed warning message".to_string());
    };

    assert_eq!(
        parse_json(&message)?,
        parse_json(&format!(
            r#"{{
                "$message_type": "diagnostic",
                "message": "{0}",
                "code": null,
                "level": "warning",
                "spans": [],
                "children": [],
                "rendered": "{0}"
            }}"#,
            text
        ))?
    );
    Ok(())
}

#[test]
fn test_stderr_policy_switches_to_raw_passthrough_after_parse_failure() {
    let mut policy = RustcStderrPolicy::from_option_str(Some("rendered"));
    let malformed = "{\"rendered\":\"unterminated\"\n";
    let valid = "{\"$message_type\":\"diagnostic\",\"rendered\":\"Diagnostic message\"}\n";

    assert_eq!(policy.process_line(malformed), Some(malformed.to_string()));
    assert_eq!(policy.process_line(valid), Some(valid.to_string()));
}

/// Table-driven test covering all `process_stderr_line` branches:
/// rendered diagnostic, JSON diagnostic, warning normalization, and artifact skip.
#[test]
fn test_process_stderr_line_table() -> Result<(), String> {
    // (input, format, expected output)
    let diagnostic_json = r#"{"$message_type":"diagnostic","rendered":"Diagnostic message"}"#;

    // JSON mode: returns the full JSON unchanged.
    let LineOutput::Message(msg) =
        process_stderr_line(diagnostic_json.to_string(), ErrorFormat::Json)?
    else {
        return Err("expected Message for diagnostic in JSON mode".to_string());
    };
    assert_eq!(parse_json(&msg)?, parse_json(diagnostic_json)?);

    // Rendered mode: extracts the "rendered" field.
    let LineOutput::Message(msg) =
        process_stderr_line(diagnostic_json.to_string(), ErrorFormat::Rendered)?
    else {
        return Err("expected Message for diagnostic in Rendered mode".to_string());
    };
    assert_eq!(msg, "Diagnostic message");

    // Noise lines are normalized to JSON diagnostics.
    for text in [
        "'+zaamo' is not a recognized feature for this target (ignoring feature)",
        " WARN rustc_errors::emitter Invalid span...",
    ] {
        let LineOutput::Message(msg) =
            process_stderr_line(text.to_string(), ErrorFormat::Json)?
        else {
            return Err(format!("expected Message for noise line: {text}"));
        };
        assert_eq!(
            parse_json(&msg)?,
            parse_json(&format!(
                r#"{{"$message_type":"diagnostic","message":"{0}","code":null,"level":"warning","spans":[],"children":[],"rendered":"{0}"}}"#,
                text
            ))?
        );
    }

    // Artifact lines are skipped.
    for emit in ["link", "metadata"] {
        let json = format!(r#"{{"$message_type":"artifact","emit":"{emit}"}}"#);
        assert!(
            matches!(
                process_stderr_line(json, ErrorFormat::Rendered)?,
                LineOutput::Skip
            ),
            "artifact emit={emit} should be skipped"
        );
    }

    Ok(())
}
