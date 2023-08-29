//! Crate specific information embedded into [crate::context::Context] objects.

use std::collections::{BTreeMap, BTreeSet};

use cargo_metadata::{Node, Package, PackageId};
use serde::{Deserialize, Serialize};

use crate::config::{CrateId, GenBinaries, StringOrSelect};
use crate::metadata::{CrateAnnotation, Dependency, PairredExtras, SourceAnnotation};
use crate::utils::sanitize_module_name;
use crate::utils::starlark::{Glob, SelectList, SelectMap, SelectStringDict, SelectStringList};

#[derive(Debug, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize, Clone)]
pub struct CrateDependency {
    /// The [CrateId] of the dependency
    pub id: CrateId,

    /// The target name of the dependency. Note this may differ from the
    /// dependency's package name in cases such as build scripts.
    pub target: String,

    /// Some dependencies are assigned aliases. This is tracked here
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub alias: Option<String>,
}

#[derive(Debug, Default, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize, Clone)]
#[serde(default)]
pub struct TargetAttributes {
    /// The module name of the crate (notably, not the package name).
    //
    // This must be the first field of `TargetAttributes` to make it the
    // lexicographically first thing the derived `Ord` implementation will sort
    // by. The `Ord` impl controls the order of multiple rules of the same type
    // in the same BUILD file. In particular, this makes packages with multiple
    // bin crates generate those `rust_binary` targets in alphanumeric order.
    pub crate_name: String,

    /// The path to the crate's root source file, relative to the manifest.
    pub crate_root: Option<String>,

    /// A glob pattern of all source files required by the target
    pub srcs: Glob,
}

#[derive(Debug, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize, Clone)]
pub enum Rule {
    /// `rust_library`
    Library(TargetAttributes),

    /// `rust_proc_macro`
    ProcMacro(TargetAttributes),

    /// `rust_binary`
    Binary(TargetAttributes),

    /// `cargo_build_script`
    BuildScript(TargetAttributes),
}

#[derive(Debug, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize, Clone)]
#[serde(untagged)]
pub enum CrateFeatures {
    // Not populated going forward. This just exists for backward compatiblity
    // with old lock files.
    LegacySet(BTreeSet<String>),

    /// Map from target triplet to set of features.
    SelectList(SelectList<String>),
}

impl Default for CrateFeatures {
    fn default() -> Self {
        CrateFeatures::SelectList(Default::default())
    }
}

impl From<&CrateFeatures> for SelectList<String> {
    fn from(value: &CrateFeatures) -> Self {
        match value {
            CrateFeatures::LegacySet(s) => {
                let mut sl = SelectList::default();
                for v in s {
                    sl.insert(v.clone(), None);
                }
                sl
            }
            CrateFeatures::SelectList(sl) => sl.clone(),
        }
    }
}

impl CrateFeatures {
    pub fn is_empty(&self) -> bool {
        match self {
            CrateFeatures::LegacySet(s) => s.is_empty(),
            CrateFeatures::SelectList(sl) => sl.is_empty(),
        }
    }
}

/// A set of attributes common to most `rust_library`, `rust_proc_macro`, and other
/// [core rules of `rules_rust`](https://bazelbuild.github.io/rules_rust/defs.html).
#[derive(Debug, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize, Clone)]
#[serde(default)]
pub struct CommonAttributes {
    #[serde(skip_serializing_if = "SelectStringList::is_empty")]
    pub compile_data: SelectStringList,

    #[serde(skip_serializing_if = "BTreeSet::is_empty")]
    pub compile_data_glob: BTreeSet<String>,

    #[serde(skip_serializing_if = "CrateFeatures::is_empty")]
    pub crate_features: CrateFeatures,

    #[serde(skip_serializing_if = "SelectStringList::is_empty")]
    pub data: SelectStringList,

    #[serde(skip_serializing_if = "BTreeSet::is_empty")]
    pub data_glob: BTreeSet<String>,

