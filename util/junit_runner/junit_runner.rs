use std::collections::HashMap;
use std::env;
use std::fs;
use std::io::{BufRead, BufReader, Write};
use std::path::PathBuf;
use std::process::{Command, Stdio};

fn resolve_runfiles(rlocation_path: &str) -> PathBuf {
    if let Ok(manifest) = env::var("RUNFILES_MANIFEST_FILE") {
        if let Ok(contents) = fs::read_to_string(&manifest) {
            let prefix = format!("{} ", rlocation_path);
            for line in contents.lines() {
                if let Some(abs_path) = line.strip_prefix(&prefix) {
                    let p = PathBuf::from(abs_path);
                    if p.exists() {
                        return p;
                    }
                }
            }
        }
    }

    if let Ok(dir) = env::var("RUNFILES_DIR") {
        let candidate = PathBuf::from(&dir).join(rlocation_path);
        if candidate.exists() {
            return candidate;
        }
    }

    if let Ok(dir) = env::var("TEST_SRCDIR") {
        let candidate = PathBuf::from(&dir).join(rlocation_path);
        if candidate.exists() {
            return candidate;
        }
    }

    eprintln!(
        "ERROR: junit_runner: cannot resolve runfiles path: {}",
        rlocation_path
    );
    eprintln!("  RUNFILES_MANIFEST_FILE={:?}", env::var("RUNFILES_MANIFEST_FILE").ok());
    eprintln!("  RUNFILES_DIR={:?}", env::var("RUNFILES_DIR").ok());
    eprintln!("  TEST_SRCDIR={:?}", env::var("TEST_SRCDIR").ok());
    std::process::exit(1);
}

fn exec_passthrough(test_bin: &PathBuf, args: &[String]) -> ! {
    #[cfg(unix)]
    {
        use std::os::unix::process::CommandExt;
        let err = Command::new(test_bin).args(args).exec();
        eprintln!("ERROR: junit_runner: exec failed: {}", err);
        std::process::exit(1);
    }

    #[cfg(not(unix))]
    {
        let status = Command::new(test_bin)
            .args(args)
            .status()
            .unwrap_or_else(|e| {
                eprintln!("ERROR: junit_runner: failed to spawn test binary: {}", e);
                std::process::exit(1);
            });
        std::process::exit(status.code().unwrap_or(1));
    }
}

#[derive(Debug, PartialEq)]
struct TestResult {
    name: String,
    status: String,
}

struct ParsedOutput {
    results: Vec<TestResult>,
    failures: HashMap<String, String>,
    suite_time: f64,
}

fn parse_libtest_output(output: &str) -> ParsedOutput {
    let mut results = Vec::new();
    let mut failures = HashMap::new();
    let mut current_failure: Option<String> = None;
    let mut failure_lines: Vec<String> = Vec::new();
    let mut suite_time = 0.0;

    for line in output.lines() {
        // Check for failure header: ---- <name> stdout ----
        if line.starts_with("---- ") && line.ends_with(" stdout ----") {
            if let Some(ref name) = current_failure {
                failures.insert(name.clone(), failure_lines.join("\n"));
            }
            let name = &line["---- ".len()..line.len() - " stdout ----".len()];
            current_failure = Some(name.to_string());
            failure_lines.clear();
            continue;
        }

        if current_failure.is_some() {
            if line.trim().is_empty() && failure_lines.is_empty() {
                continue;
            }
            if line.starts_with("----") {
                if let Some(ref name) = current_failure {
                    failures.insert(name.clone(), failure_lines.join("\n"));
                }
                current_failure = None;
                failure_lines.clear();
            } else {
                failure_lines.push(line.to_string());
            }
            continue;
        }

        // Check for test result: test <name> ... ok|FAILED|ignored|bench
        if line.starts_with("test ") && line.contains(" ... ") {
            if let Some(result) = parse_test_result_line(line) {
                results.push(result);
                continue;
            }
        }

        // Check for suite summary: test result: ...
        if line.starts_with("test result: ") {
            if let Some(time) = parse_suite_time(line) {
                suite_time = time;
            }
        }
    }

    if let Some(ref name) = current_failure {
        failures.insert(name.clone(), failure_lines.join("\n"));
    }

    ParsedOutput {
        results,
        failures,
        suite_time,
    }
}

fn parse_test_result_line(line: &str) -> Option<TestResult> {
    // Format: "test <name> ... <status>"
    // The name can contain spaces in some edge cases, but typically doesn't.
    // We split on " ... " to separate name from status.
    let after_test = line.strip_prefix("test ")?;
    let sep_pos = after_test.find(" ... ")?;
    let name = &after_test[..sep_pos];
    let rest = &after_test[sep_pos + " ... ".len()..];

    // Status is the first word of rest
    let status = rest.split_whitespace().next()?;
    match status {
        "ok" | "FAILED" | "ignored" | "bench" => Some(TestResult {
            name: name.to_string(),
            status: status.to_string(),
        }),
        _ => None,
    }
}

