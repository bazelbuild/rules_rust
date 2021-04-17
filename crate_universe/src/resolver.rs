use std::{
    borrow::Cow,
    collections::{BTreeMap, BTreeSet, HashMap},
    path::{Path, PathBuf},
    process::Stdio,
};

use anyhow::Context;
use cargo_metadata::{DependencyKind, Metadata, MetadataCommand};
use cargo_raze::{
    context::CrateContext,
    metadata::RazeMetadataFetcher,
    planning::{BuildPlanner, BuildPlannerImpl},
    settings::{GenMode, RazeSettings},
};
use log::trace;
use semver::{Version, VersionReq};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use url::Url;

use crate::{
    consolidator::{Consolidator, ConsolidatorConfig, ConsolidatorOverride},
    renderer::RenderConfig,
    NamedTempFile,
};

pub struct ResolverConfig {
    pub cargo: PathBuf,
    pub index_url: Url,
}

pub struct Resolver {
    pub toml: toml::Value,
    pub resolver_config: ResolverConfig,
    pub consolidator_config: ConsolidatorConfig,
    pub render_config: RenderConfig,
    pub target_triples: Vec<String>,
    pub label_to_crates: BTreeMap<String, BTreeSet<String>>,
    digest: Option<String>,
}

// TODO: Interesting edge cases
// - you can pass deps using: version number path on fs, git repo.
// - you can rename crates you depend on.
pub struct ResolvedArtifactsWithMetadata {
    pub resolved_packages: Vec<CrateContext>,
    pub member_packages_version_mapping: HashMap<String, Version>,
}

#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
pub struct Dependencies {
    pub normal: BTreeMap<String, Version>,
    pub build: BTreeMap<String, Version>,
    pub dev: BTreeMap<String, Version>,
}

impl Resolver {
    pub fn new(
        toml: toml::Value,
        resolver_config: ResolverConfig,
        consolidator_config: ConsolidatorConfig,
        render_config: RenderConfig,
        target_triples: Vec<String>,
        label_to_crates: BTreeMap<String, BTreeSet<String>>,
    ) -> Resolver {
        Resolver {
            toml,
            resolver_config,
            consolidator_config,
            render_config,
            target_triples,
            label_to_crates,
            digest: None,
        }
    }

