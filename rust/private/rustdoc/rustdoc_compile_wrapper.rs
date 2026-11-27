//! Wrapper around the `rustdoc --test --no-run --persist-doctests` invocation
//! used by `rust_doc_test` when the `experimental_compile_rustdoc_tests` flag
//! is enabled.
//!
//! Doc test compilation is split into a build-time compile action (this
//! wrapper) and a test-time execute action (`rustdoc_test_runner`). At
//! compile time rustdoc both (a) writes one `rust_out` binary per doc test
//! into a `--persist-doctests` directory and (b) prints a `test ... ` line
//! per test to stdout. The runner only sees the persisted directory tree, so
//! it cannot recover the human-readable test names on its own.
//!
//! This wrapper bridges that gap: it spawns rustdoc, captures stdout, and
//! writes a `<mangled-dir-name>=<human-name>` metadata file that the runner
//! consults to label each persisted binary. It also suppresses rustdoc's
//! stdout on clean runs (to keep `bazel test` output tidy) while still
//! surfacing it whenever the compile fails or emits warnings.
//!
//! Persisted binaries carry no record of the doctest attributes rustdoc
//! would have applied when running them itself: `should_panic` inverts the
//! exit code check and `no_run` skips execution entirely (rustdoc still
//! compiles `no_run` tests fully when persisting). The `--doctests` option
//! takes the JSON produced by `rustdoc --output-format=doctest` for the same
//! crate and records those attributes next to each name, separated by tabs.

use std::collections::{BTreeSet, HashMap};
use std::env;
use std::fs;
use std::io::{self, BufRead, Read, Write};
use std::process::{exit, Command, Stdio};
use std::thread;

/// Parsed command-line for this wrapper.
struct WrapperArgs {
    /// Where to write the `<mangled>=<human>` test-name metadata, or `None`
    /// if `--test-metadata` was not passed (in which case stdout is not
    /// parsed for test names).
    test_metadata_path: Option<String>,
    /// The `rustdoc --output-format=doctest` JSON describing the crate's
    /// doctests, or `None` if `--doctests` was not passed.
    doctests_path: Option<String>,
    /// The rustdoc command and its arguments, everything that appeared
    /// after the `--` separator.
    child_args: Vec<String>,
}

impl WrapperArgs {
    /// Parse command line arguments.
    fn parse() -> Self {
        let mut test_metadata_path: Option<String> = None;
        let mut doctests_path: Option<String> = None;
        let mut child_args: Vec<String> = Vec::new();
        let mut past_separator = false;

        let mut args_iter = env::args().skip(1);
        while let Some(arg) = args_iter.next() {
            if past_separator {
                child_args.push(arg);
            } else if arg == "--" {
                past_separator = true;
            } else if arg == "--test-metadata" {
                test_metadata_path = args_iter.next();
            } else if arg == "--doctests" {
                doctests_path = args_iter.next();
            } else {
                eprintln!("Unknown wrapper flag: {}", arg);
                exit(1);
            }
        }

        Self {
            test_metadata_path,
            doctests_path,
            child_args,
        }
    }
}

/// The pieces of a human-readable doctest name.
///
/// rustdoc names doctests `<file> - <item> (line <n>)`, or `<file> - (line
/// <n>)` for crate level doctests that have no item. When rustdoc runs the
/// tests itself it appends ` - should panic`, and under `--no-run` it
/// appends ` - compile`; neither suffix is part of the persisted name.
struct TestName<'a> {
    file: &'a str,
    line: &'a str,
}

fn split_test_name(human_name: &str) -> Option<TestName<'_>> {
    let (file_and_item, line_part) = human_name.rsplit_once(" (line ")?;
    let (line, _) = line_part.split_once(')')?;
    let file = file_and_item
        .split_once(" - ")
        .map(|(file, _)| file)
        .or_else(|| file_and_item.strip_suffix(" -"))?;
    Some(TestName { file, line })
}