    #[serde(skip_serializing_if = "SelectList::is_empty")]
    pub deps: SelectList<CrateDependency>,

    #[serde(skip_serializing_if = "BTreeSet::is_empty")]
    pub extra_deps: BTreeSet<String>,

    #[serde(skip_serializing_if = "SelectList::is_empty")]
    pub deps_dev: SelectList<CrateDependency>,

    pub edition: String,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub linker_script: Option<String>,

    #[serde(skip_serializing_if = "SelectList::is_empty")]
    pub proc_macro_deps: SelectList<CrateDependency>,

    #[serde(skip_serializing_if = "BTreeSet::is_empty")]
    pub extra_proc_macro_deps: BTreeSet<String>,

    #[serde(skip_serializing_if = "SelectList::is_empty")]
    pub proc_macro_deps_dev: SelectList<CrateDependency>,

    #[serde(skip_serializing_if = "SelectStringDict::is_empty")]
    pub rustc_env: SelectStringDict,

    #[serde(skip_serializing_if = "SelectStringList::is_empty")]
    pub rustc_env_files: SelectStringList,

    #[serde(skip_serializing_if = "Vec::is_empty")]
    pub rustc_flags: Vec<String>,

    pub version: String,

    #[serde(skip_serializing_if = "Vec::is_empty")]
    pub tags: Vec<String>,
}

impl Default for CommonAttributes {
    fn default() -> Self {
        Self {
            compile_data: Default::default(),
            // Generated targets include all files in their package by default
            compile_data_glob: BTreeSet::from(["**".to_owned()]),
            crate_features: Default::default(),
            data: Default::default(),
            data_glob: Default::default(),
            deps: Default::default(),
            extra_deps: Default::default(),
            deps_dev: Default::default(),
            edition: Default::default(),
            linker_script: Default::default(),
            proc_macro_deps: Default::default(),
            extra_proc_macro_deps: Default::default(),
            proc_macro_deps_dev: Default::default(),
            rustc_env: Default::default(),
            rustc_env_files: Default::default(),
            rustc_flags: Default::default(),
            version: Default::default(),
            tags: Default::default(),
        }
    }
}

// Build script attributes. See
// https://bazelbuild.github.io/rules_rust/cargo.html#cargo_build_script
#[derive(Debug, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize, Clone)]
#[serde(default)]
pub struct BuildScriptAttributes {
    #[serde(skip_serializing_if = "SelectStringList::is_empty")]
    pub compile_data: SelectStringList,

    #[serde(skip_serializing_if = "SelectStringList::is_empty")]
    pub data: SelectStringList,

    #[serde(skip_serializing_if = "BTreeSet::is_empty")]
    pub data_glob: BTreeSet<String>,

    #[serde(skip_serializing_if = "SelectList::is_empty")]
    pub deps: SelectList<CrateDependency>,

    #[serde(skip_serializing_if = "BTreeSet::is_empty")]
    pub extra_deps: BTreeSet<String>,

    // TODO: refactor a crate with a build.rs file from two into three bazel
    // rules in order to deduplicate link_dep information. Currently as the
    // crate depends upon the build.rs file, the build.rs cannot find the
    // information for the normal dependencies of the crate. This could be
    // solved by switching the dependency graph from:
    //
    //   rust_library -> cargo_build_script
    //
    // to:
    //
    //   rust_library ->-+-->------------------->--+
    //                   |                         |
    //                   +--> cargo_build_script --+--> crate dependencies
    //
    // in which either all of the deps are in crate dependencies, or just the
    // normal dependencies. This could be handled a special rule, or just using
    // a `filegroup`.
    #[serde(skip_serializing_if = "SelectList::is_empty")]
    pub link_deps: SelectList<CrateDependency>,

    #[serde(skip_serializing_if = "BTreeSet::is_empty")]
    pub extra_link_deps: BTreeSet<String>,

