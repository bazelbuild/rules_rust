use crate::output::LineOutput;

use super::*;
use tinyjson::JsonValue;

fn parse_json(json_str: &str) -> Result<JsonValue, String> {
    json_str.parse::<JsonValue>().map_err(|e| e.to_string())
}

#[test]
fn test_stderr_policy_normalizes_llvm_warning_in_json_mode() -> Result<(), String> {
    let mut policy = RustcStderrPolicy::new(Some(ErrorFormat::Json));
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
    let mut policy = RustcStderrPolicy::new(Some(ErrorFormat::Rendered));
    let malformed = "{\"rendered\":\"unterminated\"\n";
    let valid = "{\"$message_type\":\"diagnostic\",\"rendered\":\"Diagnostic message\"}\n";

    assert_eq!(policy.process_line(malformed), Some(malformed.to_string()));
    assert_eq!(policy.process_line(valid), Some(valid.to_string()));
}

#[test]
fn test_process_stderr_line_keeps_rendered_messages_structured() -> Result<(), String> {
    let LineOutput::Message(message) = process_stderr_line(
        r#"{"$message_type":"diagnostic","rendered":"Diagnostic message"}"#.to_string(),
        ErrorFormat::Rendered,
    )?
    else {
        return Err("Expected rendered diagnostic output".to_string());
    };

    assert_eq!(message, "Diagnostic message");
    Ok(())
}
