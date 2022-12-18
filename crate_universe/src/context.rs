//! Convert annotated metadata into a renderable context

pub mod crate_context;
mod platforms;

use std::collections::{BTreeMap, BTreeSet};
use std::fs;
use std::path::{Path, PathBuf};

use anyhow::Result;
use serde::{Deserialize, Serialize};

use crate::config::CrateId;
use crate::context::crate_context::{CrateContext, CrateDependency, Rule};
use crate::context::platforms::resolve_cfg_platforms;
use crate::lockfile::Digest;
use crate::metadata::Annotations;
use crate::utils::starlark::{Select, SelectList};

pub use self::crate_context::*;

/// A struct containing information about a Cargo dependency graph in an easily to consume
/// format for rendering reproducible Bazel targets.
#[derive(Debug, Default, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize, Clone)]
pub struct Context {
    /// The collective checksum of all inputs to the context
    pub checksum: Option<Digest>,

    /// The collection of all crates that make up the dependency graph
    pub crates: BTreeMap<CrateId, CrateContext>,

    /// A subset of only crates with binary targets
    pub binary_crates: BTreeSet<CrateId>,

    /// A subset of workspace members mapping to their workspace
    /// path relative to the workspace root
    pub workspace_members: BTreeMap<CrateId, String>,

    /// A mapping of `cfg` flags to platform triples supporting the configuration
    pub conditions: BTreeMap<String, BTreeSet<String>>,
}

impl Context {
    pub fn try_from_path<T: AsRef<Path>>(path: T) -> Result<Self> {
        let data = fs::read_to_string(path.as_ref())?;
        Ok(serde_json::from_str(&data)?)
    }

    pub fn new(annotations: Annotations) -> Result<Self> {
        // Build a map of crate contexts
        let crates: BTreeMap<CrateId, CrateContext> = annotations
            .metadata
            .crates
            .values()
            .map(|annotation| {
                let context = CrateContext::new(
                    annotation,
                    &annotations.metadata.packages,
                    &annotations.lockfile.crates,
                    &annotations.pairred_extras,
                    annotations.config.generate_build_scripts,
                );
                let id = CrateId::new(context.name.clone(), context.version.clone());
                (id, context)
            })
            .collect();

        // Filter for any crate that contains a binary
        let binary_crates: BTreeSet<CrateId> = crates
            .iter()
            .filter(|(_, ctx)| ctx.targets.iter().any(|t| matches!(t, Rule::Binary(..))))
            // Only consider remote repositories (so non-workspace members).
            .filter(|(_, ctx)| ctx.repository.is_some())
            .map(|(id, _)| id.clone())
            .collect();

        // Given a list of all conditional dependencies, build a set of platform
        // triples which satsify the conditions.
        let conditions = resolve_cfg_platforms(
            crates.values().collect(),
            &annotations.config.supported_platform_triples,
        )?;

        // Generate a list of all workspace members
        let workspace_members = annotations
            .metadata
            .workspace_members
            .iter()
            .filter_map(|id| {
                let pkg = &annotations.metadata.packages[id];
                let package_path_id = match Self::get_package_path_id(
                    pkg,
                    &annotations.metadata.workspace_root,
                    &annotations.metadata.workspace_metadata.workspace_prefix,
                    &annotations.metadata.workspace_metadata.package_prefixes,
                ) {
                    Ok(id) => id,
                    Err(e) => return Some(Err(e)),
                };
                let crate_id = CrateId::new(pkg.name.clone(), pkg.version.to_string());

                // Crates that have repository information are not considered workspace members.
                // The assumpion is that they are "extra workspace members".
                match crates[&crate_id].repository {
                    Some(_) => None,
                    None => Some(Ok((crate_id, package_path_id))),
                }
            })
            .collect::<Result<BTreeMap<CrateId, String>>>()?;

        Ok(Self {
            checksum: None,
            crates,
            binary_crates,
            workspace_members,
            conditions,
        })
    }

