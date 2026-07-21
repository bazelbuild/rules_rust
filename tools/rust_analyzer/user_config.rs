//! Per-user, per-workspace runtime settings for the rust-analyzer
//! integration. Lives in `<launcher_dir>/user_config.json` (inside
//! the gitignored launcher dir). `setup` writes it; `discover` and
//! `flycheck` read it. Malformed → defaults + warning, so an
//! unreadable file doesn't blow up the LSP.

use std::fs;

use anyhow::{Context, Result};
use camino::{Utf8Path, Utf8PathBuf};
use serde::{Deserialize, Serialize};

/// Filename inside `<launcher_dir>` that holds the per-user config.
pub const USER_CONFIG_FILENAME: &str = "user_config.json";

impl Default for UserConfig {
    fn default() -> Self {
        Self {
            clippy: false,
            // Whole-workspace mode blew RA memory to 46 GB on a
            // 713-crate workspace; per-package keeps it cargo-scoped.
            per_package_workspaces: true,
            output_base: None,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(default)]
pub struct UserConfig {
    /// Run clippy on save alongside rustc. See `bin/flycheck.rs`.
    pub clippy: bool,

    /// Focus discover on the saved file's package instead of the whole
    /// workspace. See `Default` for why this defaults to `true`.
    pub per_package_workspaces: bool,

    /// Override for flycheck's `--output_base`. `None` derives the
    /// server location from the sidecar's `output_base` with an
    /// `_rra` suffix, so flycheck's server sits next to the primary
    /// one under the same `output_user_root`. The `--output_base` CLI
    /// flag wins for one-off overrides.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub output_base: Option<Utf8PathBuf>,
}

/// Read `<launcher_dir>/user_config.json`. Missing or malformed →
/// defaults (with a warning for malformed).
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

/// Write `<launcher_dir>/user_config.json`, creating the launcher
/// dir if it's missing.
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
    // Edition 2018 doesn't put `TryFrom` in the prelude.
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
        assert!(!config.clippy);
        assert!(config.per_package_workspaces);
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn roundtrip_preserves_all_fields() {
        let dir = tmp_dir("roundtrip");
        let original = UserConfig {
            clippy: true,
            per_package_workspaces: true,
            output_base: Some(Utf8PathBuf::from("/tmp/custom_flycheck_base")),
        };
        save(&dir, &original).unwrap();
        let loaded = load(&dir);
        assert_eq!(loaded, original);
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn absent_output_base_stays_none() {
        // `skip_serializing_if` keeps the key out of the default file.
        let dir = tmp_dir("absent_output_base");
        save(&dir, &UserConfig::default()).unwrap();
        let text = fs::read_to_string(dir.join(USER_CONFIG_FILENAME)).unwrap();
        assert!(
            !text.contains("output_base"),
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
        // Older file that only has `clippy` set must not fail when a
        // new key is added, and picks up the new default.
        let dir = tmp_dir("partial");
        fs::write(dir.join(USER_CONFIG_FILENAME), br#"{"clippy": true}"#).unwrap();
        let config = load(&dir);
        assert!(config.clippy);
        assert!(config.per_package_workspaces);
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn explicit_false_in_file_is_preserved() {
        // `--no-per-package-workspaces` written before the default
        // flipped must still deserialize as `false`.
        let dir = tmp_dir("explicit_false");
        fs::write(
            dir.join(USER_CONFIG_FILENAME),
            br#"{"per_package_workspaces": false}"#,
        )
        .unwrap();
        let config = load(&dir);
        assert!(!config.per_package_workspaces);
        let _ = fs::remove_dir_all(&dir);
    }
}