    pub fn digest(&mut self) -> anyhow::Result<String> {
        // TODO: Ignore * .cargo config files outside of the workspace

        if self.digest.is_none() {
            // TODO: Combine values better
            let mut hasher = Sha256::new();
            // Mix in the version of this crate, which encompasses all logic and templates.
            // This is probably a wild over-estimate of what should go in the cache key.
            // NOTE: In debug mode, this mixes the digest of the executable, rather than the version number.
            hasher.update(version_for_hashing()?);
            hasher.update(b"\0");

            // If new fields are added, you should decide whether they need hashing.
            // Hint: They probably do. If not, please add a comment justifying why not.
            let Self {
                toml,
                render_config:
                    RenderConfig {
                        repo_rule_name,
                        crate_registry_template,
                        rules_rust_workspace_name,
                    },
                consolidator_config: ConsolidatorConfig { overrides },
                resolver_config: ResolverConfig { cargo, index_url },

                // This is what we're computing.
                digest: _ignored,
                target_triples,
                label_to_crates,
            } = &self;

            hasher.update(repo_rule_name.as_str().as_bytes());
            hasher.update(b"\0");
            hasher.update(crate_registry_template.as_str().as_bytes());
            hasher.update(b"\0");
            hasher.update(rules_rust_workspace_name.as_bytes());
            hasher.update(b"\0");

            hasher.update(get_cargo_version(&cargo)?);
            hasher.update(b"\0");
            hasher.update(index_url.as_str().as_bytes());
            hasher.update(b"\0");
            for target_triple in target_triples {
                hasher.update(target_triple);
                hasher.update(b"\0");
            }
            hasher.update(b"\0");
            for (label, crates) in label_to_crates.iter() {
                hasher.update(label.as_bytes());
                hasher.update(b"\0");
                for krate in crates.iter() {
                    hasher.update(krate.as_bytes());
                    hasher.update(b"\0");
                }
            }

            // TODO: improve the caching by generating a lockfile over the resolve rather than over
            // the render. If the digest contains only input for the cargo dependency resolution
            // then we don't need to re-pin when making changes to things that only affect the
            // generated bazel file.
            for (
                crate_name,
                ConsolidatorOverride {
                    extra_rustc_env_vars,
                    extra_build_script_env_vars,
                    extra_bazel_deps,
                    extra_bazel_data_deps,
                    extra_build_script_bazel_deps,
                    extra_build_script_bazel_data_deps,
                    features_to_remove,
                },
            ) in overrides
            {
                hasher.update(crate_name);
                hasher.update(b"\0");
                for (env_key, env_val) in extra_rustc_env_vars {
                    hasher.update(env_key);
                    hasher.update(b"\0");
                    hasher.update(env_val);
                    hasher.update(b"\0");
                }
                for (env_key, env_val) in extra_build_script_env_vars {
                    hasher.update(env_key);
                    hasher.update(b"\0");
                    hasher.update(env_val);
                    hasher.update(b"\0");
                }
                for dep_map in &[
                    extra_bazel_deps,
                    extra_bazel_data_deps,
                    extra_build_script_bazel_deps,
                    extra_build_script_bazel_data_deps,
                ] {
                    for (target, deps) in *dep_map {
                        hasher.update(target);
                        hasher.update(b"\0");
                        for dep in deps {
                            hasher.update(dep);
                            hasher.update(b"\0");
                        }
                    }
                }
                for feature in features_to_remove {
                    hasher.update(feature);
                    hasher.update(b"\n");
                }
            }

            for (env_name, env_value) in std::env::vars() {
                // The CARGO_HOME variable changes where cargo writes and reads config, and caches.
                // We currently use the user's Cargo home (by not overwriting it) so we should
                // allow users to use a custom path to one.
                if env_name == "CARGO_HOME" {
                    continue;
                }
                if env_name == "CARGO" {
                    continue;
                }
                if env_name == "RUSTC" {
                    continue;
                }
                // We hope that other env vars don't cause problems...
                if env_name.starts_with("CARGO") && env_name != "CARGO_NET_GIT_FETCH_WITH_CLI" {
                    eprintln!("Warning: You have the {} environment variable set - this may affect your crate_universe output", env_name);
                    hasher.update(env_name);
                    hasher.update(b"\0");
                    hasher.update(env_value);
                    hasher.update(b"\0");
                }
            }

            hasher.update(toml.to_string().as_bytes());
            hasher.update(b"\0");

            // TODO: Include all files referenced by the toml.
            self.digest = Some(hex::encode(hasher.finalize()));
        }
        // UNWRAP: Guaranteed by above code.
        Ok(self.digest.clone().unwrap())
    }

    pub fn resolve(mut self) -> anyhow::Result<Consolidator> {
        let toml_str = self.toml.to_string();
        trace!("Resolving for generated Cargo.toml:\n{}", toml_str);
        let merged_cargo_toml = NamedTempFile::with_str_content("Cargo.toml", &toml_str)
            .context("Writing intermediate Cargo.toml")?;

        // RazeMetadataFetcher only uses the scheme+host+port of this URL.
        // If it used the path, we'd run into issues escaping the {s and }s from the template,
        // but the scheme+host+port should be fine.
        let crate_registry_template_url = Url::parse(&self.render_config.crate_registry_template)
            .context("Parsing repository template URL")?;
        let md_fetcher = RazeMetadataFetcher::new(
            &self.resolver_config.cargo,
            crate_registry_template_url,
            self.resolver_config.index_url.clone(),
        );
        let metadata = md_fetcher
            .fetch_metadata(merged_cargo_toml.path().parent().unwrap(), None, None)
            .context("Failed fetching metadata")?;

        let raze_settings = RazeSettings {
            gen_workspace_prefix: self.render_config.repo_rule_name.clone(),
            genmode: GenMode::Remote,

            // TODO: These are ?all ignored
            workspace_path: "".to_string(),
            package_aliases_dir: "".to_string(),
            render_package_aliases: false,
            target: None,
            targets: Some(self.target_triples.clone()),
            crates: HashMap::default(),
            output_buildfile_suffix: "".to_string(),
            default_gen_buildrs: true,
            registry: self.render_config.crate_registry_template.clone(),
            index_url: self.resolver_config.index_url.as_str().to_owned(),
            rust_rules_workspace_name: self.render_config.rules_rust_workspace_name.clone(),
            vendor_dir: "".to_string(),
            experimental_api: false,
        };

        let planner = BuildPlannerImpl::new(metadata, raze_settings);

        let planned_build = planner.plan_build(None).context("Failed planning build")?;

        let mut resolved_packages = planned_build.crate_contexts;
        resolved_packages
            .sort_by(|l, r| (&l.pkg_name, &l.pkg_version).cmp(&(&r.pkg_name, &r.pkg_version)));

        let member_packages_version_mapping =
            self.get_member_packages_version_mapping(merged_cargo_toml.path(), &resolved_packages);

        // TODO: generate a cargo toml from metadata in the bazel rule, when no cargo toml is present.

        let digest = self.digest().context("Digesting Resolver inputs")?;
        Ok(Consolidator::new(
            self.consolidator_config,
            self.render_config,
            digest,
            self.target_triples,
            resolved_packages,
            member_packages_version_mapping?,
            self.label_to_crates,
        ))
    }