    // A helper function for locating the unique path in a workspace to a workspace member
    fn get_package_path_id(
        package: &cargo_metadata::Package,
        workspace_root: &Path,
        workspace_prefix: &Option<String>,
        package_prefixes: &BTreeMap<String, String>,
    ) -> Result<String> {
        // Locate the package's manifest directory
        let manifest_dir = package
            .manifest_path
            .parent()
            .expect("Every manifest should have a parent")
            .as_std_path();

        // Compare it with the root of the workspace
        let package_path_diff = pathdiff::diff_paths(manifest_dir, workspace_root)
            .expect("Every workspace member's manifest is a child of the workspace root");

        // Ensure the package paths are adjusted in the macros according to the splicing results
        let package_path = match package_prefixes.get(&package.name) {
            // Any package prefix should be absolute and therefore always applied
            Some(prefix) => PathBuf::from(prefix).join(package_path_diff),
            // If no package prefix is present, attempt to apply the workspace prefix
            // since workspace members would not have shown up with their own label
            None => match workspace_prefix {
                Some(prefix) => PathBuf::from(prefix).join(package_path_diff),
                None => package_path_diff,
            },
        };

        // Sanitize the path for increased consistency
        let package_path_id = package_path
            .display()
            .to_string()
            .replace('\\', "/")
            .trim_matches('/')
            .to_owned();

        Ok(package_path_id)
    }

    /// Filter a crate's dependencies to only ones with aliases
    pub fn crate_aliases(
        &self,
        crate_id: &CrateId,
        build: bool,
        include_dev: bool,
    ) -> SelectList<&CrateDependency> {
        let ctx = &self.crates[crate_id];
        let mut set = SelectList::default();

        // Return a set of aliases for build dependencies
        // vs normal dependencies when requested.
        if build {
            // Note that there may not be build dependencies so no dependencies
            // will be gathered in this case
            if let Some(attrs) = &ctx.build_script_attrs {
                let collection: Vec<(Option<String>, &CrateDependency)> = attrs
                    .deps
                    .configurations()
                    .into_iter()
                    .flat_map(move |conf| {
                        attrs
                            .deps
                            .get_iter(conf)
                            .expect("Iterating over known keys should never panic")
                            .filter(|dep| dep.alias.is_some())
                            .map(move |dep| (conf.cloned(), dep))
                    })
                    .chain(attrs.proc_macro_deps.configurations().into_iter().flat_map(
                        move |conf| {
                            attrs
                                .proc_macro_deps
                                .get_iter(conf)
                                .expect("Iterating over known keys should never panic")
                                .filter(|dep| dep.alias.is_some())
                                .map(move |dep| (conf.cloned(), dep))
                        },
                    ))
                    .collect();

                for (config, dep) in collection {
                    set.insert(dep, config);
                }
            }
        } else {
            let attrs = &ctx.common_attrs;
            let mut collection: Vec<(Option<String>, &CrateDependency)> =
                attrs
                    .deps
                    .configurations()
                    .into_iter()
                    .flat_map(move |conf| {
                        attrs
                            .deps
                            .get_iter(conf)
                            .expect("Iterating over known keys should never panic")
                            .filter(|dep| dep.alias.is_some())
                            .map(move |dep| (conf.cloned(), dep))
                    })
                    .chain(attrs.proc_macro_deps.configurations().into_iter().flat_map(
                        move |conf| {
                            attrs
                                .proc_macro_deps
                                .get_iter(conf)
                                .expect("Iterating over known keys should never panic")
                                .filter(|dep| dep.alias.is_some())
                                .map(move |dep| (conf.cloned(), dep))
                        },
                    ))
                    .collect();

            // Optionally include dev dependencies
            if include_dev {
                collection = collection
                    .into_iter()
                    .chain(
                        attrs
                            .deps_dev
                            .configurations()
                            .into_iter()
                            .flat_map(move |conf| {
                                attrs
                                    .deps_dev
                                    .get_iter(conf)
                                    .expect("Iterating over known keys should never panic")
                                    .filter(|dep| dep.alias.is_some())
                                    .map(move |dep| (conf.cloned(), dep))
                            }),
                    )
                    .chain(
                        attrs
                            .proc_macro_deps_dev
                            .configurations()
                            .into_iter()
                            .flat_map(move |conf| {
                                attrs
                                    .proc_macro_deps_dev
                                    .get_iter(conf)
                                    .expect("Iterating over known keys should never panic")
                                    .filter(|dep| dep.alias.is_some())
                                    .map(move |dep| (conf.cloned(), dep))
                            }),
                    )
                    .collect();
            }

            for (config, dep) in collection {
                set.insert(dep, config);
            }
        }

        set
    }

