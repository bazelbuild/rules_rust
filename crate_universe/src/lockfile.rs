//! Utility module for interracting with different kinds of lock files

use std::collections::BTreeMap;
use std::convert::TryFrom;
use std::ffi::OsStr;
use std::fs;
use std::path::Path;
use std::process::Command;

use anyhow::{bail, Context as AnyhowContext, Result};
use hex::ToHex;
use serde::{Deserialize, Serialize};
use sha2::{Digest as Sha2Digest, Sha256};

use crate::config::Config;
use crate::context::Context;
use crate::metadata::Cargo;
use crate::splicing::{SplicingManifest, SplicingMetadata};

pub fn lock_context(
    mut context: Context,
    config: &Config,
    splicing_manifest: &SplicingManifest,
    cargo_bin: &Cargo,
    rustc_bin: &Path,
) -> Result<Context> {
    // Ensure there is no existing checksum which could impact the lockfile results
    context.checksum = None;

    let checksum = Digest::new(&context, config, splicing_manifest, cargo_bin, rustc_bin)
        .context("Failed to generate context digest")?;

    Ok(Context {
        checksum: Some(checksum),
        ..context
    })
}

/// Write a [crate::context::Context] to disk
pub fn write_lockfile(lockfile: Context, path: &Path, dry_run: bool) -> Result<()> {
    let content = serde_json::to_string_pretty(&lockfile)?;

    if dry_run {
        println!("{content:#?}");
    } else {
        // Ensure the parent directory exists
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent)?;
        }
        fs::write(path, content + "\n")
            .context(format!("Failed to write file to disk: {}", path.display()))?;
    }

    Ok(())
}

#[derive(Debug, Serialize, Deserialize, PartialEq, Eq, PartialOrd, Ord, Clone)]
pub struct Digest(String);

impl Digest {
    pub fn new(
        context: &Context,
        config: &Config,
        splicing_manifest: &SplicingManifest,
        cargo_bin: &Cargo,
        rustc_bin: &Path,
    ) -> Result<Self> {
        let splicing_metadata = SplicingMetadata::try_from((*splicing_manifest).clone())?;
        let cargo_version = cargo_bin.full_version()?;
        let rustc_version = Self::bin_version(rustc_bin)?;
        let cargo_bazel_version = env!("CARGO_PKG_VERSION");

        // Ensure the checksum of a digest is not present before computing one
        Ok(match context.checksum {
            Some(_) => Self::compute(
                &Context {
                    checksum: None,
                    ..context.clone()
                },
                config,
                &splicing_metadata,
                cargo_bazel_version,
                &cargo_version,
                &rustc_version,
            ),
            None => Self::compute(
                context,
                config,
                &splicing_metadata,
                cargo_bazel_version,
                &cargo_version,
                &rustc_version,
            ),
        })
    }

    fn compute(
        context: &Context,
        config: &Config,
        splicing_metadata: &SplicingMetadata,
        cargo_bazel_version: &str,
        cargo_version: &str,
        rustc_version: &str,
    ) -> Self {
        // Since this method is private, it should be expected that context is
        // always None. This then allows us to have this method not return a
        // Result.
        debug_assert!(context.checksum.is_none());

        let mut hasher = Sha256::new();

        hasher.update(cargo_bazel_version.as_bytes());
        hasher.update(b"\0");

        hasher.update(serde_json::to_string(context).unwrap().as_bytes());
        hasher.update(b"\0");

        hasher.update(serde_json::to_string(config).unwrap().as_bytes());
        hasher.update(b"\0");

        hasher.update(serde_json::to_string(splicing_metadata).unwrap().as_bytes());
        hasher.update(b"\0");

        hasher.update(cargo_version.as_bytes());
        hasher.update(b"\0");

        hasher.update(rustc_version.as_bytes());
        hasher.update(b"\0");

        Self(hasher.finalize().encode_hex::<String>())
    }

    pub fn bin_version(binary: &Path) -> Result<String> {
        let safe_vars = [OsStr::new("HOMEDRIVE"), OsStr::new("PATHEXT")];
        let env = std::env::vars_os().filter(|(var, _)| safe_vars.contains(&var.as_os_str()));

        let output = Command::new(binary)
            .arg("--version")
            .env_clear()
            .envs(env)
            .output()
            .with_context(|| format!("Failed to run {} to get its version", binary.display()))?;

        if !output.status.success() {
            bail!("Failed to query cargo version")
        }

        let version = String::from_utf8(output.stdout)?.trim().to_owned();

        // TODO: There is a bug in the linux binary for Cargo 1.60.0 where
        // the commit hash reported by the version is shorter than what's
        // reported on other platforms. This conditional here is a hack to
        // correct for this difference and ensure lockfile hashes can be
        // computed consistently. If a new binary is released then this
        // condition should be removed
        // https://github.com/rust-lang/cargo/issues/10547
        let corrections = BTreeMap::from([
            (
                "cargo 1.60.0 (d1fd9fe 2022-03-01)",
                "cargo 1.60.0 (d1fd9fe2c 2022-03-01)",
            ),
            (
                "cargo 1.61.0 (a028ae4 2022-04-29)",
                "cargo 1.61.0 (a028ae42f 2022-04-29)",
            ),
        ]);

        if corrections.contains_key(version.as_str()) {
            Ok(corrections[version.as_str()].to_string())
        } else {
            Ok(version)
        }
    }
}

