use std::collections::HashMap;
use std::env;
use std::fs;
use std::io::{BufRead, BufReader, Write};
use std::path::PathBuf;
use std::process::{Command, Stdio};
use std::thread;

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
    eprintln!(
        "  RUNFILES_MANIFEST_FILE={:?}",
        env::var("RUNFILES_MANIFEST_FILE").ok()
    );
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

/// The counts libtest prints on its `test result:` summary line.
#[derive(Debug, PartialEq)]
struct Summary {
    passed: usize,
    failed: usize,
    ignored: usize,
}

struct ParsedOutput {
    results: Vec<TestResult>,
    failures: HashMap<String, String>,
    suite_time: f64,
    /// `None` if libtest never printed its summary line, which is our main
    /// signal that the binary didn't finish running as a test harness.
    summary: Option<Summary>,
}

/// A `---- <name> stdout ----` (or `stderr`) banner that opens a failure
/// detail block; returns the test name it belongs to.
fn failure_header(line: &str) -> Option<&str> {
    let inner = line.strip_prefix("---- ")?;
    inner
        .strip_suffix(" stdout ----")
        .or_else(|| inner.strip_suffix(" stderr ----"))
}

fn record_failure(failures: &mut HashMap<String, String>, name: &str, lines: &[String]) {
    let body = lines.join("\n").trim_end().to_string();
    // A test can have both stdout and stderr blocks; keep both.
    match failures.get_mut(name) {
        Some(existing) => {
            existing.push('\n');
            existing.push_str(&body);
        }
        None => {
            failures.insert(name.to_string(), body);
        }
    }
}

