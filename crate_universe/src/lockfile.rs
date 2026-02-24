//! Utility module for interacting with the cargo-bazel lockfile.

use std::collections::BTreeMap;
use std::ffi::OsStr;
use std::fs;
use std::path::Path;
use std::process::Command;

use anyhow::{bail, Context as AnyhowContext, Result};
use hex::ToHex;
use once_cell::sync::OnceCell;
use regex::Regex;
use serde::{Deserialize, Serialize};
use sha2::{Digest as Sha2Digest, Sha256};

use crate::config::Config;
use crate::context::Context;
use crate::metadata::Cargo;
use crate::splicing::{SplicingManifest, SplicingMetadata};

pub(crate) fn lock_context(
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
pub(crate) fn write_lockfile(lockfile: Context, path: &Path, dry_run: bool) -> Result<()> {
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
pub(crate) struct Digest(String);

impl Digest {
    pub(crate) fn new(
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

    /// A helper for generating a hash and logging it's contents.
    fn compute_single_hash(data: &str, id: &str) -> String {
        let mut hasher = Sha256::new();
        hasher.update(data.as_bytes());
        hasher.update(b"\0");
        let hash = hasher.finalize().encode_hex::<String>();
        tracing::debug!("{} hash: {}", id, hash);
        hash
    }

    /// Normalize canonical Bazel labels in a JSON string for stable digest computation.
    ///
    /// The canonical name of a repository changes depending on whether it is used as the
    /// root workspace/module or as a dependency:
    ///
    /// - bzlmod root:     `@@//package:target`
    /// - bzlmod non-root: `@@module_name+//package:target`
    /// - WORKSPACE root:  `@@//package:target` (or `//package:target`)
    /// - WORKSPACE dep:   `@@repo_name//package:target`
    ///
    /// To ensure the lockfile digest is stable across these contexts (so that a lockfile
    /// generated when a module is root remains valid when the module is used as a
    /// non-root dependency), we normalize all canonical labels by stripping the
    /// repository name component, treating `@@repo_name//` the same as `@@//`.
    fn normalize_labels_for_digest(json: &str) -> std::borrow::Cow<'_, str> {
        static RE: OnceCell<Regex> = OnceCell::new();
        let re = RE.get_or_init(|| {
            // Match canonical labels (@@...) with a non-empty repository name followed by //.
            // The repository name is matched by [^/"]+ (one or more chars that are not / or ").
            // This handles both bzlmod (@@module_name+//) and WORKSPACE (@@repo_name//) forms.
            // This does NOT match @@// (root form, empty repo name) since [^/"]+ requires at
            // least one character.
            Regex::new(r#"@@[^/"]+//"#).expect("valid regex")
        });
        re.replace_all(json, "@@//")
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

        hasher.update(Digest::compute_single_hash(
            cargo_bazel_version,
            "cargo-bazel version",
        ));
        hasher.update(b"\0");

        // The lockfile context (typically `cargo-bazel-lock.json`).
        hasher.update(Digest::compute_single_hash(
            &serde_json::to_string(context).unwrap(),
            "lockfile context",
        ));
        hasher.update(b"\0");

        // This content is generated by various attributes in Bazel rules and written to a file behind the scenes.
        // Labels are normalized to strip bzlmod canonical repository names so the digest is stable
        // regardless of whether the module is used as a root module or a non-root dependency.
        hasher.update(Digest::compute_single_hash(
            &Self::normalize_labels_for_digest(&serde_json::to_string(config).unwrap()),
            "workspace config",
        ));
        hasher.update(b"\0");

        // Data collected about Cargo manifests and configs that feed into dependency generation. This file
        // is also generated by Bazel behind the scenes based on user inputs.
        // Labels are normalized for the same reason as the workspace config above.
        hasher.update(Digest::compute_single_hash(
            &Self::normalize_labels_for_digest(&serde_json::to_string(splicing_metadata).unwrap()),
            "splicing manifest",
        ));
        hasher.update(b"\0");

        hasher.update(Digest::compute_single_hash(cargo_version, "Cargo version"));
        hasher.update(b"\0");

        hasher.update(Digest::compute_single_hash(rustc_version, "Rustc version"));
        hasher.update(b"\0");

        let hash = hasher.finalize().encode_hex::<String>();
        tracing::debug!("Digest hash: {}", hash);

        Self(hash)
    }

    pub(crate) fn bin_version(binary: &Path) -> Result<String> {
        let safe_vars = [
            OsStr::new("HOME"),
            OsStr::new("HOMEDRIVE"),
            OsStr::new("PATHEXT"),
            OsStr::new("NIX_LD"),
            OsStr::new("NIX_LD_LIBRARY_PATH"),
        ];
        let env = std::env::vars_os().filter(|(var, _)| safe_vars.contains(&var.as_os_str()));

        let output = Command::new(binary)
            .arg("--version")
            .env_clear()
            .envs(env)
            .output()
            .with_context(|| format!("Failed to run {} to get its version", binary.display()))?;

        if !output.status.success() {
            eprintln!("{}", String::from_utf8_lossy(&output.stdout));
            eprintln!("{}", String::from_utf8_lossy(&output.stderr));
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
    use crate::config::{CrateAnnotations, CrateNameAndVersionReq};
    use crate::splicing::cargo_config::{AdditionalRegistry, CargoConfig, Registry};
    use crate::utils::target_triple::TargetTriple;

    use super::*;

    use std::collections::BTreeSet;

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
            Digest("edd73970897c01af3bb0e6c9d62f572203dd38a03c189dcca555d463990aa086".to_owned()),
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
                CrateNameAndVersionReq::new("rustonomicon".to_owned(), "1.0.0".parse().unwrap()),
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
                TargetTriple::from_bazel("wasm32-wasip1".to_owned()),
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
            Digest("8a4c1b3bb4c2d6c36e27565e71a13d54cff9490696a492c66a3a37bdd3893edf".to_owned()),
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
            Digest("1e01331686ba1f26f707dc098cd9d21c39d6ccd8e46be03329bb2470d3833e15".to_owned()),
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
            Digest("45ccf7109db2d274420fac521f4736a1fb55450ec60e6df698e1be4dc2c89fad".to_owned()),
            digest,
        );
    }

    #[test]
    fn digest_stable_with_crlf_cargo_config() {
        let context = Context::default();
        let splicing_metadata = SplicingMetadata::default();

        let json_config = |cargo_config: &str| {
            serde_json::to_string(&serde_json::json!({
                "generate_binaries": false,
                "generate_build_scripts": false,
                "cargo_config": cargo_config,
                "rendering": {
                    "repository_name": "test",
                    "regen_command": "//test",
                    "generate_cargo_toml_env_vars": true
                }
            }))
            .unwrap()
        };

        let config_crlf: Config = serde_json::from_str(&json_config(
            "[registries.my-registry]\r\nindex = \"sparse+https://example.com/\"",
        ))
        .unwrap();

        let config_lf: Config = serde_json::from_str(&json_config(
            "[registries.my-registry]\nindex = \"sparse+https://example.com/\"",
        ))
        .unwrap();

        let digest_crlf = Digest::compute(
            &context,
            &config_crlf,
            &splicing_metadata,
            "0.1.0",
            "cargo 1.57.0 (b2e52d7ca 2021-10-21)",
            "rustc 1.57.0 (f1edd0429 2021-11-29)",
        );

        let digest_lf = Digest::compute(
            &context,
            &config_lf,
            &splicing_metadata,
            "0.1.0",
            "cargo 1.57.0 (b2e52d7ca 2021-10-21)",
            "rustc 1.57.0 (f1edd0429 2021-11-29)",
        );

        assert_eq!(
            digest_crlf, digest_lf,
            "Digests should be identical regardless of CRLF vs LF line endings in cargo_config"
        );
    }

    #[test]
    fn digest_stable_for_root_vs_non_root_module() {
        // Verifies that the digest is stable when labels in the config use different
        // canonical forms depending on whether the module is root (@@//) or a non-root
        // dependency (@@module_name+//). See: https://github.com/bazelbuild/rules_rust/issues/3521
        let context = Context::default();
        let splicing_metadata = SplicingMetadata::default();

        let make_config = |patch_label: &str| -> Config {
            Config {
                annotations: BTreeMap::from([(
                    CrateNameAndVersionReq::new("some_crate".to_owned(), "1.0.0".parse().unwrap()),
                    CrateAnnotations {
                        patches: Some(BTreeSet::from([patch_label.to_owned()])),
                        ..CrateAnnotations::default()
                    },
                )]),
                ..Config::default()
            }
        };

        // Same patch label in root vs non-root bzlmod context
        let config_root = make_config("@@//patches/my_crate.patch");
        let config_non_root = make_config("@@module1+//patches/my_crate.patch");

        let digest_root = Digest::compute(
            &context,
            &config_root,
            &splicing_metadata,
            "0.1.0",
            "cargo 1.57.0 (b2e52d7ca 2021-10-21)",
            "rustc 1.57.0 (f1edd0429 2021-11-29)",
        );

        let digest_non_root = Digest::compute(
            &context,
            &config_non_root,
            &splicing_metadata,
            "0.1.0",
            "cargo 1.57.0 (b2e52d7ca 2021-10-21)",
            "rustc 1.57.0 (f1edd0429 2021-11-29)",
        );

        assert_eq!(
            digest_root, digest_non_root,
            "Digests should be identical for root (@@//...) and non-root (@@module_name+//...) module contexts"
        );
    }

    #[test]
    fn digest_stable_for_workspace_root_vs_dep() {
        // Verifies that the digest is stable in legacy WORKSPACE mode, where labels also
        // change canonical form when the workspace transitions from root to an external dep:
        // - Root workspace:    @@//package:target
        // - External workspace dep: @@repo_name//package:target  (no "+" suffix unlike bzlmod)
        let context = Context::default();
        let splicing_metadata = SplicingMetadata::default();

        let make_config = |patch_label: &str| -> Config {
            Config {
                annotations: BTreeMap::from([(
                    CrateNameAndVersionReq::new("some_crate".to_owned(), "1.0.0".parse().unwrap()),
                    CrateAnnotations {
                        patches: Some(BTreeSet::from([patch_label.to_owned()])),
                        ..CrateAnnotations::default()
                    },
                )]),
                ..Config::default()
            }
        };

        // Same patch label in WORKSPACE root vs external dep context (no "+" in repo name)
        let config_root = make_config("@@//patches/my_crate.patch");
        let config_dep = make_config("@@my_workspace//patches/my_crate.patch");

        let digest_root = Digest::compute(
            &context,
            &config_root,
            &splicing_metadata,
            "0.1.0",
            "cargo 1.57.0 (b2e52d7ca 2021-10-21)",
            "rustc 1.57.0 (f1edd0429 2021-11-29)",
        );

        let digest_dep = Digest::compute(
            &context,
            &config_dep,
            &splicing_metadata,
            "0.1.0",
            "cargo 1.57.0 (b2e52d7ca 2021-10-21)",
            "rustc 1.57.0 (f1edd0429 2021-11-29)",
        );

        assert_eq!(
            digest_root, digest_dep,
            "Digests should be identical for WORKSPACE root (@@//...) and dep (@@repo_name//...) contexts"
        );
    }
}