/// Extracts the human-readable test names from rustdoc's stdout.
///
/// rustdoc prints one `test <name> ... <status>` line per doc test when
/// invoked with `--test`. We don't care about `<status>` here (the binaries
/// haven't been run yet — `--no-run` is in effect); we only need `<name>`.
///
/// Returns names in the order rustdoc emitted them, which is the order
/// `mangle_test_name` relies on for assigning per-(file, line) suffixes.
fn parse_test_names(stdout: &str) -> Vec<String> {
    stdout
        .lines()
        .filter_map(|line| {
            let rest = line.strip_prefix("test ")?;
            let name = rest.rsplit_once(" ... ")?.0;
            Some(name.to_string())
        })
        .collect()
}

/// Reproduces the directory name rustdoc uses under `--persist-doctests`
/// for a given human-readable test name.
///
/// rustdoc's persisted directories are named `<sanitized-file>_<line>_<n>`,
/// where non-alphanumeric characters in the file path are replaced with `_`
/// and `<n>` is a per-(file, line) sequence number that increments when
/// macro expansion produces multiple tests at the same source location.
///
/// `counts` must be threaded across every call within the same rustdoc
/// invocation so the indices match the order rustdoc assigned them. If the
/// input doesn't match the expected shape we fall back to a plain
/// alphanumeric sanitization of the whole name.
fn mangle_test_name(human_name: &str, counts: &mut HashMap<(String, String), usize>) -> String {
    if let Some(TestName { file, line }) = split_test_name(human_name) {
        let mangled: String = file
            .chars()
            .map(|c| if c.is_ascii_alphanumeric() { c } else { '_' })
            .collect();
        // Macro expansion can produce multiple doc tests that share
        // the same source file and line. rustdoc assigns each one a
        // sequential suffix in the order it emits them, so we mirror
        // that here to keep the mangled name in sync with the
        // persisted directory name.
        let key = (mangled.clone(), line.to_string());
        let index = counts.entry(key).or_insert(0);
        let result = format!("{}_{}_{}", mangled, line, *index);
        *index += 1;
        return result;
    }
    human_name
        .chars()
        .map(|c| if c.is_ascii_alphanumeric() { c } else { '_' })
        .collect()
}

/// Doctest attributes that change how a persisted binary must be treated.
#[derive(Clone, Copy, Default, Debug, PartialEq, Eq)]
struct DoctestAttributes {
    should_panic: bool,
    no_run: bool,
}

/// Reads `rustdoc --output-format=doctest` JSON into a `(file, line)` map.
///
/// Only the fields the runner needs are read. Anything unexpected in the
/// document yields an empty map rather than an error: the metadata then
/// simply lacks attributes and the runner treats every test as a plain one,
/// which is the pre-existing behavior.
fn parse_doctest_attributes(json: &str) -> HashMap<(String, String), DoctestAttributes> {
    let mut attributes = HashMap::new();
    let value = match json::parse(json) {
        Some(value) => value,
        None => return attributes,
    };
    let doctests = match value.get("doctests").and_then(json::Value::as_array) {
        Some(doctests) => doctests,
        None => return attributes,
    };
    for doctest in doctests {
        let file = doctest.get("file").and_then(json::Value::as_str);
        let line = doctest.get("line").and_then(json::Value::as_integer);
        let (file, line) = match (file, line) {
            (Some(file), Some(line)) => (file, line),
            _ => continue,
        };
        let flag = |name: &str| {
            doctest
                .get("doctest_attributes")
                .and_then(|attrs| attrs.get(name))
                .and_then(json::Value::as_bool)
                .unwrap_or(false)
        };
        attributes.insert(
            (file.to_string(), line.to_string()),
            DoctestAttributes {
                should_panic: flag("should_panic"),
                no_run: flag("no_run"),
            },
        );
    }
    attributes
}

