//! Exec-redirect shim that bridges a stable workspace-relative path
//! in the committed settings file (`${workspaceFolder}/.rules_rust_analyzer/<name>.exe`)
//! to the user-specific Bazel-cache path of the real toolchain binary.
//! `setup vscode` copies this binary into the launcher dir once per
//! logical name and writes the sidecar JSON it dispatches against.
//!
//! `.exe` everywhere is required by Node's `child_process.spawn` on
//! Windows (no `shell: true`, no PATHEXT lookup) and harmless on POSIX
//! (kernel ignores file extensions for `execve`). See
//! [`gen_rust_project_lib::DISCOVER_BINARY_FILENAME`] for the same
//! decision on the discover/flycheck side.

use std::{
    collections::HashMap,
    env, fs,
    path::{Path, PathBuf},
    process,
};

const PATHS_FILENAME: &str = "launcher_paths.json";

fn main() {
    let exe = env::current_exe().unwrap_or_else(|e| die(format!("locating current_exe: {e}")));
    let logical = logical_name(&exe)
        .unwrap_or_else(|| die(format!("current_exe has no file stem: {}", exe.display())));
    let paths_path = exe
        .parent()
        .unwrap_or_else(|| die(format!("current_exe has no parent: {}", exe.display())))
        .join(PATHS_FILENAME);
    let target = resolve_target(&paths_path, &logical)
        .unwrap_or_else(|e| die(format!("resolving {logical}: {e}")));
    exec_replace(&target);
}

fn logical_name(exe: &Path) -> Option<String> {
    exe.file_stem().map(|s| s.to_string_lossy().into_owned())
}

/// Borrows strings out of `raw` to skip per-entry heap allocations on
/// the LSP-startup hot path.
fn resolve_target(paths_path: &Path, logical: &str) -> Result<PathBuf, String> {
    let raw = fs::read_to_string(paths_path)
        .map_err(|e| format!("reading {}: {e}", paths_path.display()))?;
    let map: HashMap<&str, &str> =
        serde_json::from_str(&raw).map_err(|e| format!("parsing {}: {e}", paths_path.display()))?;
    map.get(logical)
        .map(PathBuf::from)
        .ok_or_else(|| format!("no entry for `{logical}` in {}", paths_path.display()))
}

#[cfg(unix)]
fn exec_replace(target: &Path) -> ! {
    use std::os::unix::process::CommandExt;
    let err = process::Command::new(target)
        .args(env::args_os().skip(1))
        .exec();
    die(format!("exec {}: {err}", target.display()))
}

#[cfg(not(unix))]
fn exec_replace(target: &Path) -> ! {
    let status = process::Command::new(target)
        .args(env::args_os().skip(1))
        .status()
        .unwrap_or_else(|e| die(format!("spawn {}: {e}", target.display())));
    process::exit(status.code().unwrap_or(1));
}

fn die(msg: String) -> ! {
    eprintln!("rules_rust launcher: {msg}");
    process::exit(127);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn logical_name_strips_exe_suffix() {
        assert_eq!(
            logical_name(Path::new("/x/rust_analyzer.exe")).as_deref(),
            Some("rust_analyzer")
        );
    }

    #[test]
    fn logical_name_passes_through_when_no_suffix() {
        assert_eq!(
            logical_name(Path::new("/x/rustfmt")).as_deref(),
            Some("rustfmt")
        );
    }

    #[test]
    fn resolve_target_returns_mapped_path() {
        let tmp = std::env::temp_dir().join(format!("launcher_resolve_ok_{}", process::id()));
        let _ = fs::remove_dir_all(&tmp);
        fs::create_dir_all(&tmp).unwrap();
        let paths = tmp.join(PATHS_FILENAME);
        fs::write(
            &paths,
            r#"{"rust_analyzer": "/abs/rust-analyzer", "rustfmt": "/abs/rustfmt"}"#,
        )
        .unwrap();
        let out = resolve_target(&paths, "rust_analyzer").unwrap();
        assert_eq!(out, PathBuf::from("/abs/rust-analyzer"));
        let _ = fs::remove_dir_all(&tmp);
    }

    #[test]
    fn resolve_target_errors_on_missing_key_with_path_context() {
        let tmp = std::env::temp_dir().join(format!("launcher_resolve_miss_{}", process::id()));
        let _ = fs::remove_dir_all(&tmp);
        fs::create_dir_all(&tmp).unwrap();
        let paths = tmp.join(PATHS_FILENAME);
        fs::write(&paths, r#"{"rust_analyzer": "/abs/rust-analyzer"}"#).unwrap();
        let err = resolve_target(&paths, "rustfmt").unwrap_err();
        assert!(err.contains("rustfmt"), "{err}");
        assert!(err.contains(PATHS_FILENAME), "{err}");
        let _ = fs::remove_dir_all(&tmp);
    }
}