    /// Create a set of all direct dependencies of workspace member crates and map them to
    /// optional alternative names that allow them to be uniquely identified. This typically
    /// results in a mapping of ([CrateId], [None]) where [None] defaults to using the crate
    /// name. The next most common would be using ([CrateId], `Some(alias)`) as some projects
    /// may use aliases in Cargo as a way to differentiate different versions of the same dep.
    pub fn flat_workspace_member_deps(&self) -> BTreeMap<CrateId, Option<String>> {
        let workspace_member_dependencies: BTreeSet<CrateDependency> = self
            .workspace_members
            .keys()
            .map(|id| &self.crates[id])
            .flat_map(|ctx| {
                // Build an interator of all dependency CrateIds.
                // TODO: This expansion is horribly verbose and should be refactored but closures
                // were not playing nice when I tried it.
                ctx.common_attrs
                    .deps
                    .configurations()
                    .into_iter()
                    .flat_map(move |conf| {
                        ctx.common_attrs
                            .deps
                            .get_iter(conf)
                            .expect("Lookup should be guaranteed")
                    })
                    .chain(
                        ctx.common_attrs
                            .deps_dev
                            .configurations()
                            .into_iter()
                            .flat_map(move |conf| {
                                ctx.common_attrs
                                    .deps_dev
                                    .get_iter(conf)
                                    .expect("Lookup should be guaranteed")
                            }),
                    )
                    .chain(
                        ctx.common_attrs
                            .proc_macro_deps
                            .configurations()
                            .into_iter()
                            .flat_map(move |conf| {
                                ctx.common_attrs
                                    .proc_macro_deps
                                    .get_iter(conf)
                                    .expect("Lookup should be guaranteed")
                            }),
                    )
                    .chain(
                        ctx.common_attrs
                            .proc_macro_deps_dev
                            .configurations()
                            .into_iter()
                            .flat_map(move |conf| {
                                ctx.common_attrs
                                    .proc_macro_deps_dev
                                    .get_iter(conf)
                                    .expect("Lookup should be guaranteed")
                            }),
                    )
            })
            .cloned()
            .collect();

        // Search for any duplicate workspace member definitions
        let duplicate_deps: Vec<CrateDependency> = workspace_member_dependencies
            .iter()
            .filter(|dep| {
                workspace_member_dependencies
                    .iter()
                    .filter(|check| dep.id.name == check.id.name)
                    .count()
                    > 1
            })
            .cloned()
            .collect();

        workspace_member_dependencies
            .into_iter()
            .map(|dep| {
                if duplicate_deps.contains(&dep) {
                    if let Some(alias) = &dep.alias {
                        // Check for any duplicate aliases
                        let aliases = duplicate_deps
                            .iter()
                            .filter(|dupe| dupe.id.name == dep.id.name)
                            .filter(|dupe| dupe.alias.is_some())
                            .filter(|dupe| dupe.alias == dep.alias);

                        // If there are multiple aliased crates with the same name, the name is updated to
                        // be `{alias}-{version}` to differentiate them.
                        if aliases.count() >= 2 {
                            let rename = format!("{}-{}", &alias, &dep.id.version);
                            (dep.id, Some(rename))
                        } else {
                            (dep.id, Some(alias.clone()))
                        }
                    } else {
                        // Check for all duplicates that match the current dependency and have no alias
                        let unaliased = duplicate_deps
                            .iter()
                            .filter(|dupe| dupe.id.name == dep.id.name)
                            .filter(|dupe| dupe.alias.is_none());

                        // If there are multiple unaliased crates with the same name, the name is updated to
                        // be `{name}-{version}` to differentiate them.
                        if unaliased.count() >= 2 {
                            let rename = format!("{}-{}", &dep.id.name, &dep.id.version);
                            (dep.id, Some(rename))
                        } else {
                            (dep.id, None)
                        }
                    }
                } else {
                    (dep.id, dep.alias)
                }
            })
            .collect()
    }