/// Writes the `<mangled-dir-name>=<human-name>` mapping consumed by
/// `rustdoc_test_runner`, with tab separated attribute flags appended to
/// the human name when known.
///
/// Lines are sorted by mangled name (via `BTreeSet`) to keep the output
/// stable across builds, even though the per-(file, line) suffixes
/// themselves are still assigned in rustdoc-emit order. Write failures are
/// intentionally swallowed — the runner falls back to using the directory
/// name as the test name if the metadata file is missing or malformed.
fn render_test_metadata(
    stdout: &str,
    attributes: &HashMap<(String, String), DoctestAttributes>,
) -> String {
    let names = parse_test_names(stdout);
    let mut counts: HashMap<(String, String), usize> = HashMap::new();
    let entries: BTreeSet<(String, String)> = names
        .iter()
        .map(|name| {
            let mangled = mangle_test_name(name, &mut counts);
            // `--no-run` labels every test `- compile`; the runner adds
            // its own suffixes when reporting.
            let human = name.strip_suffix(" - compile").unwrap_or(name);
            let mut entry = human.to_string();
            if let Some(TestName { file, line }) = split_test_name(human) {
                if let Some(attrs) = attributes.get(&(file.to_string(), line.to_string())) {
                    if attrs.should_panic {
                        entry.push_str("\tshould_panic");
                    }
                    if attrs.no_run {
                        entry.push_str("\tno_run");
                    }
                }
            }
            (mangled, entry)
        })
        .collect();

    let mut content = String::new();
    for (mangled, human) in &entries {
        content.push_str(mangled);
        content.push('=');
        content.push_str(human);
        content.push('\n');
    }
    content
}

/// Returns true if a stderr line looks like a rustdoc warning.
///
/// We treat any line containing `warning:` as a warning; this is the
/// trigger that makes us replay buffered stdout even on a successful
/// build, so warnings printed to stdout don't get silently dropped.
fn line_has_warning(line: &[u8]) -> bool {
    contains_subslice(line, b"warning:")
}

/// Naive byte-level substring search, used by `line_has_warning` to avoid
/// allocating a `String` for every stderr line.
fn contains_subslice(haystack: &[u8], needle: &[u8]) -> bool {
    haystack
        .windows(needle.len())
        .any(|window| window == needle)
}

fn main() {
    let debug = env::var_os("RULES_RUST_RUSTDOC_DEBUG").is_some();
    let args = WrapperArgs::parse();

    if args.child_args.is_empty() {
        eprintln!("Usage: rustdoc_compile_wrapper [--test-metadata FILE] [--doctests FILE] -- <command> [args...]");
        exit(1);
    }

    let mut child = Command::new(&args.child_args[0])
        .args(&args.child_args[1..])
        .stdout(if debug {
            Stdio::inherit()
        } else {
            Stdio::piped()
        })
        .stderr(Stdio::piped())
        .spawn()
        .unwrap_or_else(|e| {
            eprintln!("Failed to spawn {}: {}", args.child_args[0], e);
            exit(1);
        });

    let child_stdout = child.stdout.take();
    let child_stderr = child.stderr.take().unwrap();

    let stdout_handle = thread::spawn(move || {
        let mut buf = Vec::new();
        if let Some(mut reader) = child_stdout {
            let _ = reader.read_to_end(&mut buf);
        }
        buf
    });

    let stderr_handle = thread::spawn(move || {
        let reader = io::BufReader::new(child_stderr);
        let mut stderr = io::stderr().lock();
        let mut has_warning = false;
        for line in reader.split(b'\n') {
            let line = match line {
                Ok(l) => l,
                Err(_) => break,
            };
            if !has_warning && line_has_warning(&line) {
                has_warning = true;
            }
            let _ = stderr.write_all(&line);
            let _ = stderr.write_all(b"\n");
        }
        has_warning
    });

    let stdout_buf = stdout_handle.join().unwrap_or_default();
    let has_warning = stderr_handle.join().unwrap_or(false);

    let status = child.wait().unwrap_or_else(|e| {
        eprintln!("Failed to wait for child process: {}", e);
        exit(1);
    });

    if let Some(ref path) = args.test_metadata_path {
        let attributes = args
            .doctests_path
            .as_deref()
            .and_then(|path| fs::read_to_string(path).ok())
            .map(|json| parse_doctest_attributes(&json))
            .unwrap_or_default();
        let stdout_str = String::from_utf8_lossy(&stdout_buf);
        let _ = fs::write(path, render_test_metadata(&stdout_str, &attributes));
    }

    let code = status.code().unwrap_or(1);
    if !debug && (code != 0 || has_warning) && !stdout_buf.is_empty() {
        let _ = io::stderr().write_all(&stdout_buf);
    }

    exit(code);
}

