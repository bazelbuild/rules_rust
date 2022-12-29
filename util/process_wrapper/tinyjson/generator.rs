use super::JsonValue;
use std::collections::HashMap;
use std::error;
use std::fmt;

#[derive(Debug)]
pub struct JsonGenerateError {
    msg: &'static str,
}

impl JsonGenerateError {
    fn new(msg: &'static str) -> Self {
        JsonGenerateError { msg }
    }

    pub fn message(&self) -> &str {
        self.msg
    }
}

impl fmt::Display for JsonGenerateError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "Generate error: {}", &self.msg)
    }
}

impl error::Error for JsonGenerateError {}

pub type JsonGenerateResult = Result<String, JsonGenerateError>;

fn quote(s: &str) -> String {
    let mut to = '"'.to_string();
    for c in s.chars() {
        match c {
            '\\' => to.push_str("\\\\"),
            '\u{0008}' => to.push_str("\\b"),
            '\u{000c}' => to.push_str("\\f"),
            '\n' => to.push_str("\\n"),
            '\r' => to.push_str("\\r"),
            '\t' => to.push_str("\\t"),
            '"' => to.push_str("\\\""),
            c if c.is_control() => to.push_str(&format!("\\u{:04x}", c as u32)),
            c => to.push(c),
        }
    }
    to.push('"');
    to
}

fn array(array: &[JsonValue]) -> JsonGenerateResult {
    let mut to = '['.to_string();
    for elem in array.iter() {
        let s = stringify(elem)?;
        to += &s;
        to.push(',');
    }
    if !array.is_empty() {
        to.pop(); // Remove trailing comma
    }
    to.push(']');
    Ok(to)
}

fn object(m: &HashMap<String, JsonValue>) -> JsonGenerateResult {
    let mut to = '{'.to_string();
    for (k, v) in m {
        to += &quote(k);
        to.push(':');
        let s = stringify(v)?;
        to += &s;
        to.push(',');
    }
    if !m.is_empty() {
        to.pop(); // Remove trailing comma
    }
    to.push('}');
    Ok(to)
}

fn number(f: f64) -> JsonGenerateResult {
    if f.is_infinite() {
        Err(JsonGenerateError::new("JSON cannot represent inf"))
    } else if f.is_nan() {
        Err(JsonGenerateError::new("JSON cannot represent NaN"))
    } else {
        Ok(f.to_string())
    }
}

pub fn stringify(value: &JsonValue) -> JsonGenerateResult {
    match value {
        JsonValue::Number(n) => number(*n),
        JsonValue::Boolean(b) => Ok(b.to_string()),
        JsonValue::String(s) => Ok(quote(s)),
        JsonValue::Null => Ok("null".to_string()),
        JsonValue::Array(a) => array(a),
        JsonValue::Object(o) => object(o),
    }
}