impl PartialEq<str> for Digest {
    fn eq(&self, other: &str) -> bool {
        self.0 == other
    }
}

impl PartialEq<String> for Digest {
    fn eq(&self, other: &String) -> bool {
        &self.0 == other
    }
}

#[cfg(test)]
mod test {
    use crate::config::{CrateAnnotations, CrateId};
    use crate::splicing::cargo_config::{AdditionalRegistry, CargoConfig, Registry};
    use crate::utils::target_triple::TargetTriple;

    use super::*;

    use std::collections::{BTreeMap, BTreeSet};

    #[test]
    fn simple_digest() {
        let context = Context::default();
        let config = Config::default();
        let splicing_metadata = SplicingMetadata::default();

        let digest = Digest::compute(
            &context,
            &config,
            &splicing_metadata,
            "0.1.0",
            "cargo 1.57.0 (b2e52d7ca 2021-10-21)",
            "rustc 1.57.0 (f1edd0429 2021-11-29)",
        );

        assert_eq!(
            Digest("379610c3d0f58778cb066f51da66894f10d0e7ea903e4621c61534b4d1344e6f".to_owned()),
            digest,
        );
    }

    #[test]
    fn digest_with_config() {
        let context = Context::default();
        let config = Config {
            generate_binaries: false,
            generate_build_scripts: false,
            annotations: BTreeMap::from([(
                CrateId::new("rustonomicon".to_owned(), "1.0.0".to_owned()),
                CrateAnnotations {
                    compile_data_glob: Some(BTreeSet::from(["arts/**".to_owned()])),
                    ..CrateAnnotations::default()
                },
            )]),
            cargo_config: None,
            supported_platform_triples: BTreeSet::from([
                TargetTriple::from_bazel("aarch64-apple-darwin".to_owned()),
                TargetTriple::from_bazel("aarch64-unknown-linux-gnu".to_owned()),
                TargetTriple::from_bazel("aarch64-pc-windows-msvc".to_owned()),
                TargetTriple::from_bazel("wasm32-unknown-unknown".to_owned()),
                TargetTriple::from_bazel("wasm32-wasi".to_owned()),
                TargetTriple::from_bazel("x86_64-apple-darwin".to_owned()),
                TargetTriple::from_bazel("x86_64-pc-windows-msvc".to_owned()),
                TargetTriple::from_bazel("x86_64-unknown-freebsd".to_owned()),
                TargetTriple::from_bazel("x86_64-unknown-linux-gnu".to_owned()),
            ]),
            ..Config::default()
        };

        let splicing_metadata = SplicingMetadata::default();

        let digest = Digest::compute(
            &context,
            &config,
            &splicing_metadata,
            "0.1.0",
            "cargo 1.57.0 (b2e52d7ca 2021-10-21)",
            "rustc 1.57.0 (f1edd0429 2021-11-29)",
        );

        assert_eq!(
            Digest("c4d5c9def86c1af758a29f144d8d9ab66b1c762d36f878d1e7f9b6e09782c512".to_owned()),
            digest,
        );
    }

    #[test]
    fn digest_with_splicing_metadata() {
        let context = Context::default();
        let config = Config::default();
        let splicing_metadata = SplicingMetadata {
            direct_packages: BTreeMap::from([(
                "rustonomicon".to_owned(),
                cargo_toml::DependencyDetail {
                    version: Some("1.0.0".to_owned()),
                    ..cargo_toml::DependencyDetail::default()
                },
            )]),
            manifests: BTreeMap::new(),
            cargo_config: None,
        };

        let digest = Digest::compute(
            &context,
            &config,
            &splicing_metadata,
            "0.1.0",
            "cargo 1.57.0 (b2e52d7ca 2021-10-21)",
            "rustc 1.57.0 (f1edd0429 2021-11-29)",
        );

        assert_eq!(
            Digest("ab158c3dd56e1771bfaed167c661f9c6c33f1effdf6d870f80640384ad1bffaf".to_owned()),
            digest,
        );
    }

    #[test]
    fn digest_with_cargo_config() {
        let context = Context::default();
        let config = Config::default();
        let cargo_config = CargoConfig {
            registries: BTreeMap::from([
                (
                    "art-crates-remote".to_owned(),
                    AdditionalRegistry {
                        index: "https://artprod.mycompany/artifactory/git/cargo-remote.git"
                            .to_owned(),
                        token: None,
                    },
                ),
                (
                    "crates-io".to_owned(),
                    AdditionalRegistry {
                        index: "https://github.com/rust-lang/crates.io-index".to_owned(),
                        token: None,
                    },
                ),
            ]),
            registry: Registry {
                default: "art-crates-remote".to_owned(),
                token: None,
            },
            source: BTreeMap::new(),
        };

        let splicing_metadata = SplicingMetadata {
            cargo_config: Some(cargo_config),
            ..SplicingMetadata::default()
        };

        let digest = Digest::compute(
            &context,
            &config,
            &splicing_metadata,
            "0.1.0",
            "cargo 1.57.0 (b2e52d7ca 2021-10-21)",
            "rustc 1.57.0 (f1edd0429 2021-11-29)",
        );

        assert_eq!(
            Digest("b707269f173b2f78ae500317f9ae54df3c05c88972531c277045d0eb756fc681".to_owned()),
            digest,
        );
    }
}
