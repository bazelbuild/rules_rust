use std::{
    collections::{BTreeMap, BTreeSet, HashMap},
    path::PathBuf,
};

use semver::VersionReq;
use serde::{Deserialize, Serialize};
use url::Url;

use crate::{
    consolidator::{ConsolidatorConfig, ConsolidatorOverride},
    parser::merge_cargo_tomls,
    renderer::RenderConfig,
    resolver::{Resolver, ResolverConfig},
};

#[derive(Debug, Deserialize, Serialize, Ord, Eq, PartialOrd, PartialEq)]
pub struct Package {
    pub name: String,
    pub semver: VersionReq,
    pub features: Vec<String>,
}

#[derive(Debug, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct Override {
    // Mapping of environment variables key -> value.
    pub extra_rustc_env_vars: BTreeMap<String, String>,
    // Mapping of environment variables key -> value.
    pub extra_build_script_env_vars: BTreeMap<String, String>,
    // Mapping of target triple or spec -> extra bazel target dependencies.
    pub extra_bazel_deps: BTreeMap<String, Vec<String>>,
    // Mapping of target triple or spec -> extra bazel target data dependencies.
    pub extra_bazel_data_deps: BTreeMap<String, Vec<String>>,
    // Mapping of target triple or spec -> extra bazel target build script dependencies.
    pub extra_build_script_bazel_deps: BTreeMap<String, Vec<String>>,
    // Mapping of target triple or spec -> extra bazel target build script data dependencies.
    pub extra_build_script_bazel_data_deps: BTreeMap<String, Vec<String>>,
    // Features to remove from crates (e.g. which are needed when building with Cargo but not with Bazel).
    pub features_to_remove: BTreeSet<String>,
}

// Options which affect the contents of the generated output should be on this struct.
// These fields all end up hashed into the lockfile hash.
//
// Anything which doesn't affect the contents of the generated output should live on `Opt` in `main.rs`.
#[derive(Debug, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct Config {
    pub repository_name: String,

    pub packages: Vec<Package>,
    pub cargo_toml_files: BTreeMap<String, PathBuf>,
    pub overrides: HashMap<String, Override>,

    /// Template of the URL from which to download crates, which are assumed to be gzip'd tar files.
    /// This string may contain arbitrarily many instances of {crate} and {version} which will be
    /// replaced by crate names and versions.
    pub crate_registry_template: String,

    pub target_triples: Vec<String>,
    pub cargo: PathBuf,

    #[serde(default = "default_rules_rust_workspace_name")]
    pub rust_rules_workspace_name: String,
    #[serde(default = "default_index_url")]
    pub index_url: Url,
}

impl Config {
    pub fn preprocess(mut self) -> anyhow::Result<Resolver> {
        self.packages.sort();

        let (toml_contents, label_to_crates) =
            merge_cargo_tomls(self.cargo_toml_files, self.packages)?;

        let overrides = self
            .overrides
            .into_iter()
            .map(|(krate, overryde)| {
                (
                    krate,
                    ConsolidatorOverride {
                        extra_rustc_env_vars: overryde.extra_rustc_env_vars,
                        extra_build_script_env_vars: overryde.extra_build_script_env_vars,
                        extra_bazel_deps: overryde.extra_bazel_deps,
                        extra_build_script_bazel_deps: overryde.extra_build_script_bazel_deps,
                        extra_bazel_data_deps: overryde.extra_bazel_data_deps,
                        extra_build_script_bazel_data_deps: overryde
                            .extra_build_script_bazel_data_deps,
                        features_to_remove: overryde.features_to_remove,
                    },
                )
            })
            .collect();

        Ok(Resolver::new(
            toml_contents.into(),
            ResolverConfig {
                cargo: self.cargo,
                index_url: self.index_url,
            },
            ConsolidatorConfig { overrides },
            RenderConfig {
                repo_rule_name: self.repository_name.clone(),
                crate_registry_template: self.crate_registry_template.clone(),
                rules_rust_workspace_name: self.rust_rules_workspace_name.clone(),
            },
            self.target_triples,
            label_to_crates,
        ))
    }
}

// TODO: maybe remove the "+buildmetadata" suffix to consolidate e.g. "1.2.3+foo" and "1.2.3".
/// Generate the repo rule name from the target like cargo-raze.
/// e.g. `0.18.0-alpha.2+test` -> `0_18_0_alpha_2_test`.
pub fn crate_to_repo_rule_name(repo_rule_name: &str, name: &str, version: &str) -> String {
    format!(
        "{repo_rule_name}__{name}__{version}",
        repo_rule_name = repo_rule_name,
        name = name.replace("-", "_"),
        version = version
            .replace(".", "_")
            .replace("+", "_")
            .replace("-", "_")
    )
}

pub fn crate_to_label(repo_rule_name: &str, crate_name: &str, crate_version: &str) -> String {
    format!(
        "@{repo_name}//:{name}",
        repo_name = crate_to_repo_rule_name(repo_rule_name, crate_name, crate_version),
        name = crate_name.replace("-", "_")
    )
}

pub fn default_rules_rust_workspace_name() -> String {
    String::from("rules_rust")
}

pub fn default_index_url() -> Url {
    Url::parse("https://github.com/rust-lang/crates.io-index").expect("Invalid default index URL")
}