fn parse_suite_time(line: &str) -> Option<f64> {
    // Format: "test result: ok. N passed; M failed; K ignored; ... finished in X.XXXs"
    let finished_marker = "finished in ";
    let pos = line.find(finished_marker)?;
    let after = &line[pos + finished_marker.len()..];
    let time_str = after.strip_suffix('s')?;
    time_str.parse::<f64>().ok()
}

fn xml_escape(s: &str) -> String {
    let mut result = String::with_capacity(s.len());
    for c in s.chars() {
        match c {
            '&' => result.push_str("&amp;"),
            '<' => result.push_str("&lt;"),
            '>' => result.push_str("&gt;"),
            '"' => result.push_str("&quot;"),
            '\'' => result.push_str("&apos;"),
            _ => result.push(c),
        }
    }
    result
}

fn build_junit_xml(binary_name: &str, parsed: &ParsedOutput) -> String {
    let n_tests = parsed.results.len();
    let n_fail = parsed.results.iter().filter(|r| r.status == "FAILED").count();
    let n_skip = parsed.results.iter().filter(|r| r.status == "ignored").count();

    let mut xml = String::new();
    xml.push_str("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n");
    xml.push_str("<testsuites>\n");
    xml.push_str(&format!(
        "<testsuite name=\"{}\" tests=\"{}\" failures=\"{}\" skipped=\"{}\" errors=\"0\" time=\"{:.3}\">\n",
        xml_escape(binary_name),
        n_tests,
        n_fail,
        n_skip,
        parsed.suite_time,
    ));

    for r in &parsed.results {
        let name = xml_escape(&r.name);
        let classname = xml_escape(binary_name);
        match r.status.as_str() {
            "FAILED" => {
                let msg = parsed.failures.get(&r.name).map(|s| s.as_str()).unwrap_or("");
                xml.push_str(&format!(
                    "<testcase name=\"{}\" classname=\"{}\" status=\"run\">\n",
                    name, classname,
                ));
                xml.push_str(&format!(
                    "<failure message=\"test failed\">{}</failure>\n",
                    xml_escape(msg),
                ));
                xml.push_str("</testcase>\n");
            }
            "ignored" => {
                xml.push_str(&format!(
                    "<testcase name=\"{}\" classname=\"{}\" status=\"run\">\n",
                    name, classname,
                ));
                xml.push_str("<skipped/>\n");
                xml.push_str("</testcase>\n");
            }
            _ => {
                xml.push_str(&format!(
                    "<testcase name=\"{}\" classname=\"{}\" status=\"run\"/>\n",
                    name, classname,
                ));
            }
        }
    }

    xml.push_str("</testsuite>\n");
    xml.push_str("</testsuites>\n");
    xml
}