    fn get_member_packages_version_mapping(
        &self,
        merged_cargo_toml: &Path,
        resolved_artifacts: &[CrateContext],
    ) -> anyhow::Result<Dependencies> {
        let merged_cargo_metadata = MetadataCommand::new()
            .cargo_path(&self.resolver_config.cargo)
            .manifest_path(merged_cargo_toml)
            .no_deps()
            .exec()
            .context("Failed to run cargo metadata")?;

        Ok(Dependencies {
            normal: Self::build_version_mapping_for_kind(
                DependencyKind::Normal,
                &merged_cargo_metadata,
                resolved_artifacts,
            ),
            build: Self::build_version_mapping_for_kind(
                DependencyKind::Build,
                &merged_cargo_metadata,
                resolved_artifacts,
            ),
            dev: Self::build_version_mapping_for_kind(
                DependencyKind::Development,
                &merged_cargo_metadata,
                resolved_artifacts,
            ),
        })
    }

    fn build_version_mapping_for_kind(
        kind: DependencyKind,
        merged_cargo_metadata: &Metadata,
        resolved_artifacts: &[CrateContext],
    ) -> BTreeMap<String, Version> {
        // Build the intersection of version requirements for all the member (i.e. toplevel) packages
        // of our workspace.
        let mut member_package_version_reqs: HashMap<String, Vec<VersionReq>> = Default::default();
        for package in &merged_cargo_metadata.packages {
            for dep in &package.dependencies {
                if dep.kind == kind {
                    member_package_version_reqs
                        .entry(dep.name.clone())
                        .or_default()
                        .push(dep.req.clone());
                }
            }
        }

        let mut member_package_version_mapping = BTreeMap::new();
        for package in resolved_artifacts {
            // If the package name matches one of the member packages' direct dependencies, consider it
            // for the final version: insert it into the map if we didn't have one yet, take the highest
            // version so far if there was already one.
            if let Some(version_req) = member_package_version_reqs.get(&package.pkg_name) {
                if version_req
                    .iter()
                    .all(|req| req.matches(&package.pkg_version))
                {
                    let current_pkg_version = member_package_version_mapping
                        .entry(package.pkg_name.clone())
                        .or_insert_with(|| Version::new(0, 0, 0));
                    if *current_pkg_version < package.pkg_version {
                        *current_pkg_version = package.pkg_version.clone();
                    }
                }
            }
        }
        member_package_version_mapping
    }
}

fn get_cargo_version(cargo_path: &Path) -> anyhow::Result<Vec<u8>> {
    let output = std::process::Command::new(cargo_path)
        .arg("--version")
        .stderr(Stdio::inherit())
        .output()
        .context("Invoking cargo --version")?;
    if !output.status.success() {
        panic!(
            "TODO: cargo --version failed with exit code {:?}",
            output.status.code()
        );
    }
    Ok(output.stdout)
}

fn version_for_hashing() -> anyhow::Result<Cow<'static, [u8]>> {
    if cfg!(debug_assertions) {
        let current_exe =
            std::env::current_exe().context("Couldn't get current executable path")?;
        Ok(Cow::Owned(
            std::fs::read(current_exe).context("Couldn't read current executable path")?,
        ))
    } else {
        Ok(Cow::Borrowed(env!("CARGO_PKG_VERSION").as_bytes()))
    }
}
