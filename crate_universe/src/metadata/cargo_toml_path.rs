use anyhow::{anyhow, Result};
use camino::{Utf8Path, Utf8PathBuf};
use serde::{Deserialize, Serialize};
use std::fmt;
use std::fmt::Display;
use std::path::Path;

/// Path that is know to end with `/Cargo.toml`.
#[derive(Eq, PartialEq, Debug, Clone, Hash, Ord, PartialOrd, Serialize, Deserialize)]
#[serde(transparent)]
pub(crate) struct CargoTomlPath(Utf8PathBuf);

impl Display for CargoTomlPath {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        Display::fmt(&self.0, f)
    }
}

impl CargoTomlPath {
    pub(crate) fn unchecked_new(path: impl Into<Utf8PathBuf>) -> Self {
        CargoTomlPath(path.into())
    }

    pub(crate) fn new(path: impl Into<Utf8PathBuf>) -> Result<Self> {
        let path = path.into();
        if !path.ends_with("Cargo.toml") {
            return Err(anyhow!("Path does not end with Cargo.toml: {path}"));
        }
        Ok(Self::unchecked_new(path))
    }

    pub(crate) fn for_dir(dir: impl Into<Utf8PathBuf>) -> Self {
        let mut path = dir.into();
        path.push("Cargo.toml");
        CargoTomlPath::unchecked_new(path)
    }

    /// Directory of `Cargo.toml` path.
    pub(crate) fn parent(&self) -> &Utf8Path {
        self.0.parent().expect("Validated in constructor")
    }

    pub(crate) fn ancestors(&self) -> impl Iterator<Item = &Utf8Path> {
        self.0.ancestors()
    }

    pub(crate) fn as_path(&self) -> &Utf8Path {
        self.0.as_path()
    }

    pub(crate) fn as_std_path(&self) -> &Path {
        self.0.as_std_path()
    }
}

impl AsRef<Path> for CargoTomlPath {
    fn as_ref(&self) -> &Path {
        self.0.as_ref()
    }
}
