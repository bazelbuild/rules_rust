//! On-save flycheck wrapper invoked by rust-analyzer.
//!
//! rust-analyzer's flycheck runnable spawns this with the saved file's
//! owning Bazel label and (optionally) the saved file path. We then:
//!
//!   1. Invoke `bazel build <label>` with rustc diagnostics turned on and
//!      `--build_event_json_file=<tmp>` so BEP can tell us where rustc
//!      wrote its JSON output.
//!   2. Parse BEP for the `rustc_output` output group, collecting every
//!      `.rustc-output` artifact produced by the build (one per rust
//!      action — bin, lib, test compilations are all separate).
//!   3. Concatenate the JSON contents to stdout for rust-analyzer to
//!      render as inline diagnostics.
//!
//! `--keep_going` keeps Bazel building even when rustc emits errors so all
//! diagnostics surface in one pass. The wrapper always emits whatever
//! `.rustc-output` files exist and forwards Bazel's exit code so
//! rust-analyzer can distinguish "build succeeded" from "build itself
//! failed" (e.g. BUILD-file syntax error).

use std::{
    env, fs,
    io::{self, Write},
    process::{Command, ExitCode},
};

use anyhow::{Context, Result};
use camino::{Utf8Path, Utf8PathBuf};
use clap::Parser;
use gen_rust_project_lib::bep;
use serde_json::Value;

#[derive(Parser, Debug)]
#[command(about = "rust-analyzer flycheck wrapper backed by `bazel build`")]
struct Args {
    /// Bazel label of the crate whose owning file rust-analyzer just saved.
    label: String,

    /// The file rust-analyzer just saved. Currently unused — we check the
    /// whole crate, matching cargo check's per-crate semantics. Accepted
    /// so the runnable template's `{saved_file}` placeholder has somewhere
    /// to land without errors.
    #[clap(default_value = "")]
    saved_file: String,

    /// Path to the bazel binary.
    #[clap(long, default_value = "bazel")]
    bazel: Utf8PathBuf,

    /// Bazel `--output_user_root` for the flycheck server. Overrides
    /// the default (`<install_dir>/output_user_root`, derived from
    /// `current_exe()`). Useful on Windows where MAX_PATH limits make
    /// the in-launcher-dir default impractical.
    #[clap(long)]
    output_user_root: Option<Utf8PathBuf>,
}

fn main() -> ExitCode {
    env_logger::init();
    match run() {
        Ok(code) => ExitCode::from(code),
        Err(e) => {
            eprintln!("flycheck: {e:#}");
            ExitCode::from(1)
        }
    }
}

fn run() -> Result<u8> {
    let args = Args::parse();

    let workspace = workspace_dir()?;

    let temp_dir = Utf8PathBuf::try_from(env::temp_dir()).context("$TMPDIR was not valid UTF-8")?;
    let bep_path = temp_dir.join(format!("flycheck_bep_{}.json", std::process::id()));
    let _bep_cleanup = scopeguard(bep_path.clone());

    // Dedicated `--output_user_root` for the inner `bazel build` so
    // its `--error_format=json` / `--rustc_output_diagnostics=true`
    // don't thrash the user's primary Bazel server's analysis cache.
    // CLI override exists for Windows MAX_PATH cases where the
    // sibling default is too long.
    let output_user_root = match args.output_user_root.clone() {
        Some(p) => p,
        None => gen_rust_project_lib::install_dir()?.join("output_user_root"),
    };
    std::fs::create_dir_all(&output_user_root)
        .with_context(|| format!("creating output_user_root {output_user_root}"))?;

    let status = Command::new(args.bazel.as_str())
        .current_dir(&workspace)
        // BUILD_WORKSPACE_DIRECTORY / BUILD_WORKING_DIRECTORY leak in from
        // the outer `bazel run` invocation and would confuse the nested
        // bazel client; clear them so the nested call rediscovers the
        // workspace from cwd.
        .env_remove("BAZELISK_SKIP_WRAPPER")
        .env_remove("BUILD_WORKING_DIRECTORY")
        .env_remove("BUILD_WORKSPACE_DIRECTORY")
        // `--output_user_root` is a STARTUP option — must precede the
        // command (`build`). Bazel rejects it elsewhere.
        .arg(format!("--output_user_root={output_user_root}"))
        .arg("build")
        .arg(&args.label)
        // `error_format=json` makes rustc emit machine-readable diagnostics
        // and tells process_wrapper to capture them verbatim; without it the
        // `.rustc-output` files are pre-rendered ANSI strings that
        // rust-analyzer can't parse.
        .arg("--@rules_rust//rust/settings:error_format=json")
        .arg("--@rules_rust//rust/settings:rustc_output_diagnostics=true")
        .arg(format!("--output_groups=+{}", bep::RUSTC_OUTPUT_GROUP))
        .arg("--keep_going")
        .arg(format!("--build_event_json_file={bep_path}"))
        .status()
        .with_context(|| format!("invoking {}", args.bazel))?;

    let stderr_files = match bep::parse_action_stderr_paths(&bep_path) {
        Ok(paths) => paths,
        Err(e) => {
            eprintln!("flycheck: parsing BEP failed: {e:#}");
            Vec::new()
        }
    };

    emit_diagnostics(&stderr_files, &workspace)?;

    // Forward Bazel's exit code so rust-analyzer can tell apart "build
    // succeeded with diagnostics" from "build tool itself broke".
    Ok(status.code().unwrap_or(1) as u8)
}