fn main() {
    let rust_test_bin = env::var("RUST_TEST_BIN").unwrap_or_else(|_| {
        eprintln!("ERROR: junit_runner: RUST_TEST_BIN environment variable not set");
        std::process::exit(1);
    });

    let test_bin = resolve_runfiles(&rust_test_bin);
    let args: Vec<String> = env::args().skip(1).collect();

    let xml_path = env::var("XML_OUTPUT_FILE").ok();
    if xml_path.is_none() {
        exec_passthrough(&test_bin, &args);
    }
    let xml_path = xml_path.unwrap();

    let binary_name = test_bin
        .file_name()
        .and_then(|n| n.to_str())
        .unwrap_or("rust_test")
        .to_string();

    let mut child = Command::new(&test_bin)
        .args(&args)
        .stdout(Stdio::piped())
        .stderr(Stdio::inherit())
        .spawn()
        .unwrap_or_else(|e| {
            eprintln!("ERROR: junit_runner: failed to spawn test binary: {}", e);
            std::process::exit(1);
        });

    let stdout = child.stdout.take().expect("stdout was piped");
    let reader = BufReader::new(stdout);
    let mut collected = Vec::new();

    let out = std::io::stdout();
    let mut out = out.lock();
    for line in reader.lines() {
        match line {
            Ok(l) => {
                let _ = writeln!(out, "{}", l);
                collected.push(l);
            }
            Err(e) => {
                eprintln!("WARNING: junit_runner: error reading stdout: {}", e);
                break;
            }
        }
    }
    drop(out);

    let status = child.wait().unwrap_or_else(|e| {
        eprintln!("ERROR: junit_runner: failed to wait for test binary: {}", e);
        std::process::exit(1);
    });

    let output = collected.join("\n");
    let parsed = parse_libtest_output(&output);
    let xml = build_junit_xml(&binary_name, &parsed);

    if let Err(e) = fs::write(&xml_path, xml.as_bytes()) {
        eprintln!("WARNING: junit_runner: failed to write XML to {}: {}", xml_path, e);
    }

    std::process::exit(status.code().unwrap_or(1));
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_result_line_ok() {
        assert_eq!(
            parse_test_result_line("test foo::bar ... ok"),
            Some(TestResult { name: "foo::bar".into(), status: "ok".into() }),
        );
    }

    #[test]
    fn parse_result_line_failed() {
        assert_eq!(
            parse_test_result_line("test my_test ... FAILED"),
            Some(TestResult { name: "my_test".into(), status: "FAILED".into() }),
        );
    }

    #[test]
    fn parse_result_line_ignored() {
        assert_eq!(
            parse_test_result_line("test skipped_test ... ignored"),
            Some(TestResult { name: "skipped_test".into(), status: "ignored".into() }),
        );
    }

    #[test]
    fn parse_result_line_bench() {
        assert_eq!(
            parse_test_result_line("test bench_thing ... bench"),
            Some(TestResult { name: "bench_thing".into(), status: "bench".into() }),
        );
    }

    #[test]
    fn parse_result_line_invalid() {
        assert_eq!(parse_test_result_line("not a test line"), None);
        assert_eq!(parse_test_result_line("test incomplete"), None);
        assert_eq!(parse_test_result_line("test bad ... unknown_status"), None);
    }

    #[test]
    fn parse_suite_time_valid() {
        let line = "test result: ok. 3 passed; 0 failed; 1 ignored; 0 measured; 0 filtered out; finished in 1.234s";
        assert_eq!(parse_suite_time(line), Some(1.234));
    }

    #[test]
    fn parse_suite_time_no_match() {
        assert_eq!(parse_suite_time("no time here"), None);
    }

    #[test]
    fn parse_libtest_output_mixed() {
        let output = "\
running 3 tests
test pass_test ... ok
test fail_test ... FAILED
test skip_test ... ignored

failures:

---- fail_test stdout ----
assertion failed: false
----

failures:
    fail_test

test result: FAILED. 1 passed; 1 failed; 1 ignored; 0 measured; 0 filtered out; finished in 0.500s";

        let parsed = parse_libtest_output(output);
        assert_eq!(parsed.results.len(), 3);
        assert_eq!(parsed.results[0].status, "ok");
        assert_eq!(parsed.results[1].status, "FAILED");
        assert_eq!(parsed.results[2].status, "ignored");
        assert!(parsed.failures.contains_key("fail_test"));
        assert!(parsed.failures["fail_test"].contains("assertion failed"));
        assert!((parsed.suite_time - 0.5).abs() < 0.001);
    }

    #[test]
    fn xml_escape_special_chars() {
        assert_eq!(xml_escape("a&b<c>d\"e'f"), "a&amp;b&lt;c&gt;d&quot;e&apos;f");
    }

    #[test]
    fn xml_escape_no_special() {
        assert_eq!(xml_escape("hello world"), "hello world");
    }

    #[test]
    fn build_xml_passing_tests() {
        let parsed = ParsedOutput {
            results: vec![
                TestResult { name: "test_a".into(), status: "ok".into() },
                TestResult { name: "test_b".into(), status: "ok".into() },
            ],
            failures: HashMap::new(),
            suite_time: 1.0,
        };
        let xml = build_junit_xml("my_test", &parsed);
        assert!(xml.contains("<?xml version=\"1.0\""));
        assert!(xml.contains("tests=\"2\""));
        assert!(xml.contains("failures=\"0\""));
        assert!(xml.contains("skipped=\"0\""));
        assert!(xml.contains("<testcase name=\"test_a\""));
        assert!(xml.contains("<testcase name=\"test_b\""));
        assert!(!xml.contains("<failure"));
        assert!(!xml.contains("<skipped/>"));
    }

    #[test]
    fn build_xml_with_failure() {
        let mut failures = HashMap::new();
        failures.insert("bad_test".to_string(), "something broke".to_string());
        let parsed = ParsedOutput {
            results: vec![
                TestResult { name: "bad_test".into(), status: "FAILED".into() },
            ],
            failures,
            suite_time: 0.1,
        };
        let xml = build_junit_xml("my_test", &parsed);
        assert!(xml.contains("failures=\"1\""));
        assert!(xml.contains("<failure message=\"test failed\">something broke</failure>"));
    }

    #[test]
    fn build_xml_with_ignored() {
        let parsed = ParsedOutput {
            results: vec![
                TestResult { name: "skip_me".into(), status: "ignored".into() },
            ],
            failures: HashMap::new(),
            suite_time: 0.0,
        };
        let xml = build_junit_xml("my_test", &parsed);
        assert!(xml.contains("skipped=\"1\""));
        assert!(xml.contains("<skipped/>"));
    }

    #[test]
    fn build_xml_escapes_special_chars() {
        let mut failures = HashMap::new();
        failures.insert("test<x>".to_string(), "a & b".to_string());
        let parsed = ParsedOutput {
            results: vec![
                TestResult { name: "test<x>".into(), status: "FAILED".into() },
            ],
            failures,
            suite_time: 0.0,
        };
        let xml = build_junit_xml("bin&name", &parsed);
        assert!(xml.contains("name=\"bin&amp;name\""));
        assert!(xml.contains("name=\"test&lt;x&gt;\""));
        assert!(xml.contains("a &amp; b"));
    }
}