    #[serde(skip_serializing_if = "SelectStringDict::is_empty")]
    pub build_script_env: SelectStringDict,

    #[serde(skip_serializing_if = "BTreeSet::is_empty")]
    pub extra_proc_macro_deps: BTreeSet<String>,

    #[serde(skip_serializing_if = "SelectList::is_empty")]
    pub proc_macro_deps: SelectList<CrateDependency>,

    #[serde(skip_serializing_if = "SelectStringDict::is_empty")]
    pub rustc_env: SelectStringDict,

    #[serde(skip_serializing_if = "SelectStringList::is_empty")]
    pub rustc_flags: SelectStringList,

    #[serde(skip_serializing_if = "SelectStringList::is_empty")]
    pub rustc_env_files: SelectStringList,

    #[serde(skip_serializing_if = "SelectStringList::is_empty")]
    pub tools: SelectStringList,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub links: Option<String>,

    #[serde(skip_serializing_if = "BTreeSet::is_empty")]
    pub toolchains: BTreeSet<String>,
}

impl Default for BuildScriptAttributes {
    fn default() -> Self {
        Self {
            compile_data: Default::default(),
            data: Default::default(),
            // Build scripts include all sources by default
            data_glob: BTreeSet::from(["**".to_owned()]),
            deps: Default::default(),
            extra_deps: Default::default(),
            link_deps: Default::default(),
            extra_link_deps: Default::default(),
            build_script_env: Default::default(),
            extra_proc_macro_deps: Default::default(),
            proc_macro_deps: Default::default(),
            rustc_env: Default::default(),
            rustc_flags: Default::default(),
            rustc_env_files: Default::default(),
            tools: Default::default(),
            links: Default::default(),
            toolchains: Default::default(),
        }
    }
}

#[derive(Debug, Default, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize, Clone)]
#[serde(default)]
pub struct CrateContext {
    /// The package name of the current crate
    pub name: String,

    /// The full version of the current crate
    pub version: String,

    /// Optional source annotations if they were discoverable in the
    /// lockfile. Workspace Members will not have source annotations and
    /// potentially others.
    pub repository: Option<SourceAnnotation>,

    /// A list of all targets (lib, proc-macro, bin) associated with this package
    pub targets: BTreeSet<Rule>,

    /// The name of the crate's root library target. This is the target that a dependent
    /// would get if they were to depend on `{crate_name}`.
    pub library_target_name: Option<String>,

    /// A set of attributes common to most [Rule] types or target types.
    pub common_attrs: CommonAttributes,

    /// Optional attributes for build scripts. This field is only populated if
    /// a build script (`custom-build`) target is defined for the crate.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub build_script_attrs: Option<BuildScriptAttributes>,

    /// The license used by the crate
    pub license: Option<String>,

    /// Additional text to add to the generated BUILD file.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub additive_build_file_content: Option<String>,

    /// If true, disables pipelining for library targets generated for this crate
    #[serde(skip_serializing_if = "std::ops::Not::not")]
    pub disable_pipelining: bool,

    /// Extra targets that should be aliased.
    #[serde(skip_serializing_if = "BTreeMap::is_empty")]
    pub extra_aliased_targets: BTreeMap<String, String>,
}