/// Stream each action-stderr file to stdout, keeping only lines that look
/// like rustc JSON messages. For each diagnostic line, recursively rewrite
/// `file_name` fields to absolute paths anchored at the workspace root —
/// rustc emits them relative to the Bazel exec root (structurally the
/// workspace layout), and rust-analyzer otherwise tries to resolve them
/// relative to the saved file's directory, producing nonsense like
/// `<workspace>/util/label/util/label/label.rs`.
///
/// Non-JSON lines (sandbox warnings, env dumps) are dropped so the LSP
/// only sees parseable rustc messages.
///
/// Errors writing to stdout bubble up — rust-analyzer parses our stdout
/// as the diagnostic stream, so silently dropping writes would surface as
/// "no squiggles after save" with no clue why. A failed write is almost
/// always "rust-analyzer closed the pipe" which is also worth surfacing
/// (the editor is gone; flycheck has no consumer).
fn emit_diagnostics(files: &[Utf8PathBuf], workspace: &Utf8Path) -> Result<()> {
    let stdout = io::stdout();
    let mut out = stdout.lock();
    for path in files {
        let content = match fs::read_to_string(path) {
            Ok(c) => c,
            Err(e) => {
                log::warn!("could not read {path}: {e}");
                continue;
            }
        };
        for line in content.lines() {
            let trimmed = line.trim_start();
            if !trimmed.starts_with('{') {
                continue;
            }
            match serde_json::from_str::<Value>(trimmed) {
                Ok(mut value) => {
                    absolutize_file_names(&mut value, workspace);
                    serde_json::to_writer(&mut out, &value)
                        .context("writing rewritten rustc JSON to stdout")?;
                    out.write_all(b"\n").context("writing newline to stdout")?;
                }
                Err(_) => {
                    // Not strict JSON — pass through unmodified so we don't
                    // silently drop a diagnostic format we don't recognize.
                    out.write_all(line.as_bytes())
                        .context("passing through non-JSON line to stdout")?;
                    out.write_all(b"\n").context("writing newline to stdout")?;
                }
            }
        }
    }
    out.flush().context("flushing stdout")?;
    Ok(())
}

/// Walk a rustc-diagnostic JSON value and rewrite every `"file_name"`
/// string field to an absolute path under `workspace`. file_name appears
/// in `spans[*].file_name`, in nested `expansion.span.file_name` chains
/// for macro expansions, and inside `children[*].spans[*]…` for
/// sub-diagnostics — recursion catches all of them.
fn absolutize_file_names(value: &mut Value, workspace: &Utf8Path) {
    match value {
        Value::Object(map) => {
            for (key, child) in map.iter_mut() {
                if key == "file_name" {
                    if let Value::String(s) = child {
                        if !s.is_empty() && !std::path::Path::new(s).is_absolute() {
                            *s = workspace.join(&*s).to_string();
                        }
                    }
                } else {
                    absolutize_file_names(child, workspace);
                }
            }
        }
        Value::Array(items) => {
            for item in items.iter_mut() {
                absolutize_file_names(item, workspace);
            }
        }
        _ => {}
    }
}

fn workspace_dir() -> Result<Utf8PathBuf> {
    if let Ok(dir) = env::var("BUILD_WORKSPACE_DIRECTORY") {
        return Utf8PathBuf::try_from(std::path::PathBuf::from(dir))
            .context("BUILD_WORKSPACE_DIRECTORY was not valid UTF-8");
    }
    let cwd = env::current_dir().context("current_dir")?;
    Utf8PathBuf::try_from(cwd).context("current_dir was not valid UTF-8")
}

/// Best-effort cleanup of the temporary BEP file.
fn scopeguard(path: Utf8PathBuf) -> impl Drop {
    struct Guard(Utf8PathBuf);
    impl Drop for Guard {
        fn drop(&mut self) {
            let _ = fs::remove_file(&self.0);
        }
    }
    Guard(path)
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn relative_file_names_become_absolute() {
        let workspace = Utf8Path::new("/abs/ws");
        let mut v = json!({
            "$message_type": "diagnostic",
            "spans": [
                {"file_name": "util/label/label.rs", "byte_start": 0},
                {"file_name": "/already/absolute.rs", "byte_start": 1},
                {
                    "file_name": "src/lib.rs",
                    "expansion": {
                        "span": {"file_name": "src/macro.rs"}
                    }
                }
            ],
            "children": [
                {"spans": [{"file_name": "src/inner.rs"}]}
            ]
        });
        absolutize_file_names(&mut v, workspace);
        // Construct expected paths via Utf8Path::join so the test passes on
        // both POSIX and Windows (Windows uses `\` as the separator).
        let expect = |rel: &str| Value::String(workspace.join(rel).to_string());
        let spans = v["spans"].as_array().unwrap();
        assert_eq!(spans[0]["file_name"], expect("util/label/label.rs"));
        // Absolute paths must be left untouched.
        assert_eq!(spans[1]["file_name"], json!("/already/absolute.rs"));
        assert_eq!(spans[2]["file_name"], expect("src/lib.rs"));
        // Recursive descent reaches the expansion span.
        assert_eq!(
            spans[2]["expansion"]["span"]["file_name"],
            expect("src/macro.rs"),
        );
        // And children's spans.
        assert_eq!(
            v["children"][0]["spans"][0]["file_name"],
            expect("src/inner.rs"),
        );
    }

    #[test]
    fn empty_file_name_is_left_alone() {
        let workspace = Utf8Path::new("/ws");
        let mut v = json!({"spans": [{"file_name": ""}]});
        absolutize_file_names(&mut v, workspace);
        assert_eq!(v["spans"][0]["file_name"], json!(""));
    }
}