fn parse_libtest_output(output: &str) -> ParsedOutput {
    let mut results = Vec::new();
    let mut failures = HashMap::new();
    let mut current_failure: Option<String> = None;
    let mut failure_lines: Vec<String> = Vec::new();
    let mut suite_time = 0.0;
    let mut summary = None;

    for line in output.lines() {
        // A new detail banner both opens a block and closes the previous one.
        if let Some(name) = failure_header(line) {
            if let Some(prev) = current_failure.take() {
                record_failure(&mut failures, &prev, &failure_lines);
            }
            current_failure = Some(name.to_string());
            failure_lines.clear();
            continue;
        }

        if let Some(name) = &current_failure {
            // A detail block runs until the trailing `failures:` name list, the
            // `test result:` summary, or a bare `----` terminator (older
            // libtest). Everything else is part of the captured output/panic.
            // Note we must not stop the block until here, or the summary line
            // gets swallowed and we lose the run totals entirely.
            if line == "failures:" || line.starts_with("test result: ") {
                record_failure(&mut failures, name, &failure_lines);
                current_failure = None;
                failure_lines.clear();
                // fall through so the summary line is still parsed below
            } else if line.starts_with("----") {
                record_failure(&mut failures, name, &failure_lines);
                current_failure = None;
                failure_lines.clear();
                continue;
            } else {
                // Drop the blank line libtest prints right after the banner.
                if !(line.trim().is_empty() && failure_lines.is_empty()) {
                    failure_lines.push(line.to_string());
                }
                continue;
            }
        }

        // A per-test result: "test <name> ... ok|FAILED|ignored|bench"
        if line.starts_with("test ") && line.contains(" ... ") {
            if let Some(result) = parse_test_result_line(line) {
                results.push(result);
                continue;
            }
        }

        // The run summary: "test result: ok. N passed; M failed; ..."
        if line.starts_with("test result: ") {
            if let Some(time) = parse_suite_time(line) {
                suite_time = time;
            }
            if let Some(counts) = parse_suite_counts(line) {
                summary = Some(counts);
            }
        }
    }

    if let Some(name) = &current_failure {
        record_failure(&mut failures, name, &failure_lines);
    }

    ParsedOutput {
        results,
        failures,
        suite_time,
        summary,
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

fn parse_suite_counts(line: &str) -> Option<Summary> {
    // "test result: ok. 3 passed; 0 failed; 1 ignored; 0 measured; 0 filtered out; ..."
    // Each ';'-separated clause ends in "<N> <label>"; pick out the three we
    // care about. "measured"/"filtered out" are left alone on purpose.
    let mut passed = None;
    let mut failed = None;
    let mut ignored = None;
    for clause in line.split(';') {
        let tokens: Vec<&str> = clause.split_whitespace().collect();
        if tokens.len() < 2 {
            continue;
        }
        let count = tokens[tokens.len() - 2].parse::<usize>();
        let label = tokens[tokens.len() - 1];
        if let Ok(count) = count {
            match label {
                "passed" => passed = Some(count),
                "failed" => failed = Some(count),
                "ignored" => ignored = Some(count),
                _ => {}
            }
        }
    }
    Some(Summary {
        passed: passed?,
        failed: failed?,
        ignored: ignored?,
    })
}

/// Pull a one-line summary out of a libtest failure block for the `message`
/// attribute, keeping the full block for the element body. Handles both the
/// current `panicked at <loc>:\n<message>` layout and the older
/// `panicked at '<message>', <loc>` one; falls back to the first non-empty
/// line for failures that aren't panics (e.g. returned `Err`).
fn extract_failure_message(body: &str) -> String {
    let lines: Vec<&str> = body.lines().collect();
    for (i, line) in lines.iter().enumerate() {
        let Some((_, after)) = line.split_once("panicked at ") else {
            continue;
        };
        // Old format keeps the message inline in single quotes.
        if let Some(start) = after.find('\'') {
            if let Some(end) = after[start + 1..].rfind('\'') {
                let msg = &after[start + 1..start + 1 + end];
                if !msg.is_empty() {
                    return msg.to_string();
                }
            }
        }
        // New format puts the message on the following line(s).
        if let Some(next) = lines[i + 1..].iter().find(|l| !l.trim().is_empty()) {
            return next.trim().to_string();
        }
    }
    lines
        .iter()
        .map(|l| l.trim())
        .find(|l| !l.is_empty())
        .unwrap_or("test failed")
        .to_string()
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

struct Report<'a> {
    binary_name: &'a str,
    parsed: &'a ParsedOutput,
    stdout: &'a str,
    stderr: &'a str,
    /// Set when the binary itself misbehaved (crashed, or exited non-zero
    /// without failing a test), as opposed to an ordinary test failure.
    harness_error: Option<&'a str>,
}

fn build_junit_xml(report: &Report) -> String {
    let results = &report.parsed.results;
    let n_fail = results.iter().filter(|r| r.status == "FAILED").count();
    let n_skip = results.iter().filter(|r| r.status == "ignored").count();
    let n_err = usize::from(report.harness_error.is_some());

    let suite = xml_escape(report.binary_name);
    let mut xml = String::new();
    xml.push_str("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n");
    xml.push_str("<testsuites>\n");
    xml.push_str(&format!(
        "<testsuite name=\"{}\" tests=\"{}\" failures=\"{}\" skipped=\"{}\" errors=\"{}\" time=\"{:.3}\">\n",
        suite,
        results.len() + n_err,
        n_fail,
        n_skip,
        n_err,
        report.parsed.suite_time,
    ));

    for r in results {
        let name = xml_escape(&r.name);
        match r.status.as_str() {
            "FAILED" => {
                let body = report
                    .parsed
                    .failures
                    .get(&r.name)
                    .map_or("", |s| s.as_str());
                let message = extract_failure_message(body);
                xml.push_str(&format!(
                    "<testcase name=\"{}\" classname=\"{}\" status=\"run\">\n",
                    name, suite,
                ));
                xml.push_str(&format!(
                    "<failure message=\"{}\">{}</failure>\n",
                    xml_escape(&message),
                    xml_escape(body),
                ));
                xml.push_str("</testcase>\n");
            }
            "ignored" => {
                xml.push_str(&format!(
                    "<testcase name=\"{}\" classname=\"{}\" status=\"run\">\n",
                    name, suite,
                ));
                xml.push_str("<skipped/>\n");
                xml.push_str("</testcase>\n");
            }
            _ => {
                xml.push_str(&format!(
                    "<testcase name=\"{}\" classname=\"{}\" status=\"run\"/>\n",
                    name, suite,
                ));
            }
        }
    }

    if let Some(error) = report.harness_error {
        xml.push_str(&format!(
            "<testcase name=\"{} (test harness)\" classname=\"{}\" status=\"run\">\n",
            suite, suite,
        ));
        xml.push_str(&format!("<error message=\"{}\"/>\n", xml_escape(error)));
        xml.push_str("</testcase>\n");
    }

    if !report.stdout.is_empty() {
        xml.push_str(&format!(
            "<system-out>{}</system-out>\n",
            xml_escape(report.stdout)
        ));
    }
    if !report.stderr.is_empty() {
        xml.push_str(&format!(
            "<system-err>{}</system-err>\n",
            xml_escape(report.stderr)
        ));
    }

    xml.push_str("</testsuite>\n");
    xml.push_str("</testsuites>\n");
    xml
}

/// Warn (loudly, but without failing the run) when our parse of the output
/// disagrees with the totals libtest reported. If this fires, the format we
/// scrape has probably shifted and the report can't be trusted.
fn warn_on_count_mismatch(summary: &Summary, results: &[TestResult]) {
    let passed = results.iter().filter(|r| r.status == "ok").count();
    let failed = results.iter().filter(|r| r.status == "FAILED").count();
    let ignored = results.iter().filter(|r| r.status == "ignored").count();
    if (passed, failed, ignored) != (summary.passed, summary.failed, summary.ignored) {
        eprintln!(
            "WARNING: junit_runner: parsed {passed} passed / {failed} failed / {ignored} ignored, \
             but libtest reported {} / {} / {}; the JUnit report may be incomplete",
            summary.passed, summary.failed, summary.ignored,
        );
    }
}

fn main() {
    let rust_test_bin = env::var("RUST_TEST_BIN").unwrap_or_else(|_| {
        eprintln!("ERROR: junit_runner: RUST_TEST_BIN environment variable not set");
        std::process::exit(1);
    });

    let test_bin = resolve_runfiles(&rust_test_bin);
    let args: Vec<String> = env::args().skip(1).collect();

    // Nothing wants a report (e.g. `bazel run`): get out of the way entirely.
    let xml_path = match env::var("XML_OUTPUT_FILE") {
        Ok(path) => path,
        Err(_) => exec_passthrough(&test_bin, &args),
    };

    let binary_name = test_bin
        .file_name()
        .and_then(|n| n.to_str())
        .unwrap_or("rust_test")
        .to_string();

    let mut child = Command::new(&test_bin)
        .args(&args)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .unwrap_or_else(|e| {
            eprintln!("ERROR: junit_runner: failed to spawn test binary: {}", e);
            std::process::exit(1);
        });

    let child_stdout = child.stdout.take().expect("stdout was piped");
    let child_stderr = child.stderr.take().expect("stderr was piped");

    // Drain stderr on a separate thread and mirror it straight through, so a
    // test that writes a lot to stderr can't wedge us by filling the pipe
    // while we're busy reading stdout.
    let stderr_thread = thread::spawn(move || {
        let reader = BufReader::new(child_stderr);
        let mut collected = Vec::new();
        let err = std::io::stderr();
        let mut err = err.lock();
        for line in reader.lines().map_while(Result::ok) {
            let _ = writeln!(err, "{}", line);
            collected.push(line);
        }
        collected.join("\n")
    });

    let mut stdout_lines = Vec::new();
    {
        let reader = BufReader::new(child_stdout);
        let out = std::io::stdout();
        let mut out = out.lock();
        for line in reader.lines() {
            match line {
                Ok(l) => {
                    let _ = writeln!(out, "{}", l);
                    stdout_lines.push(l);
                }
                Err(e) => {
                    eprintln!("WARNING: junit_runner: error reading stdout: {}", e);
                    break;
                }
            }
        }
    }

    let stderr_output = stderr_thread.join().unwrap_or_default();
    let status = child.wait().unwrap_or_else(|e| {
        eprintln!("ERROR: junit_runner: failed to wait for test binary: {}", e);
        std::process::exit(1);
    });

    let stdout_output = stdout_lines.join("\n");
    let parsed = parse_libtest_output(&stdout_output);

    let exit_code = status.code();
    let exit_desc = exit_code.map_or_else(|| "a signal".to_string(), |c| format!("code {}", c));

    // Separate a misbehaving binary from a test that legitimately failed. No
    // summary means libtest never finished; a non-zero exit with nothing
    // marked FAILED means something outside the tests went wrong. In both
    // cases we'd otherwise hand back an all-green report for a red run.
    let harness_error = if parsed.summary.is_none() {
        Some(format!(
            "test binary exited with {} without printing a libtest summary; \
             it likely crashed or aborted before finishing",
            exit_desc,
        ))
    } else if exit_code != Some(0) && !parsed.results.iter().any(|r| r.status == "FAILED") {
        Some(format!(
            "test binary exited with {} but reported no failing tests",
            exit_desc,
        ))
    } else {
        None
    };

    if let Some(summary) = &parsed.summary {
        warn_on_count_mismatch(summary, &parsed.results);
    }

    let report = Report {
        binary_name: &binary_name,
        parsed: &parsed,
        stdout: &stdout_output,
        stderr: &stderr_output,
        harness_error: harness_error.as_deref(),
    };
    let xml = build_junit_xml(&report);

    if let Err(e) = fs::write(&xml_path, xml.as_bytes()) {
        eprintln!(
            "WARNING: junit_runner: failed to write XML to {}: {}",
            xml_path, e
        );
    }

    std::process::exit(exit_code.unwrap_or(1));
}

#[cfg(test)]
mod tests {
    use super::*;

    fn report<'a>(binary_name: &'a str, parsed: &'a ParsedOutput) -> Report<'a> {
        Report {
            binary_name,
            parsed,
            stdout: "",
            stderr: "",
            harness_error: None,
        }
    }

    #[test]
    fn parse_result_line_ok() {
        assert_eq!(
            parse_test_result_line("test foo::bar ... ok"),
            Some(TestResult {
                name: "foo::bar".into(),
                status: "ok".into()
            }),
        );
    }

    #[test]
    fn parse_result_line_failed() {
        assert_eq!(
            parse_test_result_line("test my_test ... FAILED"),
            Some(TestResult {
                name: "my_test".into(),
                status: "FAILED".into()
            }),
        );
    }

    #[test]
    fn parse_result_line_ignored() {
        assert_eq!(
            parse_test_result_line("test skipped_test ... ignored"),
            Some(TestResult {
                name: "skipped_test".into(),
                status: "ignored".into()
            }),
        );
    }

    #[test]
    fn parse_result_line_bench() {
        assert_eq!(
            parse_test_result_line("test bench_thing ... bench"),
            Some(TestResult {
                name: "bench_thing".into(),
                status: "bench".into()
            }),
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
    fn parse_suite_counts_valid() {
        let line = "test result: ok. 3 passed; 1 failed; 2 ignored; 0 measured; 0 filtered out; finished in 1.234s";
        assert_eq!(
            parse_suite_counts(line),
            Some(Summary {
                passed: 3,
                failed: 1,
                ignored: 2
            }),
        );
    }

    #[test]
    fn parse_libtest_output_records_summary() {
        let output = "\
running 1 test
test ok_test ... ok

test result: ok. 1 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.010s";
        let parsed = parse_libtest_output(output);
        assert_eq!(
            parsed.summary,
            Some(Summary {
                passed: 1,
                failed: 0,
                ignored: 0
            }),
        );
    }

    #[test]
    fn parse_libtest_output_no_summary_when_truncated() {
        // A binary that dies mid-run never prints "test result:".
        let output = "\
running 2 tests
test a ... ok";
        let parsed = parse_libtest_output(output);
        assert!(parsed.summary.is_none());
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
    fn parse_libtest_output_summary_after_failure_block() {
        // Modern libtest does not print a closing `----` after a failure's
        // detail block: the block is followed directly by the `failures:` name
        // list and then `test result:`. The parser must still pick up the
        // summary here, otherwise a passing-but-failing run looks like a crash.
        let output = "\
running 3 tests
test tests::test_ignored ... ok
test tests::test_passing ... ok
test tests::test_failing ... FAILED

failures:

---- tests::test_failing stdout ----

thread 'tests::test_failing' panicked at test/junit/lib.rs:14:9:
assertion `left == right` failed: arithmetic is broken
  left: 4
 right: 5
note: run with `RUST_BACKTRACE=1` environment variable to display a backtrace


failures:
    tests::test_failing

test result: FAILED. 2 passed; 1 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s";

        let parsed = parse_libtest_output(output);
        let summary = parsed
            .summary
            .expect("summary must survive the failure block");
        assert_eq!(summary.passed, 2);
        assert_eq!(summary.failed, 1);
        assert_eq!(summary.ignored, 0);

        // The failure body holds the panic but not the trailing summary lines.
        let body = &parsed.failures["tests::test_failing"];
        assert!(body.contains("arithmetic is broken"));
        assert!(!body.contains("test result:"));
        assert!(!body.contains("failures:"));
        assert_eq!(
            extract_failure_message(body),
            "assertion `left == right` failed: arithmetic is broken"
        );
    }

    #[test]
    fn failure_message_new_panic_format() {
        let body = "\
thread 'tests::foo' panicked at src/lib.rs:10:5:
assertion `left == right` failed
  left: 1
 right: 2
note: run with `RUST_BACKTRACE=1` environment variable to display a backtrace";
        assert_eq!(
            extract_failure_message(body),
            "assertion `left == right` failed"
        );
    }

    #[test]
    fn failure_message_old_panic_format() {
        let body = "thread 'tests::foo' panicked at 'boom', src/lib.rs:3:5";
        assert_eq!(extract_failure_message(body), "boom");
    }

    #[test]
    fn failure_message_non_panic_fallback() {
        let body = "the test returned an Err: NotFound";
        assert_eq!(
            extract_failure_message(body),
            "the test returned an Err: NotFound"
        );
    }

    #[test]
    fn xml_escape_special_chars() {
        assert_eq!(
            xml_escape("a&b<c>d\"e'f"),
            "a&amp;b&lt;c&gt;d&quot;e&apos;f"
        );
    }

    #[test]
    fn xml_escape_no_special() {
        assert_eq!(xml_escape("hello world"), "hello world");
    }

    #[test]
    fn build_xml_passing_tests() {
        let parsed = ParsedOutput {
            results: vec![
                TestResult {
                    name: "test_a".into(),
                    status: "ok".into(),
                },
                TestResult {
                    name: "test_b".into(),
                    status: "ok".into(),
                },
            ],
            failures: HashMap::new(),
            suite_time: 1.0,
            summary: Some(Summary {
                passed: 2,
                failed: 0,
                ignored: 0,
            }),
        };
        let xml = build_junit_xml(&report("my_test", &parsed));
        assert!(xml.contains("<?xml version=\"1.0\""));
        assert!(xml.contains("tests=\"2\""));
        assert!(xml.contains("failures=\"0\""));
        assert!(xml.contains("skipped=\"0\""));
        assert!(xml.contains("errors=\"0\""));
        assert!(xml.contains("<testcase name=\"test_a\""));
        assert!(xml.contains("<testcase name=\"test_b\""));
        assert!(!xml.contains("<failure"));
        assert!(!xml.contains("<skipped/>"));
    }

    #[test]
    fn build_xml_with_failure() {
        let mut failures = HashMap::new();
        failures.insert(
            "bad_test".to_string(),
            "thread 'bad_test' panicked at src/lib.rs:1:1:\nsomething broke".to_string(),
        );
        let parsed = ParsedOutput {
            results: vec![TestResult {
                name: "bad_test".into(),
                status: "FAILED".into(),
            }],
            failures,
            suite_time: 0.1,
            summary: Some(Summary {
                passed: 0,
                failed: 1,
                ignored: 0,
            }),
        };
        let xml = build_junit_xml(&report("my_test", &parsed));
        assert!(xml.contains("failures=\"1\""));
        // The panic message becomes the message attr; the full block is the body.
        assert!(xml.contains("<failure message=\"something broke\">"));
        assert!(xml.contains("panicked at src/lib.rs"));
    }

    #[test]
    fn build_xml_with_ignored() {
        let parsed = ParsedOutput {
            results: vec![TestResult {
                name: "skip_me".into(),
                status: "ignored".into(),
            }],
            failures: HashMap::new(),
            suite_time: 0.0,
            summary: Some(Summary {
                passed: 0,
                failed: 0,
                ignored: 1,
            }),
        };
        let xml = build_junit_xml(&report("my_test", &parsed));
        assert!(xml.contains("skipped=\"1\""));
        assert!(xml.contains("<skipped/>"));
    }

    #[test]
    fn build_xml_escapes_special_chars() {
        let mut failures = HashMap::new();
        failures.insert("test<x>".to_string(), "a & b".to_string());
        let parsed = ParsedOutput {
            results: vec![TestResult {
                name: "test<x>".into(),
                status: "FAILED".into(),
            }],
            failures,
            suite_time: 0.0,
            summary: Some(Summary {
                passed: 0,
                failed: 1,
                ignored: 0,
            }),
        };
        let xml = build_junit_xml(&report("bin&name", &parsed));
        assert!(xml.contains("name=\"bin&amp;name\""));
        assert!(xml.contains("name=\"test&lt;x&gt;\""));
        assert!(xml.contains("a &amp; b"));
    }

    #[test]
    fn build_xml_harness_error() {
        let parsed = ParsedOutput {
            results: vec![TestResult {
                name: "ran_ok".into(),
                status: "ok".into(),
            }],
            failures: HashMap::new(),
            suite_time: 0.0,
            summary: None,
        };
        let mut r = report("crashy", &parsed);
        r.harness_error =
            Some("test binary exited with code 139 without printing a libtest summary");
        let xml = build_junit_xml(&r);
        assert!(xml.contains("errors=\"1\""));
        assert!(xml.contains("tests=\"2\""));
        assert!(xml.contains("<testcase name=\"crashy (test harness)\""));
        assert!(xml.contains("<error message=\"test binary exited with code 139"));
    }

    #[test]
    fn build_xml_includes_captured_output() {
        let parsed = ParsedOutput {
            results: vec![TestResult {
                name: "t".into(),
                status: "ok".into(),
            }],
            failures: HashMap::new(),
            suite_time: 0.0,
            summary: Some(Summary {
                passed: 1,
                failed: 0,
                ignored: 0,
            }),
        };
        let mut r = report("bin", &parsed);
        r.stderr = "a panic backtrace";
        let xml = build_junit_xml(&r);
        assert!(xml.contains("<system-err>a panic backtrace</system-err>"));
    }
}
