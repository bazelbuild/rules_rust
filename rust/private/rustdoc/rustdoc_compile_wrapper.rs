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
    /// The rustdoc command and its arguments, everything that appeared
    /// after the `--` separator.
    child_args: Vec<String>,
}

impl WrapperArgs {
    /// Parse command line arguments.
    fn parse() -> Self {
        let mut test_metadata_path: Option<String> = None;
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
            } else {
                eprintln!("Unknown wrapper flag: {}", arg);
                exit(1);
            }
        }

        Self {
            test_metadata_path,
            child_args,
        }
    }
}

/// Extracts the human-readable test names from rustdoc's stdout.
///
/// rustdoc prints one `test <name> ... <status>` line per doc test when
/// invoked with `--test`. We don't care about `<status>` here (the binaries
/// haven't been run yet — `--no-run` is in effect); we only need `<name>`,
/// which has the form `<file> - <item> (line <n>)`.
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
/// input doesn't match the expected `<file> - <item> (line <n>)` shape we
/// fall back to a plain alphanumeric sanitization of the whole name.
fn mangle_test_name(human_name: &str, counts: &mut HashMap<(String, String), usize>) -> String {
    if let Some((file_and_item, line_part)) = human_name.rsplit_once(" (line ") {
        if let Some(line_num) = line_part.strip_suffix(')') {
            if let Some((file_path, _)) = file_and_item.split_once(" - ") {
                let mangled: String = file_path
                    .chars()
                    .map(|c| if c.is_ascii_alphanumeric() { c } else { '_' })
                    .collect();
                // Macro expansion can produce multiple doc tests that share
                // the same source file and line. rustdoc assigns each one a
                // sequential suffix in the order it emits them, so we mirror
                // that here to keep the mangled name in sync with the
                // persisted directory name.
                let key = (mangled.clone(), line_num.to_string());
                let index = counts.entry(key).or_insert(0);
                let result = format!("{}_{}_{}", mangled, line_num, *index);
                *index += 1;
                return result;
            }
        }
    }
    human_name
        .chars()
        .map(|c| if c.is_ascii_alphanumeric() { c } else { '_' })
        .collect()
}

/// Writes the `<mangled-dir-name>=<human-name>` mapping consumed by
/// `rustdoc_test_runner`.
///
/// Lines are sorted by mangled name (via `BTreeSet`) to keep the output
/// stable across builds, even though the per-(file, line) suffixes
/// themselves are still assigned in rustdoc-emit order. Write failures are
/// intentionally swallowed — the runner falls back to using the directory
/// name as the test name if the metadata file is missing or malformed.
fn write_test_metadata(path: &str, stdout: &str) {
    let names = parse_test_names(stdout);
    let mut counts: HashMap<(String, String), usize> = HashMap::new();
    let entries: BTreeSet<(String, &str)> = names
        .iter()
        .map(|name| (mangle_test_name(name, &mut counts), name.as_str()))
        .collect();

    let mut content = String::new();
    for (mangled, human) in &entries {
        content.push_str(mangled);
        content.push('=');
        content.push_str(human);
        content.push('\n');
    }
    let _ = fs::write(path, content);
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
        eprintln!("Usage: rustdoc_compile_wrapper [--test-metadata FILE] -- <command> [args...]");
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
        let stdout_str = String::from_utf8_lossy(&stdout_buf);
        write_test_metadata(path, &stdout_str);
    }

    let code = status.code().unwrap_or(1);
    if !debug && (code != 0 || has_warning) && !stdout_buf.is_empty() {
        let _ = io::stderr().write_all(&stdout_buf);
    }

    exit(code);
}