impl CrateContext {
    pub fn new(
        annotation: &CrateAnnotation,
        packages: &BTreeMap<PackageId, Package>,
        source_annotations: &BTreeMap<PackageId, SourceAnnotation>,
        extras: &BTreeMap<CrateId, PairredExtras>,
        features: &BTreeMap<CrateId, SelectList<String>>,
        include_binaries: bool,
        include_build_scripts: bool,
    ) -> Self {
        let package: &Package = &packages[&annotation.node.id];
        let current_crate_id = CrateId::new(package.name.clone(), package.version.to_string());

        let new_crate_dep = |dep: Dependency| -> CrateDependency {
            let pkg = &packages[&dep.package_id];

            // Unfortunately, The package graph and resolve graph of cargo metadata have different representations
            // for the crate names (resolve graph sanitizes names to match module names) so to get the rest of this
            // content to align when rendering, the dependency target needs to be explicitly sanitized.
            let target = sanitize_module_name(&dep.target_name);

            CrateDependency {
                id: CrateId::new(pkg.name.clone(), pkg.version.to_string()),
                target,
                alias: dep.alias,
            }
        };

        // Convert the dependencies into renderable strings
        let deps = annotation.deps.normal_deps.clone().map(new_crate_dep);
        let deps_dev = annotation.deps.normal_dev_deps.clone().map(new_crate_dep);
        let proc_macro_deps = annotation.deps.proc_macro_deps.clone().map(new_crate_dep);
        let proc_macro_deps_dev = annotation
            .deps
            .proc_macro_dev_deps
            .clone()
            .map(new_crate_dep);

        // Gather all "common" attributes
        let mut common_attrs = CommonAttributes {
            crate_features: CrateFeatures::SelectList(
                features
                    .get(&current_crate_id)
                    .map_or_else(SelectList::default, |f| f.clone()),
            ),
            deps,
            deps_dev,
            edition: package.edition.as_str().to_string(),
            proc_macro_deps,
            proc_macro_deps_dev,
            version: package.version.to_string(),
            ..Default::default()
        };

        // Locate extra settings for the current package.
        let package_extra = extras
            .iter()
            .find(|(_, settings)| settings.package_id == package.id);

        let include_build_scripts =
            Self::crate_includes_build_script(package_extra, include_build_scripts);

        let gen_none = GenBinaries::Some(BTreeSet::new());
        let gen_binaries = package_extra
            .and_then(|(_, settings)| settings.crate_extra.gen_binaries.as_ref())
            .unwrap_or(if include_binaries {
                &GenBinaries::All
            } else {
                &gen_none
            });

        // Iterate over each target and produce a Bazel target for all supported "kinds"
        let targets = Self::collect_targets(
            &annotation.node,
            packages,
            gen_binaries,
            include_build_scripts,
        );

        // Parse the library crate name from the set of included targets
        let library_target_name = {
            let lib_targets: Vec<&TargetAttributes> = targets
                .iter()
                .filter_map(|t| match t {
                    Rule::ProcMacro(attrs) => Some(attrs),
                    Rule::Library(attrs) => Some(attrs),
                    _ => None,
                })
                .collect();

            // TODO: There should only be at most 1 library target. This case
            // should be handled in a more intelligent way.
            assert!(lib_targets.len() <= 1);
            lib_targets
                .iter()
                .last()
                .map(|attr| attr.crate_name.clone())
        };

        // Gather any build-script related attributes
        let build_script_target = targets.iter().find_map(|r| match r {
            Rule::BuildScript(attr) => Some(attr),
            _ => None,
        });

        let build_script_attrs = if let Some(target) = build_script_target {
            // Track the build script dependency
            common_attrs.deps.insert(
                CrateDependency {
                    id: current_crate_id,
                    target: target.crate_name.clone(),
                    alias: None,
                },
                None,
            );

            let build_deps = annotation.deps.build_deps.clone().map(new_crate_dep);
            let build_link_deps = annotation.deps.build_link_deps.clone().map(new_crate_dep);
            let build_proc_macro_deps = annotation
                .deps
                .build_proc_macro_deps
                .clone()
                .map(new_crate_dep);

            Some(BuildScriptAttributes {
                deps: build_deps,
                link_deps: build_link_deps,
                proc_macro_deps: build_proc_macro_deps,
                links: package.links.clone(),
                ..Default::default()
            })
        } else {
            None
        };

        // Save the repository information for the current crate
        let repository = source_annotations.get(&package.id).cloned();

        // Identify the license type
        let license = package.license.clone();

        // Create the crate's context and apply extra settings
        CrateContext {
            name: package.name.clone(),
            version: package.version.to_string(),
            repository,
            targets,
            library_target_name,
            common_attrs,
            build_script_attrs,
            license,
            additive_build_file_content: None,
            disable_pipelining: false,
            extra_aliased_targets: BTreeMap::new(),
        }
        .with_overrides(extras)
    }

