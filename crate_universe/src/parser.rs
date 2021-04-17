use std::{
    collections::{BTreeMap, BTreeSet},
    convert::{TryFrom, TryInto},
    fs::read_to_string,
    path::PathBuf,
};

use anyhow::{anyhow, Context};
use indoc::indoc;
use log::*;
use semver::{Version, VersionReq};
use serde::{Deserialize, Deserializer};
use toml::Value;

use crate::config::Package as AdditionalPackage;

#[derive(Debug, Deserialize)]
// We deny unknown fields so that when new fields are encountered, we need to explicitly decide
// whether they affect dependency resolution or not.
// For our first few users, this will be annoying, but it's hopefully worth it for the correctness.
#[serde(deny_unknown_fields)]
pub struct CargoToml {
    pub package: Package,
    pub dependencies: BTreeMap<String, DepSpec>,
    #[serde(rename = "build-dependencies", default = "BTreeMap::new")]
    pub build_dependencies: BTreeMap<String, DepSpec>,
    #[serde(rename = "dev-dependencies", default = "BTreeMap::new")]
    pub dev_dependencies: BTreeMap<String, DepSpec>,

    #[serde(default = "BTreeMap::new")]
    pub patch: BTreeMap<String, BTreeMap<String, DepSpec>>,

    #[serde(flatten)]
    _ignored: Option<Ignored>,
}

#[derive(Debug, Deserialize)]
// Allows unknown fields - we assume everything in Package doesn't affect dependency resolution.
pub struct Package {
    pub name: String,
    pub version: Version,
}

#[derive(Debug, PartialEq, Eq)]
pub struct DepSpec {
    pub default_features: bool,
    pub features: BTreeSet<String>,
    pub version: VersionSpec,
}

#[derive(Debug, PartialEq, Eq)]
pub enum VersionSpec {
    Semver(VersionReq),
    Git {
        url: String,
        rev: Option<String>,
        tag: Option<String>,
    },
    Local(PathBuf),
}

/// Fields in the top-level CargoToml which are ignored.
/// Only add new fields here if you are certain they cannot affect dependency resolution.
/// Cargo.toml docs: https://doc.rust-lang.org/cargo/reference/manifest.html
#[derive(Debug, Deserialize)]
struct Ignored {
    // Target tables
    lib: serde::de::IgnoredAny,
    bin: serde::de::IgnoredAny,
    example: serde::de::IgnoredAny,
    test: serde::de::IgnoredAny,
    bench: serde::de::IgnoredAny,
    profile: serde::de::IgnoredAny,

    // Other
    features: serde::de::IgnoredAny,
    badges: serde::de::IgnoredAny,
    // Not ignored:
    // replace: deprecated alternative to patch, use patch instead.
    // cargo-features: unstable nightly features, evaluate on a case-by-case basis.
    // workspace: TODO: support cargo workspaces.
    // target: TODO: support platform-specific dependencies.
}