/// A minimal JSON reader for `rustdoc --output-format=doctest`.
///
/// These tools build without third party crates, so this covers just the
/// JSON grammar (RFC 8259) with no extensions. Numbers are kept as text
/// since the only numeric field used is a line number.
mod json {
    use std::str::Chars;

    #[derive(Debug, PartialEq)]
    pub(crate) enum Value {
        Null,
        Bool(bool),
        Number(String),
        String(String),
        Array(Vec<Value>),
        Object(Vec<(String, Value)>),
    }

    impl Value {
        pub(crate) fn get(&self, key: &str) -> Option<&Value> {
            match self {
                Value::Object(members) => members
                    .iter()
                    .find(|(name, _)| name == key)
                    .map(|(_, value)| value),
                _ => None,
            }
        }

        pub(crate) fn as_array(&self) -> Option<&[Value]> {
            match self {
                Value::Array(items) => Some(items),
                _ => None,
            }
        }

        pub(crate) fn as_str(&self) -> Option<&str> {
            match self {
                Value::String(text) => Some(text),
                _ => None,
            }
        }

        pub(crate) fn as_bool(&self) -> Option<bool> {
            match self {
                Value::Bool(value) => Some(*value),
                _ => None,
            }
        }

        pub(crate) fn as_integer(&self) -> Option<u64> {
            match self {
                Value::Number(text) => text.parse().ok(),
                _ => None,
            }
        }
    }

    /// Parses a complete JSON document, returning `None` on any error.
    pub(crate) fn parse(text: &str) -> Option<Value> {
        let mut parser = Parser {
            chars: text.chars(),
            peeked: None,
        };
        let value = parser.value()?;
        parser.skip_whitespace();
        if parser.peek().is_some() {
            return None;
        }
        Some(value)
    }