    fn with_overrides(mut self, extras: &BTreeMap<CrateId, PairredExtras>) -> Self {
        let id = CrateId::new(self.name.clone(), self.version.clone());

        // Insert all overrides/extras
        if let Some(pairred_override) = extras.get(&id) {
            let crate_extra = &pairred_override.crate_extra;

            // Deps
            if let Some(extra) = &crate_extra.deps {
                self.common_attrs.extra_deps = extra.clone();
            }

            // Proc macro deps
            if let Some(extra) = &crate_extra.proc_macro_deps {
                self.common_attrs.extra_proc_macro_deps = extra.clone();
            }

            // Compile data
            if let Some(extra) = &crate_extra.compile_data {
                for data in extra.iter() {
                    self.common_attrs.compile_data.insert(data.clone(), None);
                }
            }

            // Compile data glob
            if let Some(extra) = &crate_extra.compile_data_glob {
                self.common_attrs.compile_data_glob.extend(extra.clone());
            }

            // Crate features
            if let Some(extra) = &crate_extra.crate_features {
                match &mut self.common_attrs.crate_features {
                    CrateFeatures::LegacySet(s) => s.append(&mut extra.clone()),
                    CrateFeatures::SelectList(sl) => {
                        for data in extra.iter() {
                            sl.insert(data.clone(), None);
                        }
                    }
                }
            }

            // Data
            if let Some(extra) = &crate_extra.data {
                for data in extra.iter() {
                    self.common_attrs.data.insert(data.clone(), None);
                }
            }

            // Data glob
            if let Some(extra) = &crate_extra.data_glob {
                self.common_attrs.data_glob.extend(extra.clone());
            }

            // Disable pipelining
            if crate_extra.disable_pipelining {
                self.disable_pipelining = true;
            }

            // Rustc flags
            if let Some(extra) = &crate_extra.rustc_flags {
                self.common_attrs.rustc_flags.append(&mut extra.clone());
            }

            // Rustc env
            if let Some(extra) = &crate_extra.rustc_env {
                self.common_attrs.rustc_env.extend(extra.clone(), None);
            }

            // Rustc env files
            if let Some(extra) = &crate_extra.rustc_env_files {
                for data in extra.iter() {
                    self.common_attrs.rustc_env_files.insert(data.clone(), None);
                }
            }

            // Build script Attributes
            if let Some(attrs) = &mut self.build_script_attrs {
                // Deps
                if let Some(extra) = &crate_extra.build_script_deps {
                    attrs.extra_deps = extra.clone();
                }

                // Proc macro deps
                if let Some(extra) = &crate_extra.build_script_proc_macro_deps {
                    attrs.extra_proc_macro_deps = extra.clone();
                }

                // Data
                if let Some(extra) = &crate_extra.build_script_data {
                    for data in extra {
                        attrs.data.insert(data.clone(), None);
                    }
                }

                // Tools
                if let Some(extra) = &crate_extra.build_script_tools {
                    for data in extra {
                        attrs.tools.insert(data.clone(), None);
                    }
                }

                // Toolchains
                if let Some(extra) = &crate_extra.build_script_toolchains {
                    for data in extra {
                        attrs.toolchains.insert(data.clone());
                    }
                }

                // Data glob
                if let Some(extra) = &crate_extra.build_script_data_glob {
                    attrs.data_glob.extend(extra.clone());
                }

                // Rustc env
                if let Some(extra) = &crate_extra.build_script_rustc_env {
                    attrs.rustc_env.extend(extra.clone(), None);
                }

                // Build script env
                if let Some(extra) = &crate_extra.build_script_env {
                    for (key, value) in extra {
                        match value {
                            StringOrSelect::Value(value) => {
                                attrs
                                    .build_script_env
                                    .insert(key.clone(), value.clone(), None);
                            }
                            StringOrSelect::Select(select) => {
                                for (select_key, value) in select {
                                    attrs.build_script_env.insert(
                                        key.clone(),
                                        value.clone(),
                                        Some(select_key.clone()),
                                    );
                                }
                            }
                        }
                    }
                }
            }

            // Extra build contents
            self.additive_build_file_content = crate_extra
                .additive_build_file_content
                .as_ref()
                .map(|content| {
                    // For prettier rendering, dedent the build contents
                    textwrap::dedent(content)
                });

            // Extra aliased targets
            if let Some(extra) = &crate_extra.extra_aliased_targets {
                self.extra_aliased_targets.append(&mut extra.clone());
            }

            // Git shallow_since
            if let Some(SourceAnnotation::Git { shallow_since, .. }) = &mut self.repository {
                *shallow_since = crate_extra.shallow_since.clone()
            }

            // Patch attributes
            if let Some(repository) = &mut self.repository {
                match repository {
                    SourceAnnotation::Git {
                        patch_args,
                        patch_tool,
                        patches,
                        ..
                    } => {
                        *patch_args = crate_extra.patch_args.clone();
                        *patch_tool = crate_extra.patch_tool.clone();
                        *patches = crate_extra.patches.clone();
                    }
                    SourceAnnotation::Http {
                        patch_args,
                        patch_tool,
                        patches,
                        ..
                    } => {
                        *patch_args = crate_extra.patch_args.clone();
                        *patch_tool = crate_extra.patch_tool.clone();
                        *patches = crate_extra.patches.clone();
                    }
                }
            }
        }

        self
    }

