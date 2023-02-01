use crate::splicing::SourceInfo;
use anyhow::{Context, Result};
use crates_index::IndexConfig;
use hex::ToHex;

pub enum CrateIndexLookup {
    Git(crates_index::Index),
    Http(crates_index::SparseIndex),
}

impl CrateIndexLookup {
    pub fn get_source_info(&self, pkg: &cargo_lock::Package) -> Result<Option<SourceInfo>> {
        let index_config = self
            .index_config()
            .context("Failed to get crate index config")?;
        let crate_ = match self {
            // The crates we care about should all be in the cache already,
            // because `cargo metadata` ran which should have fetched them.
            Self::Http(index) => Some(
                index
                    .crate_from_cache(pkg.name.as_str())
                    .with_context(|| format!("Failed to get crate from cache for {pkg:?}"))?,
            ),
            Self::Git(index) => index.crate_(pkg.name.as_str()),
        };
        let source_info = crate_.and_then(|crate_idx| {
            crate_idx
                .versions()
                .iter()
                .find(|v| v.version() == pkg.version.to_string())
                .and_then(|v| {
                    v.download_url(&index_config).map(|url| {
                        let sha256 = pkg
                            .checksum
                            .as_ref()
                            .and_then(|sum| sum.as_sha256().map(|sum| sum.encode_hex::<String>()))
                            .unwrap_or_else(|| v.checksum().encode_hex::<String>());
                        SourceInfo { url, sha256 }
                    })
                })
        });
        Ok(source_info)
    }

    fn index_config(&self) -> Result<IndexConfig, crates_index::Error> {
        match self {
            Self::Git(index) => index.index_config(),
            Self::Http(index) => index.index_config(),
        }
    }
}
