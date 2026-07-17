use std::env;
use std::fs;
use std::path::Path;
use std::process::ExitCode;

#[cfg(target_family = "windows")]
const PATH_ENV_SEP: char = ';';

#[cfg(not(target_family = "windows"))]
const PATH_ENV_SEP: char = ':';

const MARKERS_ENV: &str = "RUST_LINT_TEST_MARKERS";

fn main() -> ExitCode {
    let raw = env::var(MARKERS_ENV).unwrap_or_default();
    let entries: Vec<&str> = raw.split(PATH_ENV_SEP).filter(|s| !s.is_empty()).collect();

    if entries.is_empty() {
        println!("No lint outputs to report.");
        return ExitCode::SUCCESS;
    }

    let runfiles = match runfiles::Runfiles::create() {
        Ok(r) => r,
        Err(err) => {
            eprintln!("Failed to locate runfiles: {err}");
            return ExitCode::FAILURE;
        }
    };

    let mut failed = false;
    for rlocation in &entries {
        let Some(path) = runfiles::rlocation!(runfiles, rlocation) else {
            eprintln!("Missing runfile: {rlocation}");
            failed = true;
            continue;
        };

        match classify(&path) {
            (Verdict::Pass, _) => println!("PASS {}", path.display()),
            (Verdict::Fail(reason), contents) => {
                eprintln!("FAIL {} — {reason}", path.display());
                if let Some(text) = contents {
                    if !text.trim().is_empty() {
                        eprintln!("--- {} ---\n{text}\n--- end ---", path.display());
                    }
                }
                failed = true;
            }
        }
    }

    if failed { ExitCode::FAILURE } else { ExitCode::SUCCESS }
}

enum Verdict {
    Pass,
    Fail(&'static str),
}

enum Kind {
    Marker,      // .clippy.ok / .rustfmt.ok — presence is success.
    ClippyOut,   // .clippy.out — captured stderr; non-empty means clippy had something to say.
    Diagnostics, // .clippy.diagnostics — JSON stream; warning/error entries mean failure.
    Unknown,
}

fn kind_of(path: &Path) -> Kind {
    let name = path.file_name().and_then(|s| s.to_str()).unwrap_or("");
    if name.ends_with(".clippy.ok") || name.ends_with(".rustfmt.ok") {
        Kind::Marker
    } else if name.ends_with(".clippy.out") {
        Kind::ClippyOut
    } else if name.ends_with(".clippy.diagnostics") {
        Kind::Diagnostics
    } else {
        Kind::Unknown
    }
}

/// Decide whether a collected lint artifact represents pass or fail.
///
/// Both `capture_clippy_output` and `clippy_output_diagnostics` make clippy
/// exit 0 even on real issues (via `--cap-lints=warn`), so we inspect file
/// contents rather than presence. Returns the file contents on failure so
/// callers can print them without re-reading from disk.
fn classify(path: &Path) -> (Verdict, Option<String>) {
    match kind_of(path) {
        Kind::Marker => (Verdict::Pass, None),
        Kind::ClippyOut => match fs::read_to_string(path) {
            Ok(text) if text.trim().is_empty() => (Verdict::Pass, None),
            Ok(text) => (
                Verdict::Fail("clippy stderr is non-empty (capture_clippy_output masks the exit code)"),
                Some(text),
            ),
            Err(_) => (Verdict::Fail("failed to read captured clippy stderr"), None),
        },
        Kind::Diagnostics => match fs::read_to_string(path) {
            Ok(text) if text.lines().any(is_diagnostic_json_line) => (
                Verdict::Fail("clippy diagnostics contain warning/error entries (cap_at_warnings masks the exit code)"),
                Some(text),
            ),
            Ok(_) => (Verdict::Pass, None),
            Err(_) => (Verdict::Fail("failed to read clippy diagnostics"), None),
        },
        Kind::Unknown => {
            eprintln!("warning: unrecognized lint artifact {}", path.display());
            (Verdict::Pass, None)
        }
    }
}

/// rustc emits compact newline-separated JSON (no whitespace between tokens);
/// a real diagnostic has `"level":"warning"` or `"level":"error"` as a
/// top-level field. Notes / help entries use other levels and are ignored.
fn is_diagnostic_json_line(line: &str) -> bool {
    line.contains(r#""level":"warning""#) || line.contains(r#""level":"error""#)
}