    /// Determine whether or not a crate __should__ include a build script
    /// (build.rs) if it happens to have one.
    fn crate_includes_build_script(
        package_extra: Option<(&CrateId, &PairredExtras)>,
        default_generate_build_script: bool,
    ) -> bool {
        // If the crate has extra settings, which explicitly set `gen_build_script`, always use
        // this value, otherwise, fallback to the provided default.
        package_extra
            .and_then(|(_, settings)| settings.crate_extra.gen_build_script)
            .unwrap_or(default_generate_build_script)
    }

    /// Collect all Bazel targets that should be generated for a particular Package
    fn collect_targets(
        node: &Node,
        packages: &BTreeMap<PackageId, Package>,
        gen_binaries: &GenBinaries,
        include_build_scripts: bool,
    ) -> BTreeSet<Rule> {
        let package = &packages[&node.id];

        let package_root = package
            .manifest_path
            .as_std_path()
            .parent()
            .expect("Every manifest should have a parent directory");

        package
            .targets
            .iter()
            .flat_map(|target| {
                target.kind.iter().filter_map(move |kind| {
                    // Unfortunately, The package graph and resolve graph of cargo metadata have different representations
                    // for the crate names (resolve graph sanitizes names to match module names) so to get the rest of this
                    // content to align when rendering, the package target names are always sanitized.
                    let crate_name = sanitize_module_name(&target.name);

                    // Locate the crate's root source file relative to the package root normalized for unix
                    let crate_root = pathdiff::diff_paths(&target.src_path, package_root).map(
                        // Normalize the path so that it always renders the same regardless of platform
                        |root| root.to_string_lossy().replace('\\', "/"),
                    );

                    // Conditionally check to see if the dependencies is a build-script target
                    if include_build_scripts && kind == "custom-build" {
                        return Some(Rule::BuildScript(TargetAttributes {
                            crate_name,
                            crate_root,
                            srcs: Glob::new_rust_srcs(),
                        }));
                    }

                    // Check to see if the dependencies is a proc-macro target
                    if kind == "proc-macro" {
                        return Some(Rule::ProcMacro(TargetAttributes {
                            crate_name,
                            crate_root,
                            srcs: Glob::new_rust_srcs(),
                        }));
                    }

                    // Check to see if the dependencies is a library target
                    if ["lib", "rlib"].contains(&kind.as_str()) {
                        return Some(Rule::Library(TargetAttributes {
                            crate_name,
                            crate_root,
                            srcs: Glob::new_rust_srcs(),
                        }));
                    }

                    // Check if the target kind is binary and is one of the ones included in gen_binaries
                    if kind == "bin"
                        && match gen_binaries {
                            GenBinaries::All => true,
                            GenBinaries::Some(set) => set.contains(&target.name),
                        }
                    {
                        return Some(Rule::Binary(TargetAttributes {
                            crate_name: target.name.clone(),
                            crate_root,
                            srcs: Glob::new_rust_srcs(),
                        }));
                    }

                    None
                })
            })
            .collect()
    }
}