    struct Parser<'a> {
        chars: Chars<'a>,
        peeked: Option<char>,
    }

    impl Parser<'_> {
        fn peek(&mut self) -> Option<char> {
            if self.peeked.is_none() {
                self.peeked = self.chars.next();
            }
            self.peeked
        }

        fn next(&mut self) -> Option<char> {
            match self.peeked.take() {
                Some(c) => Some(c),
                None => self.chars.next(),
            }
        }

        fn skip_whitespace(&mut self) {
            while matches!(self.peek(), Some(' ' | '\t' | '\n' | '\r')) {
                self.next();
            }
        }

        fn expect(&mut self, expected: char) -> Option<()> {
            if self.next()? == expected {
                Some(())
            } else {
                None
            }
        }

        fn literal(&mut self, text: &str, value: Value) -> Option<Value> {
            for expected in text.chars() {
                self.expect(expected)?;
            }
            Some(value)
        }

        fn value(&mut self) -> Option<Value> {
            self.skip_whitespace();
            match self.peek()? {
                '{' => self.object(),
                '[' => self.array(),
                '"' => self.string().map(Value::String),
                't' => self.literal("true", Value::Bool(true)),
                'f' => self.literal("false", Value::Bool(false)),
                'n' => self.literal("null", Value::Null),
                '-' | '0'..='9' => self.number(),
                _ => None,
            }
        }

        fn object(&mut self) -> Option<Value> {
            self.expect('{')?;
            let mut members = Vec::new();
            self.skip_whitespace();
            if self.peek() == Some('}') {
                self.next();
                return Some(Value::Object(members));
            }
            loop {
                self.skip_whitespace();
                let key = self.string()?;
                self.skip_whitespace();
                self.expect(':')?;
                let value = self.value()?;
                members.push((key, value));
                self.skip_whitespace();
                match self.next()? {
                    ',' => continue,
                    '}' => return Some(Value::Object(members)),
                    _ => return None,
                }
            }
        }

        fn array(&mut self) -> Option<Value> {
            self.expect('[')?;
            let mut items = Vec::new();
            self.skip_whitespace();
            if self.peek() == Some(']') {
                self.next();
                return Some(Value::Array(items));
            }
            loop {
                items.push(self.value()?);
                self.skip_whitespace();
                match self.next()? {
                    ',' => continue,
                    ']' => return Some(Value::Array(items)),
                    _ => return None,
                }
            }
        }

        fn string(&mut self) -> Option<String> {
            self.expect('"')?;
            let mut text = String::new();
            loop {
                match self.next()? {
                    '"' => return Some(text),
                    '\\' => match self.next()? {
                        '"' => text.push('"'),
                        '\\' => text.push('\\'),
                        '/' => text.push('/'),
                        'b' => text.push('\u{8}'),
                        'f' => text.push('\u{c}'),
                        'n' => text.push('\n'),
                        'r' => text.push('\r'),
                        't' => text.push('\t'),
                        'u' => {
                            let code = self.hex4()?;
                            // Surrogate pairs arrive as two escapes.
                            let c = if (0xD800..0xDC00).contains(&code) {
                                self.expect('\\')?;
                                self.expect('u')?;
                                let low = self.hex4()?;
                                let combined =
                                    0x10000 + ((code - 0xD800) << 10) + low.checked_sub(0xDC00)?;
                                char::from_u32(combined)?
                            } else {
                                char::from_u32(code)?
                            };
                            text.push(c);
                        }
                        _ => return None,
                    },
                    c => text.push(c),
                }
            }
        }

        fn hex4(&mut self) -> Option<u32> {
            let mut code = 0;
            for _ in 0..4 {
                code = code * 16 + self.next()?.to_digit(16)?;
            }
            Some(code)
        }

        fn number(&mut self) -> Option<Value> {
            let mut text = String::new();
            while let Some(c) = self.peek() {
                if c.is_ascii_digit() || matches!(c, '-' | '+' | '.' | 'e' | 'E') {
                    text.push(c);
                    self.next();
                } else {
                    break;
                }
            }
            // Validate by parsing; the text form is kept for integers.
            text.parse::<f64>().ok()?;
            Some(Value::Number(text))
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_names_are_taken_from_rustdoc_stdout() {
        let stdout = "\nrunning 2 tests\n\
            test src/lib.rs - (line 3) - compile ... ok\n\
            test src/lib.rs - answer (line 12) - compile ... ok\n\
            \n\
            test result: ok. 2 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s\n";
        assert_eq!(
            parse_test_names(stdout),
            vec![
                "src/lib.rs - (line 3) - compile",
                "src/lib.rs - answer (line 12) - compile"
            ]
        );
    }

    #[test]
    fn item_doctests_map_to_persisted_directories() {
        let mut counts = HashMap::new();
        assert_eq!(
            mangle_test_name("src/lib.rs - answer (line 12)", &mut counts),
            "src_lib_rs_12_0"
        );
        assert_eq!(
            mangle_test_name("src/lib.rs - answer (line 12)", &mut counts),
            "src_lib_rs_12_1"
        );
    }

    #[test]
    fn crate_level_doctests_map_to_persisted_directories() {
        let mut counts = HashMap::new();
        assert_eq!(
            mangle_test_name("test/pkg/lib.rs - (line 3)", &mut counts),
            "test_pkg_lib_rs_3_0"
        );
        assert_eq!(
            mangle_test_name("test/pkg/lib.rs - (line 18) - should panic", &mut counts),
            "test_pkg_lib_rs_18_0"
        );
        assert_eq!(
            mangle_test_name("test/pkg/lib.rs - (line 25) - compile", &mut counts),
            "test_pkg_lib_rs_25_0"
        );
    }

    #[test]
    fn unexpected_names_are_sanitized() {
        let mut counts = HashMap::new();
        assert_eq!(
            mangle_test_name("something else", &mut counts),
            "something_else"
        );
    }

    const DOCTESTS_JSON: &str = r#"{
      "format_version": 2,
      "doctests": [
        {"file": "src/lib.rs", "line": 3,
         "doctest_attributes": {"original": "should_panic", "should_panic": true, "no_run": false,
                                "ignore": "None", "rust": true, "compile_fail": false, "error_codes": [],
                                "edition": null, "added_css_classes": [], "unknown": []},
         "original_code": "panic!(\"boom \\u00e9\");", "name": "src/lib.rs - (line 3)"},
        {"file": "src/lib.rs", "line": 12,
         "doctest_attributes": {"should_panic": false, "no_run": true},
         "name": "src/lib.rs - answer (line 12)"},
        {"file": "src/lib.rs", "line": 20,
         "doctest_attributes": {"should_panic": false, "no_run": false},
         "name": "src/lib.rs - plain (line 20)"}
      ]
    }"#;

    #[test]
    fn attributes_are_read_from_doctest_json() {
        let attributes = parse_doctest_attributes(DOCTESTS_JSON);
        assert_eq!(
            attributes.get(&("src/lib.rs".to_string(), "3".to_string())),
            Some(&DoctestAttributes {
                should_panic: true,
                no_run: false
            })
        );
        assert_eq!(
            attributes.get(&("src/lib.rs".to_string(), "12".to_string())),
            Some(&DoctestAttributes {
                should_panic: false,
                no_run: true
            })
        );
        assert_eq!(attributes.len(), 3);
    }

    #[test]
    fn malformed_json_yields_no_attributes() {
        assert!(parse_doctest_attributes("{\"doctests\": [").is_empty());
        assert!(parse_doctest_attributes("[]").is_empty());
    }

    #[test]
    fn metadata_carries_attributes_and_drops_compile_suffix() {
        let stdout = "test src/lib.rs - plain (line 20) - compile ... ok\n\
            test src/lib.rs - (line 3) - compile ... ok\n\
            test src/lib.rs - answer (line 12) - compile ... ok\n";
        let metadata = render_test_metadata(stdout, &parse_doctest_attributes(DOCTESTS_JSON));
        assert_eq!(
            metadata,
            "src_lib_rs_12_0=src/lib.rs - answer (line 12)\tno_run\n\
             src_lib_rs_20_0=src/lib.rs - plain (line 20)\n\
             src_lib_rs_3_0=src/lib.rs - (line 3)\tshould_panic\n"
        );
    }

    #[test]
    fn json_strings_and_numbers_are_decoded() {
        let value = json::parse(
            r#"{"s": "a\"b\\c\n\u00e9\ud83e\udd80", "n": 42, "f": -1.5e3, "e": {}, "l": []}"#,
        )
        .unwrap();
        assert_eq!(
            value.get("s").and_then(json::Value::as_str),
            Some("a\"b\\c\né🦀")
        );
        assert_eq!(value.get("n").and_then(json::Value::as_integer), Some(42));
        assert_eq!(
            value.get("f"),
            Some(&json::Value::Number("-1.5e3".to_string()))
        );
        assert_eq!(value.get("e"), Some(&json::Value::Object(vec![])));
        assert_eq!(
            value.get("l").and_then(json::Value::as_array),
            Some(&[][..])
        );
        assert_eq!(json::parse("{\"a\": yes}"), None);
        assert_eq!(json::parse("{} x"), None);
    }
}