    /// Produce a list of binary dependencies with optional aliases which prevent duplicate
    /// targets from being generated.
    pub fn flat_binary_deps(&self) -> BTreeMap<CrateId, Option<String>> {
        // Check for any duplicate binary crate names. If one exists provide an alias to differentiate them
        self.binary_crates
            .iter()
            .map(|crate_id| {
                let dupe_count = self
                    .binary_crates
                    .iter()
                    .filter(|id| crate_id.name == id.name)
                    .count();
                // For targets that appear twice (which can happen if one crate aliases a binary dependency)
                if dupe_count >= 2 {
                    let rename = format!("{}-{}", crate_id.name, crate_id.version);
                    (crate_id.clone(), Some(rename))
                } else {
                    (crate_id.clone(), None)
                }
            })
            .collect()
    }
}

#[cfg(test)]
mod test {
    use super::*;

    use crate::config::Config;

    fn mock_context_common() -> Context {
        let annotations = Annotations::new(
            crate::test::metadata::common(),
            crate::test::lockfile::common(),
            Config::default(),
        )
        .unwrap();

        Context::new(annotations).unwrap()
    }

    fn mock_context_aliases() -> Context {
        let annotations = Annotations::new(
            crate::test::metadata::alias(),
            crate::test::lockfile::alias(),
            Config::default(),
        )
        .unwrap();

        Context::new(annotations).unwrap()
    }

    #[test]
    fn flat_workspace_member_deps() {
        let context = mock_context_common();
        let workspace_member_deps = context.flat_workspace_member_deps();

        assert_eq!(
            workspace_member_deps,
            BTreeMap::from([
                (
                    CrateId::new("bitflags".to_owned(), "1.3.2".to_owned()),
                    None
                ),
                (CrateId::new("cfg-if".to_owned(), "1.0.0".to_owned()), None),
            ])
        );
    }

    #[test]
    fn flat_workspace_member_deps_with_alises() {
        let context = mock_context_aliases();
        let workspace_member_deps = context.flat_workspace_member_deps();

        assert_eq!(
            workspace_member_deps,
            BTreeMap::from([
                (
                    CrateId {
                        name: "log".to_owned(),
                        version: "0.3.9".to_owned(),
                    },
                    Some("pinned_log".to_owned())
                ),
                (
                    CrateId {
                        name: "log".to_owned(),
                        version: "0.4.14".to_owned(),
                    },
                    None
                ),
                (
                    CrateId {
                        name: "names".to_owned(),
                        version: "0.12.1-dev".to_owned(),
                    },
                    Some("pinned_names".to_owned())
                ),
                (
                    CrateId {
                        name: "names".to_owned(),
                        version: "0.13.0".to_owned(),
                    },
                    None
                ),
                (
                    CrateId {
                        name: "value-bag".to_owned(),
                        version: "1.0.0-alpha.7".to_owned(),
                    },
                    None
                ),
            ])
        );
    }
}
