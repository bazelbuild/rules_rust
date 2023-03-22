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
use crate::utils::starlark::Select;

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
                    &annotations.features,
                    annotations.config.generate_binaries,
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

    /// Create a set of all direct dependencies of workspace member crates.
    pub fn workspace_member_deps(&self) -> BTreeSet<&CrateDependency> {
        self.workspace_members
            .keys()
            .map(move |id| &self.crates[id])
            .flat_map(|ctx| {
                IntoIterator::into_iter([
                    &ctx.common_attrs.deps,
                    &ctx.common_attrs.deps_dev,
                    &ctx.common_attrs.proc_macro_deps,
                    &ctx.common_attrs.proc_macro_deps_dev,
                ])
                .flat_map(|deps| {
                    deps.configurations().into_iter().flat_map(move |conf| {
                        deps.get_iter(conf).expect("Lookup should be guaranteed")
                    })
                })
            })
            .collect()
    }

    pub fn has_duplicate_workspace_member_dep(&self, dep: &CrateDependency) -> bool {
        1 < self
            .workspace_member_deps()
            .into_iter()
            .filter(|check| check.id.name == dep.id.name && check.alias == dep.alias)
            .count()
    }

    pub fn has_duplicate_binary_crate(&self, bin: &CrateId) -> bool {
        1 < self
            .binary_crates
            .iter()
            .filter(|check| check.name == bin.name)
            .count()
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
    fn workspace_member_deps() {
        let context = mock_context_common();
        let workspace_member_deps = context.workspace_member_deps();

        assert_eq! {
            workspace_member_deps
                .iter()
                .map(|dep| (&dep.id, context.has_duplicate_workspace_member_dep(dep)))
                .collect::<Vec<_>>(),
            [
                (&CrateId::new("bitflags".to_owned(), "1.3.2".to_owned()), false),
                (&CrateId::new("cfg-if".to_owned(), "1.0.0".to_owned()), false),
            ],
        }
    }

    #[test]
    fn workspace_member_deps_with_aliases() {
        let context = mock_context_aliases();
        let workspace_member_deps = context.workspace_member_deps();

        assert_eq! {
            workspace_member_deps
                .iter()
                .map(|dep| (&dep.id, context.has_duplicate_workspace_member_dep(dep)))
                .collect::<Vec<_>>(),
            [
                (&CrateId::new("log".to_owned(), "0.3.9".to_owned()), false),
                (&CrateId::new("log".to_owned(), "0.4.14".to_owned()), false),
                (&CrateId::new("names".to_owned(), "0.12.1-dev".to_owned()), false),
                (&CrateId::new("names".to_owned(), "0.13.0".to_owned()), false),
                (&CrateId::new("value-bag".to_owned(), "1.0.0-alpha.7".to_owned()), false),
            ],
        }
    }

    #[test]
    fn seralization() {
        let context = mock_context_aliases();

        // Seralize and deseralize the context object
        let json_text = serde_json::to_string(&context).unwrap();
        let deserialized_context: Context = serde_json::from_str(&json_text).unwrap();

        // The data should be identical
        assert_eq!(context, deserialized_context);
    }
}