pub fn merge_cargo_tomls(
    label_to_path: BTreeMap<String, PathBuf>,
    packages: Vec<AdditionalPackage>,
) -> anyhow::Result<(CargoToml, BTreeMap<String, BTreeSet<String>>)> {
    let mut merged_cargo_toml: CargoToml = indoc! { r#"
    [package]
    name = "dummy_package_for_crate_universe_resolver"
    version = "0.1.0"

    [lib]
    path = "doesnotexist.rs"

    [dependencies]
    "# }
    .try_into()?;

    let mut labels_to_deps = BTreeMap::new();

    for (label, path) in label_to_path {
        let mut all_dep_names = BTreeSet::new();

        trace!("Parsing {:?}", path);
        let content =
            read_to_string(&path).with_context(|| format!("Failed to read {:?}", path))?;
        let cargo_toml = CargoToml::try_from(content.as_str())
            .with_context(|| format!("Error parsing {:?}", path))?;
        let CargoToml {
            dependencies,
            build_dependencies,
            dev_dependencies,
            patch,
            package: _,
            _ignored,
        } = cargo_toml;
        for (dep, dep_spec) in dependencies.into_iter() {
            if let VersionSpec::Local(_) = dep_spec.version {
                // We ignore local deps.
                debug!("Ignoring local path dependency on {:?}", path);
                continue;
            }
            all_dep_names.insert(dep.clone());
            if let Some(dep_spec_to_merge) = merged_cargo_toml.dependencies.get_mut(&dep) {
                dep_spec_to_merge
                    .merge(dep_spec)
                    .context(format!("Failed to merge multiple dependencies on {}", dep))?;
            } else {
                merged_cargo_toml.dependencies.insert(dep, dep_spec);
            }
        }

        for (dep, dep_spec) in build_dependencies.into_iter() {
            if let VersionSpec::Local(_) = dep_spec.version {
                // We ignore local deps.
                debug!("Ignoring local path dependency on {:?}", path);
                continue;
            }
            all_dep_names.insert(dep.clone());
            if let Some(dep_spec_to_merge) = merged_cargo_toml.build_dependencies.get_mut(&dep) {
                dep_spec_to_merge
                    .merge(dep_spec)
                    .context(format!("Failed to merge multiple dependencies on {}", dep))?;
            } else {
                merged_cargo_toml.build_dependencies.insert(dep, dep_spec);
            }
        }

        for (dep, dep_spec) in dev_dependencies.into_iter() {
            if let VersionSpec::Local(_) = dep_spec.version {
                // We ignore local deps.
                debug!("Ignoring local path dependency on {:?}", path);
                continue;
            }
            all_dep_names.insert(dep.clone());
            if let Some(dep_spec_to_merge) = merged_cargo_toml.dev_dependencies.get_mut(&dep) {
                dep_spec_to_merge
                    .merge(dep_spec)
                    .context(format!("Failed to merge multiple dependencies on {}", dep))?;
            } else {
                merged_cargo_toml.dev_dependencies.insert(dep, dep_spec);
            }
        }

        for (repo, deps) in patch {
            if let Some(repo_map) = merged_cargo_toml.patch.get_mut(&repo) {
                for (dep, dep_spec) in deps {
                    if let Some(existing_dep_spec) = repo_map.get_mut(&dep) {
                        existing_dep_spec.merge(dep_spec).context(format!(
                            "Failed to merge multiple patches of {} in {}",
                            dep, repo
                        ))?;
                    } else {
                        repo_map.insert(dep, dep_spec);
                    }
                }
            } else {
                merged_cargo_toml.patch.insert(repo, deps);
            }
        }

        labels_to_deps.insert(label.clone(), all_dep_names);
    }

    // Check for conflicts between packages in Cargo.toml and packages in crate_universe().
    // TODO: only mark packages as conflicting if names are the same but versions are incompatible.
    let cargo_toml_package_set: BTreeSet<_> =
        merged_cargo_toml.dependencies.keys().cloned().collect();
    let repo_rule_package_set: BTreeSet<_> = packages.iter().map(|p| p.name.clone()).collect();

    let conflicting_pkgs: BTreeSet<_> = cargo_toml_package_set
        .intersection(&repo_rule_package_set)
        .collect();
    if !conflicting_pkgs.is_empty() {
        let conflicting_pkgs: Vec<_> = conflicting_pkgs.into_iter().cloned().collect();
        // TODO: Mention which one, from labels_to_deps.
        return Err(anyhow!("The following package{} provided both in a Cargo.toml and in the crate_universe repository rule: {}.", if conflicting_pkgs.len() == 1 { " was" } else { "s were" }, conflicting_pkgs.join(", ")));
    }

    for package in packages {
        merged_cargo_toml.dependencies.insert(
            package.name,
            DepSpec {
                default_features: true,
                features: package.features.into_iter().collect(),
                version: VersionSpec::Semver(package.semver),
            },
        );
    }

    Ok((merged_cargo_toml, labels_to_deps))
}

impl TryFrom<&str> for CargoToml {
    type Error = anyhow::Error;

    fn try_from(value: &str) -> Result<Self, Self::Error> {
        Ok(toml::from_str(value)?)
    }
}

impl From<CargoToml> for toml::Value {
    fn from(cargo_toml: CargoToml) -> Value {
        let CargoToml {
            package,
            dependencies,
            build_dependencies,
            dev_dependencies,
            patch,
            _ignored,
        } = cargo_toml;

        let mut v = toml::value::Table::new();

        v.insert(String::from("package"), package.into());

        v.insert(
            String::from("lib"),
            toml::Value::Table({
                let mut table = toml::value::Table::new();
                // cargo-metadata fails without this key.
                table.insert(
                    String::from("path"),
                    toml::Value::String(String::from("doesnotexist.rs")),
                );
                table
            }),
        );

        if !dependencies.is_empty() {
            v.insert(
                String::from("dependencies"),
                table_of_dep_specs_to_toml(dependencies),
            );
        }
        if !build_dependencies.is_empty() {
            v.insert(
                String::from("build-dependencies"),
                table_of_dep_specs_to_toml(build_dependencies),
            );
        }
        if !dev_dependencies.is_empty() {
            v.insert(
                String::from("dev-dependencies"),
                table_of_dep_specs_to_toml(dev_dependencies),
            );
        }

        if !patch.is_empty() {
            v.insert(
                String::from("patch"),
                toml::Value::Table({
                    let mut table = toml::value::Table::new();
                    for (repo, patches) in patch {
                        table.insert(repo, table_of_dep_specs_to_toml(patches));
                    }
                    table
                }),
            );
        }

        toml::Value::Table(v)
    }
}

fn table_of_dep_specs_to_toml(table: BTreeMap<String, DepSpec>) -> toml::Value {
    toml::Value::Table(
        table
            .into_iter()
            .filter_map(|(dep_name, dep_spec)| {
                dep_spec.to_cargo_toml_dep().map(|dep| (dep_name, dep))
            })
            .collect(),
    )
}

impl From<Package> for toml::Value {
    fn from(package: Package) -> Self {
        let Package { name, version } = package;

        let mut v = toml::value::Table::new();
        v.insert(String::from("name"), toml::Value::String(name));
        v.insert(
            String::from("version"),
            toml::Value::String(format!("{}", version)),
        );

        toml::Value::Table(v)
    }
}

impl<'de> Deserialize<'de> for DepSpec {
    fn deserialize<D>(deserializer: D) -> Result<Self, <D as Deserializer<'de>>::Error>
    where
        D: Deserializer<'de>,
    {
        deserializer.deserialize_any(crate::serde_utils::DepSpecDeserializer)
    }
}

impl DepSpec {
    fn merge(&mut self, other: DepSpec) -> Result<(), anyhow::Error> {
        self.default_features |= other.default_features;

        self.features.extend(other.features.clone());

        match (&mut self.version, &other.version) {
            (v1, v2) if v1 == v2 => {}
            (VersionSpec::Semver(v1), VersionSpec::Semver(v2)) => {
                self.version = VersionSpec::Semver(VersionReq::parse(&format!("{}, {}", v1, v2))?)
            }
            (v1 @ VersionSpec::Git { .. }, v2 @ VersionSpec::Git { .. }) => {
                return Err(anyhow!(
                    "Can't merge different git versions of the same dependency (saw {:?} and {:?})",
                    v1,
                    v2
                ))
            }
            (v1, v2) => {
                return Err(anyhow!(
                "Can't merge semver and git versions of the same dependency (saw: {:?} and {:?})",
                v1,
                v2
            ))
            }
        }
        Ok(())
    }

    fn to_cargo_toml_dep(self) -> Option<toml::Value> {
        let Self {
            default_features,
            features,
            version,
        } = self;

        let mut v = toml::value::Table::new();
        v.insert(
            String::from("default-features"),
            toml::Value::Boolean(default_features),
        );
        v.insert(
            String::from("features"),
            toml::Value::Array(features.into_iter().map(toml::Value::String).collect()),
        );
        match version {
            VersionSpec::Semver(version) => {
                v.insert(
                    String::from("version"),
                    toml::Value::String(format!("{}", version)),
                );
            }
            VersionSpec::Git { url, rev, tag } => {
                v.insert(String::from("git"), toml::Value::String(url));
                if let Some(rev) = rev {
                    v.insert(String::from("rev"), toml::Value::String(rev));
                }
                if let Some(tag) = tag {
                    v.insert(String::from("tag"), toml::Value::String(tag));
                }
            }
            VersionSpec::Local(path) => {
                eprintln!("Ignoring local path dependency on {:?}", path);
                return None;
            }
        }

        Some(toml::Value::Table(v))
    }
}
