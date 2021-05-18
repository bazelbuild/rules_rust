use std::path::{Path, PathBuf};

use std::io::Write;

pub mod config;
pub mod consolidator;
pub mod context;
pub mod error;
pub mod metadata;
pub mod parser;
pub mod planning;
pub mod renderer;
pub mod resolver;
mod serde_utils;
pub mod settings;
pub mod util;

#[cfg(test)]
mod testing;

pub struct NamedTempFile(tempfile::TempDir, PathBuf);

impl NamedTempFile {
    pub fn with_str_content<P: AsRef<Path>>(name: P, content: &str) -> std::io::Result<Self> {
        let dir = tempfile::tempdir()?;
        let path = dir.path().join(name.as_ref());
        let mut file = std::fs::File::create(&path)?;
        write!(file, "{}", content)?;
        Ok(Self(dir, path))
    }
    pub fn path(&self) -> &Path {
        &self.1
    }
}