#[cfg(test)]
mod test {
    use super::*;

    use crate::config::CrateAnnotations;
    use crate::metadata::Annotations;

    fn common_annotations() -> Annotations {
        Annotations::new(
            crate::test::metadata::common(),
            crate::test::lockfile::common(),
            crate::config::Config::default(),
        )
        .unwrap()
    }

    #[test]
    fn new_context() {
        let annotations = common_annotations();

        let crate_annotation = &annotations.metadata.crates[&PackageId {
            repr: "common 0.1.0 (path+file://{TEMP_DIR}/common)".to_owned(),
        }];

        let include_binaries = false;
        let include_build_scripts = false;
        let context = CrateContext::new(
            crate_annotation,
            &annotations.metadata.packages,
            &annotations.lockfile.crates,
            &annotations.pairred_extras,
            &annotations.features,
            include_binaries,
            include_build_scripts,
        );

        assert_eq!(context.name, "common");
        assert_eq!(
            context.targets,
            BTreeSet::from([Rule::Library(TargetAttributes {
                crate_name: "common".to_owned(),
                crate_root: Some("lib.rs".to_owned()),
                srcs: Glob::new_rust_srcs(),
            })]),
        );
    }

    #[test]
    fn context_with_overrides() {
        let annotations = common_annotations();

        let package_id = PackageId {
            repr: "common 0.1.0 (path+file://{TEMP_DIR}/common)".to_owned(),
        };

        let crate_annotation = &annotations.metadata.crates[&package_id];

        let mut pairred_extras = BTreeMap::new();
        pairred_extras.insert(
            CrateId::new("common".to_owned(), "0.1.0".to_owned()),
            PairredExtras {
                package_id,
                crate_extra: CrateAnnotations {
                    gen_binaries: Some(GenBinaries::All),
                    data_glob: Some(BTreeSet::from(["**/data_glob/**".to_owned()])),
                    ..CrateAnnotations::default()
                },
            },
        );

        let include_binaries = false;
        let include_build_scripts = false;
        let context = CrateContext::new(
            crate_annotation,
            &annotations.metadata.packages,
            &annotations.lockfile.crates,
            &pairred_extras,
            &annotations.features,
            include_binaries,
            include_build_scripts,
        );

        assert_eq!(context.name, "common");
        assert_eq!(
            context.targets,
            BTreeSet::from([
                Rule::Library(TargetAttributes {
                    crate_name: "common".to_owned(),
                    crate_root: Some("lib.rs".to_owned()),
                    srcs: Glob::new_rust_srcs(),
                }),
                Rule::Binary(TargetAttributes {
                    crate_name: "common-bin".to_owned(),
                    crate_root: Some("main.rs".to_owned()),
                    srcs: Glob::new_rust_srcs(),
                }),
            ]),
        );
        assert_eq!(
            context.common_attrs.data_glob,
            BTreeSet::from(["**/data_glob/**".to_owned()])
        );
    }

