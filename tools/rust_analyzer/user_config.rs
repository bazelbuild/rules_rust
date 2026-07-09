//! Per-user, per-workspace runtime settings for the rust-analyzer
//! integration.
//!
//! Rendered into `<launcher_dir>/user_config.json`. This file lives
//! inside the launcher dir (e.g. `.vscode/.rules_rust_analyzer/`),
//! which is gitignored — so nothing here leaks into the shared
//! `settings.json` / `.code-workspace`. `setup`'s CLI flags mutate
//! the file; `discover` and `flycheck` read it on every invocation.
//!
//! Deliberately serialized as PRETTY JSON (with a trailing newline)
//! so users editing the file by hand see one key per line and can
//! diff it sanely if they check it in on a fork.
//!
//! `load` treats a missing file as all-defaults; a malformed file
//! also falls back to defaults with a warning, since blowing up the
//! LSP over a syntax error the user can't see in their editor is a
//! worse experience than "clippy silently didn't turn on".

use std::fs;

use anyhow::{Context, Result};
use camino::{Utf8Path, Utf8PathBuf};
use serde::{Deserialize, Serialize};

/// Filename inside `<launcher_dir>` that holds the per-user config.
pub const USER_CONFIG_FILENAME: &str = "user_config.json";

#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(default)]
pub struct UserConfig {
    /// Run clippy on save and stream its JSON diagnostics alongside
    /// rustc's. See `bin/flycheck.rs`.
    pub clippy: bool,

    /// Ask discover to focus on the saved file's package instead of
    /// re-emitting the whole workspace. See the `--per-package-workspaces`
    /// docs in `bin/setup.rs`.
    pub per_package_workspaces: bool,

    /// Override for flycheck's inner `--output_user_root`. Escape
    /// hatch for platform-specific concerns (Windows MAX_PATH, atypical
    /// cache layouts) — `None` lets `bin/flycheck.rs` pick a per-
    /// workspace directory next to Bazel's normal cache. The
    /// `--output_user_root` CLI flag on flycheck still wins over this
    /// for one-off overrides.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub output_user_root: Option<Utf8PathBuf>,
}

/// Read `<launcher_dir>/user_config.json`. Missing → defaults;
/// malformed → defaults + warning (see module docs for rationale).
pub fn load(launcher_dir: &Utf8Path) -> UserConfig {
    let path = launcher_dir.join(USER_CONFIG_FILENAME);
    let text = match fs::read_to_string(&path) {
        Ok(t) => t,
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => return UserConfig::default(),
        Err(e) => {
            log::warn!("user_config: reading {path}: {e}; falling back to defaults");
            return UserConfig::default();
        }
    };
    match serde_json::from_str::<UserConfig>(&text) {
        Ok(config) => config,
        Err(e) => {
            log::warn!("user_config: parsing {path}: {e}; falling back to defaults");
            UserConfig::default()
        }
    }
}

/// Write `<launcher_dir>/user_config.json`. Creates the launcher
/// dir if it's missing (setup does that too, but this keeps `save`
/// safe to call in isolation from tests).
pub fn save(launcher_dir: &Utf8Path, config: &UserConfig) -> Result<()> {
    fs::create_dir_all(launcher_dir)
        .with_context(|| format!("creating launcher dir {launcher_dir}"))?;
    let path = launcher_dir.join(USER_CONFIG_FILENAME);
    let mut text = serde_json::to_string_pretty(config)
        .with_context(|| format!("serializing user_config for {path}"))?;
    text.push('\n');
    fs::write(&path, text).with_context(|| format!("writing {path}"))?;
    Ok(())
}

#[cfg(test)]
mod tests {
    // Edition 2018 doesn't put `TryFrom` in the prelude, but the tests
    // use `Utf8PathBuf::try_from` to convert `std::path::PathBuf`
    // returned by `std::env::temp_dir()`.
    use std::convert::TryFrom;

    use super::*;
    use camino::Utf8PathBuf;

    fn tmp_dir(tag: &str) -> Utf8PathBuf {
        let dir = std::env::temp_dir().join(format!(
            "rules_rust_ra_user_config_{}_{}",
            tag,
            std::process::id()
        ));
        let _ = fs::remove_dir_all(&dir);
        fs::create_dir_all(&dir).unwrap();
        Utf8PathBuf::try_from(dir).unwrap()
    }

    #[test]
    fn missing_file_returns_defaults() {
        let dir = tmp_dir("missing");
        let config = load(&dir);
        assert_eq!(config, UserConfig::default());
        // Sanity: defaults must be all-false so first-run users don't
        // implicitly opt into anything.
        assert!(!config.clippy);
        assert!(!config.per_package_workspaces);
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn roundtrip_preserves_all_fields() {
        let dir = tmp_dir("roundtrip");
        let original = UserConfig {
            clippy: true,
            per_package_workspaces: true,
            output_user_root: Some(Utf8PathBuf::from("/tmp/custom_flycheck_root")),
        };
        save(&dir, &original).unwrap();
        let loaded = load(&dir);
        assert_eq!(loaded, original);
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn absent_output_user_root_stays_none() {
        // `skip_serializing_if` keeps the key out of the file so the
        // default JSON stays minimal. Round-tripping a `None` produces
        // a file with no `output_user_root` field.
        let dir = tmp_dir("absent_output_user_root");
        save(&dir, &UserConfig::default()).unwrap();
        let text = fs::read_to_string(dir.join(USER_CONFIG_FILENAME)).unwrap();
        assert!(
            !text.contains("output_user_root"),
            "unset field should be omitted, got:\n{}",
            text,
        );
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn malformed_file_falls_back_to_defaults() {
        let dir = tmp_dir("malformed");
        fs::write(dir.join(USER_CONFIG_FILENAME), b"{not valid json").unwrap();
        let config = load(&dir);
        assert_eq!(config, UserConfig::default());
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn partial_file_uses_defaults_for_missing_keys() {
        // Forward-compat: an older file that only has `clippy` set
        // must not fail when a new key is added.
        let dir = tmp_dir("partial");
        fs::write(dir.join(USER_CONFIG_FILENAME), br#"{"clippy": true}"#).unwrap();
        let config = load(&dir);
        assert!(config.clippy);
        assert!(!config.per_package_workspaces);
        let _ = fs::remove_dir_all(&dir);
    }
}