    fn build_script_annotations() -> Annotations {
        Annotations::new(
            crate::test::metadata::build_scripts(),
            crate::test::lockfile::build_scripts(),
            crate::config::Config::default(),
        )
        .unwrap()
    }

    fn crate_type_annotations() -> Annotations {
        Annotations::new(
            crate::test::metadata::crate_types(),
            crate::test::lockfile::crate_types(),
            crate::config::Config::default(),
        )
        .unwrap()
    }

    #[test]
    fn context_with_build_script() {
        let annotations = build_script_annotations();

        let package_id = PackageId {
            repr: "openssl-sys 0.9.87 (registry+https://github.com/rust-lang/crates.io-index)"
                .to_owned(),
        };

        let crate_annotation = &annotations.metadata.crates[&package_id];

        let include_binaries = false;
        let include_build_scripts = true;
        let context = CrateContext::new(
            crate_annotation,
            &annotations.metadata.packages,
            &annotations.lockfile.crates,
            &annotations.pairred_extras,
            &annotations.features,
            include_binaries,
            include_build_scripts,
        );

        assert_eq!(context.name, "openssl-sys");
        assert!(context.build_script_attrs.is_some());
        assert_eq!(
            context.targets,
            BTreeSet::from([
                Rule::Library(TargetAttributes {
                    crate_name: "openssl_sys".to_owned(),
                    crate_root: Some("src/lib.rs".to_owned()),
                    srcs: Glob::new_rust_srcs(),
                }),
                Rule::BuildScript(TargetAttributes {
                    crate_name: "build_script_main".to_owned(),
                    crate_root: Some("build/main.rs".to_owned()),
                    srcs: Glob::new_rust_srcs(),
                })
            ]),
        );

        // Cargo build scripts should include all sources
        assert!(context.build_script_attrs.unwrap().data_glob.contains("**"));
    }

    #[test]
    fn context_disabled_build_script() {
        let annotations = build_script_annotations();

        let package_id = PackageId {
            repr: "openssl-sys 0.9.87 (registry+https://github.com/rust-lang/crates.io-index)"
                .to_owned(),
        };

        let crate_annotation = &annotations.metadata.crates[&package_id];

        let include_binaries = false;
        let include_build_scripts = false;
        let context = CrateContext::new(
            crate_annotation,
            &annotations.metadata.packages,
            &annotations.lockfile.crates,
            &annotations.pairred_extras,
            &annotations.features,
            include_binaries,
            include_build_scripts,
        );

        assert_eq!(context.name, "openssl-sys");
        assert!(context.build_script_attrs.is_none());
        assert_eq!(
            context.targets,
            BTreeSet::from([Rule::Library(TargetAttributes {
                crate_name: "openssl_sys".to_owned(),
                crate_root: Some("src/lib.rs".to_owned()),
                srcs: Glob::new_rust_srcs(),
            })]),
        );
    }

    #[test]
    fn context_rlib_crate_type() {
        let annotations = crate_type_annotations();

        let package_id = PackageId {
            repr: "sysinfo 0.22.5 (registry+https://github.com/rust-lang/crates.io-index)"
                .to_owned(),
        };

        let crate_annotation = &annotations.metadata.crates[&package_id];

        let include_binaries = false;
        let include_build_scripts = false;
        let context = CrateContext::new(
            crate_annotation,
            &annotations.metadata.packages,
            &annotations.lockfile.crates,
            &annotations.pairred_extras,
            &annotations.features,
            include_binaries,
            include_build_scripts,
        );

        assert_eq!(context.name, "sysinfo");
        assert!(context.build_script_attrs.is_none());
        assert_eq!(
            context.targets,
            BTreeSet::from([Rule::Library(TargetAttributes {
                crate_name: "sysinfo".to_owned(),
                crate_root: Some("src/lib.rs".to_owned()),
                srcs: Glob::new_rust_srcs(),
            })]),
        );
    }
}
