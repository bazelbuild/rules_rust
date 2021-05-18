// Copyright 2020 Google Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

use std::{
    collections::{BTreeSet, HashMap, HashSet},
    io, iter,
    path::{Path, PathBuf},
    str::FromStr,
};

use anyhow::{anyhow, Context, Result};
use cargo_lock::SourceId;
use cargo_metadata::{DepKindInfo, DependencyKind, Node, Package};
use cargo_platform::Platform;
use itertools::Itertools;

use crate::{
    context::{
        BuildableDependency, BuildableTarget, CrateContext, CrateDependencyContext,
        CrateTargetedDepContext, DependencyAlias, GitRepo, LicenseData, SourceDetails,
        WorkspaceContext,
    },
    error::{RazeError, PLEASE_FILE_A_BUG},
    metadata::RazeMetadata,
    planning::license,
    settings::{format_registry_url, CrateSettings, GenMode, RazeSettings},
    util,
};

use super::{
    crate_catalog::{CrateCatalog, CrateCatalogEntry},
    PlannedBuild,
};

/// Named type to reduce declaration noise for deducing the crate contexts
type CrateContextProduction = (Vec<CrateContext>, Vec<DependencyAlias>);

/// Utility type alias to reduce declaration noise
type DepProduction = HashMap<Option<String>, CrateDependencyContext>;

/// An internal working planner for generating context for an individual crate.
struct CrateSubplanner<'planner> {
    // Workspace-Wide details
    settings: &'planner RazeSettings,
    platform_details: &'planner Option<util::PlatformDetails>,
    crate_catalog: &'planner CrateCatalog,
    // Crate specific content
    crate_catalog_entry: &'planner CrateCatalogEntry,
    source_id: &'planner Option<SourceId>,
    node: &'planner Node,
    crate_settings: Option<&'planner CrateSettings>,
    sha256: &'planner Option<String>,
}

/// An internal working planner for generating context for a whole workspace.
pub struct WorkspaceSubplanner<'planner> {
    pub(super) settings: &'planner RazeSettings,
    pub(super) platform_details: &'planner Option<util::PlatformDetails>,
    pub(super) crate_catalog: &'planner CrateCatalog,
    pub(super) metadata: &'planner RazeMetadata,
}

impl<'planner> WorkspaceSubplanner<'planner> {
    /// Produces a planned build using internal state.
    pub fn produce_planned_build(&self) -> Result<PlannedBuild> {
        // Produce planned build
        let (crate_contexts, workspace_aliases) = self.produce_crate_contexts()?;

        Ok(PlannedBuild {
            workspace_context: self.produce_workspace_context(),
            crate_contexts,
            workspace_aliases,
            lockfile: self.metadata.lockfile.clone(),
        })
    }

    /// Constructs a workspace context from settings.
    fn produce_workspace_context(&self) -> WorkspaceContext {
        // Gather the workspace member paths for all workspace members
        let workspace_members = self
            .metadata
            .metadata
            .workspace_members
            .iter()
            .filter_map(|pkg_id| {
                let workspace_member = self
                    .metadata
                    .metadata
                    .packages
                    .iter()
                    .find(|pkg| pkg.id == *pkg_id);
                if let Some(pkg) = workspace_member {
                    util::get_workspace_member_path(
                        &pkg.manifest_path,
                        &self.metadata.metadata.workspace_root,
                    )
                } else {
                    None
                }
            })
            .collect();

        WorkspaceContext {
            workspace_path: self.settings.workspace_path.clone(),
            gen_workspace_prefix: self.settings.gen_workspace_prefix.clone(),
            output_buildfile_suffix: self.settings.output_buildfile_suffix.clone(),
            workspace_members,
        }
    }

    fn create_crate_context(
        &self,
        node: &Node,
        catalog: &CrateCatalog,
    ) -> Option<Result<(CrateContext, bool)>> {
        let own_crate_catalog_entry = catalog.entry_for_package_id(&node.id)?;
        let own_package = own_crate_catalog_entry.package();

        // Skip workspace members unless they are binary dependencies
        if own_crate_catalog_entry.is_workspace_crate() {
            return None;
        }

        // UNWRAP: Safe given unwrap during serialize step of metadata
        let own_source_id = own_package
            .source
            .as_ref()
            .map(|s| SourceId::from_url(&s.to_string()).unwrap());

        let crate_settings = self.crate_settings(&own_package).ok()?;

        let checksum_opt = self
            .metadata
            .checksum_for(&own_package.name, &own_package.version.to_string());

        let crate_subplanner = CrateSubplanner {
            crate_catalog: &catalog,
            settings: self.settings,
            platform_details: self.platform_details,
            crate_catalog_entry: &own_crate_catalog_entry,
            source_id: &own_source_id,
            node: &node,
            crate_settings,
            sha256: &checksum_opt.map(|c| c.to_owned()),
        };

        let res = crate_subplanner
            .produce_context(&self.metadata.cargo_workspace_root)
            .map(|x| (x, own_crate_catalog_entry.is_workspace_crate()));

        Some(res)
    }

    fn crate_settings(&self, package: &Package) -> Result<Option<&CrateSettings>> {
        self.settings
            .crates
            .get(&package.name)
            .map_or(Ok(None), |settings| {
                let mut versions = settings
                    .iter()
                    .filter(|(ver_req, _)| ver_req.matches(&package.version))
                    .peekable();

                match versions.next() {
                    // This is possible if the crate does not have any version overrides to match against
                    None => Ok(None),
                    Some((_, settings)) if versions.peek().is_none() => Ok(Some(settings)),
                    Some(current) => Err(RazeError::Config {
                        field_path_opt: None,
                        message: format!(
                            "Multiple potential semver matches `[{}]` found for `{}`",
                            iter::once(current).chain(versions).map(|x| x.0).join(", "),
                            &package.name
                        ),
                    }),
                }
            })
            .map_err(|e| e.into())
    }

    /// Produces a crate context for each declared crate and dependency.
    fn produce_crate_contexts(&self) -> Result<CrateContextProduction> {
        let contexts = self
            .crate_catalog
            .metadata
            .resolve
            .as_ref()
            .ok_or_else(|| RazeError::Generic("Missing resolve graph".into()))?
            .nodes
            .iter()
            .sorted_by_key(|n| &n.id)
            .filter_map(|node| self.create_crate_context(node, &self.crate_catalog))
            .collect::<Result<Vec<_>>>()?;

        let root_ctxs = contexts
            .iter()
            .filter_map(|(ctx, is_workspace)| match is_workspace {
                true => Some(ctx.default_deps.aliased_dependencies.clone()),
                false => None,
            })
            .flatten()
            .collect::<BTreeSet<_>>();

        let contexts = contexts.into_iter().map(|(ctx, _)| ctx).collect_vec();
        let aliases = self.produce_workspace_aliases(root_ctxs, &contexts);

        Ok((contexts, aliases))
    }

    fn produce_workspace_aliases(
        &self,
        root_dep_aliases: BTreeSet<DependencyAlias>,
        all_packages: &[CrateContext],
    ) -> Vec<DependencyAlias> {
        let renames = root_dep_aliases
            .iter()
            .map(|rename| (&rename.target, &rename.alias))
            .collect::<HashMap<_, _>>();

        all_packages
            .iter()
            .filter(|to_alias| to_alias.lib_target_name.is_some())
            .filter(|to_alias| to_alias.is_workspace_member_dependency)
            .flat_map(|to_alias| {
                let pkg_name = to_alias.pkg_name.replace("-", "_");
                let target = format!("{}:{}", &to_alias.workspace_path_to_crate, &pkg_name);
                let alias = renames
                    .get(&target)
                    .map(|x| x.to_string())
                    .unwrap_or(pkg_name);
                let dep_alias = DependencyAlias { alias, target };

                to_alias
                    .raze_settings
                    .extra_aliased_targets
                    .iter()
                    .map(move |extra_alias| DependencyAlias {
                        alias: extra_alias.clone(),
                        target: format!("{}:{}", &to_alias.workspace_path_to_crate, extra_alias),
                    })
                    .chain(std::iter::once(dep_alias))
            })
            .sorted()
            .collect_vec()
    }
}

impl<'planner> CrateSubplanner<'planner> {
    /// Builds a crate context from internal state.
    fn produce_context(&self, cargo_workspace_root: &Path) -> Result<CrateContext> {
        let package = self.crate_catalog_entry.package();

        let manifest_path = PathBuf::from(&package.manifest_path);
        assert!(manifest_path.is_absolute());
        let package_root = self.find_package_root_for_manifest(&manifest_path)?;

        let mut targets = self.produce_targets(&package_root)?;
        let build_script_target_opt = self.take_build_script_target(&mut targets);

        let lib_target_name = targets
            .iter()
            .find(|target| target.kind == "lib" || target.kind == "proc-macro")
            .map(|target| target.name.clone());

        let is_proc_macro = targets.iter().any(|target| target.kind == "proc-macro");

        let mut deps = self.produce_deps()?;

        // Take the default deps that are not bound to platform targets
        let default_deps = deps.remove(&None).unwrap_or_default();

        // Build a list of dependencies while addression a potential allowlist of target triples
        let mut targeted_deps = deps
            .into_iter()
            .map(|(target, deps)| {
                let target = target.unwrap();
                let platform_targets =
                    util::get_matching_bazel_triples(&target, &self.settings.targets)?
                        .map(|x| x.to_string())
                        .collect();

                Ok(CrateTargetedDepContext {
                    deps,
                    target,
                    platform_targets,
                })
            })
            .filter(|res| match res {
                Ok(ctx) => !ctx.platform_targets.is_empty(),
                Err(_) => true,
            })
            .collect::<Result<Vec<_>>>()?;

        targeted_deps.sort();

        let mut workspace_member_dependents: Vec<PathBuf> = Vec::new();
        let mut workspace_member_dev_dependents: Vec<PathBuf> = Vec::new();
        let mut workspace_member_build_dependents: Vec<PathBuf> = Vec::new();

        for pkg_id in self.crate_catalog_entry.workspace_member_dependents.iter() {
            let workspace_member = self
                .crate_catalog
                .metadata
                .packages
                .iter()
                .find(|pkg| pkg.id == *pkg_id);

            if let Some(member) = workspace_member {
                // UNWRAP: This should always return a dependency
                let current_dependency = member
                    .dependencies
                    .iter()
                    .find(|dep| dep.name == package.name)
                    .unwrap();

                let workspace_member_path = util::get_workspace_member_path(
                    &member.manifest_path,
                    &self.crate_catalog.metadata.workspace_root,
                )
                .ok_or_else(|| {
                    anyhow!(
                        "Failed to generate workspace_member_path for {} and {}",
                        &package.manifest_path,
                        &self.crate_catalog.metadata.workspace_root,
                    )
                })?;

                match current_dependency.kind {
                    DependencyKind::Development => {
                        workspace_member_dev_dependents.push(workspace_member_path)
                    }
                    DependencyKind::Normal => {
                        workspace_member_dependents.push(workspace_member_path)
                    }
                    DependencyKind::Build => {
                        workspace_member_build_dependents.push(workspace_member_path)
                    }
                    _ => {}
                }
            }
        }

        let is_workspace_member_dependency = !&workspace_member_dependents.is_empty()
            || !&workspace_member_dev_dependents.is_empty()
            || !&workspace_member_build_dependents.is_empty();

        // Generate canonicalized paths to additional build files so they're guaranteed to exist
        // and always locatable.
        let raze_settings = self.crate_settings.cloned().unwrap_or_default();
        let canonical_additional_build_file = match &raze_settings.additional_build_file {
            Some(build_file) => Some(
                cargo_workspace_root
                    .join(&build_file)
                    .canonicalize()
                    .with_context(|| {
                        format!(
                            "Failed to find additional_build_file: {}",
                            &build_file.display()
                        )
                    })?,
            ),
            None => None,
        };

        let context = CrateContext {
            pkg_name: package.name.clone(),
            pkg_version: package.version.clone(),
            edition: package.edition.clone(),
            license: self.produce_license(),
            features: self.node.features.clone(),
            workspace_member_dependents,
            workspace_member_dev_dependents,
            workspace_member_build_dependents,
            is_workspace_member_dependency,
            is_proc_macro,
            default_deps,
            targeted_deps,
            workspace_path_to_crate: self.crate_catalog_entry.workspace_path(&self.settings)?,
            build_script_target: build_script_target_opt,
            links: package.links.clone(),
            raze_settings,
            canonical_additional_build_file,
            source_details: self.produce_source_details(&package, &package_root),
            expected_build_path: self.crate_catalog_entry.local_build_path(&self.settings)?,
            sha256: self.sha256.clone(),
            registry_url: format_registry_url(
                &self.settings.registry,
                &package.name,
                &package.version.to_string(),
            ),
            lib_target_name,
            targets,
        };

        Ok(context)
    }

    /// Generates license data from internal crate details.
    fn produce_license(&self) -> LicenseData {
        let licenses_str = self
            .crate_catalog_entry
            .package()
            .license
            .as_ref()
            .map_or("", String::as_str);

        license::get_license_from_str(licenses_str)
    }

    /// Generates the set of dependencies for the contained crate.
    fn produce_deps(&self) -> Result<DepProduction> {
        let mut dep_production = DepProduction::new();

        let all_skipped_deps = self
            .crate_settings
            .iter()
            .flat_map(|pkg| pkg.skipped_deps.iter())
            .collect::<HashSet<_>>();

        // This wonderful part of the metadata gives us both renames and targets.
        //
        // Irritatingly its still a little tricky to detect renames fully, we need this to finally
        // deduce the aliases - see `is_renamed`.
        //
        // If https://github.com/rust-lang/cargo/issues/7289 gets solved then a lot of the left-over
        // rename detection code can get removed.
        for dep in &self.node.deps {
            // UNWRAP(s): Safe from verification of packages_by_id
            let dep_package = self
                .crate_catalog
                .entry_for_package_id(&dep.pkg)
                .unwrap()
                .package();

            // Skip settings-indicated deps to skip
            let pkg_id = util::package_ident(&dep_package.name, &dep_package.version.to_string());
            if all_skipped_deps.contains(&pkg_id) {
                continue;
            }

            // TODO(GregBowyer): Reimplement what cargo does to detect bad renames
            //
            // The problem manifests from this:
            //
            // ```toml
            // [dependencies]
            // bytes_new = { version = "0.3.0", package = "bytes" }
            // bytes_old = { version = "0.3.0", package = "bytes" }
            // ```
            //
            // Strictly this is an error. Right now cargo metadata will basically lose both bytes deps
            // from the resolve graph :gruntle: but a cargo build will scream about having the same basic
            // package with multiple names.
            //
            // Currently there is no good solution using metadata. Pull requests welcome!
            for dep_kind in &dep.dep_kinds {
                let platform_target = dep_kind.target.as_ref().map(|x| x.to_string());
                // Skip deps that fall out of targetting
                if !self.is_dep_targetted(platform_target.as_ref()) {
                    continue;
                }

                let mut dep_set = dep_production.entry(platform_target).or_default();
                self.process_dep(&mut dep_set, &dep.name, dep_kind, &dep_package)?
            }
        }

        for set in dep_production.values_mut() {
            set.build_proc_macro_dependencies.sort();
            set.build_dependencies.sort();
            set.dev_dependencies.sort();
            set.proc_macro_dependencies.sort();
            set.dependencies.sort();
        }

        Ok(dep_production)
    }

    fn process_dep(
        &self,
        dep_set: &mut CrateDependencyContext,
        name: &str,
        dep: &DepKindInfo,
        pkg: &Package,
    ) -> Result<()> {
        let is_proc_macro = self.is_proc_macro(pkg);
        let is_sys_crate = pkg.name.ends_with("-sys");

        let build_dep = BuildableDependency {
            name: pkg.name.clone(),
            version: pkg.version.clone(),
            buildable_target: self.buildable_target_for_dep(pkg)?,
            is_proc_macro,
        };

        use DependencyKind::*;
        match dep.kind {
            Build if is_proc_macro => dep_set.build_proc_macro_dependencies.push(build_dep),
            Build => dep_set.build_dependencies.push(build_dep),
            Development => dep_set.dev_dependencies.push(build_dep),
            Normal if is_proc_macro => dep_set.proc_macro_dependencies.push(build_dep),
            Normal => {
                // sys crates may generate DEP_* env vars that must be visible to direct dep builds
                if is_sys_crate {
                    dep_set.build_dependencies.push(build_dep.clone());
                }
                dep_set.dependencies.push(build_dep)
            }
            kind => {
                return Err(RazeError::Planning {
                    dependency_name_opt: Some(pkg.name.to_string()),
                    message: format!(
                        "Unhandlable dependency type {:?} on {} detected! {}",
                        kind, &pkg.name, PLEASE_FILE_A_BUG
                    ),
                }
                .into())
            }
        };

        if self.is_renamed(pkg) {
            let dep_alias = DependencyAlias {
                target: self.buildable_target_for_dep(pkg)?,
                alias: name.replace("-", "_"),
            };

            if !dep_set.aliased_dependencies.insert(dep_alias) {
                return Err(RazeError::Planning {
                    dependency_name_opt: Some(pkg.name.to_string()),
                    message: format!("Duplicated renamed package {}", name),
                }
                .into());
            }
        }

        Ok(())
    }

    /// Test to see if a dep has been renamed
    ///
    /// Currently cargo-metadata provides rename detection in a few places, we take the names
    /// from the resolution of a package
    fn is_renamed(&self, dep_package: &Package) -> bool {
        self.crate_catalog_entry
            .package()
            .dependencies
            .iter()
            .filter(|x| x.name == dep_package.name)
            .filter(|x| x.req.matches(&dep_package.version))
            .filter(|x| x.source == dep_package.source.as_ref().map(|src| src.to_string()))
            .find(|x| x.rename.is_some())
            .map_or(false, |x| x.rename.is_some())
    }

    fn is_dep_targetted(&self, target: Option<&String>) -> bool {
        target
            .map(|platform| {
                let potential_targets = self
                    .platform_details
                    .as_ref()
                    .zip(self.settings.target.as_ref());

                match potential_targets {
                    // Legacy behavior
                    Some((platform_details, settings_target)) => {
                        // Skip this dep if it doesn't match our platform attributes
                        // UNWRAP: It is reasonable to assume cargo is not giving us odd platform strings
                        let platform = Platform::from_str(platform).unwrap();
                        platform.matches(settings_target, platform_details.attrs())
                    }
                    None => {
                        util::is_bazel_supported_platform(platform)
                            != util::BazelTargetSupport::Unsupported
                    }
                }
            })
            .unwrap_or(true)
    }

    /// Test if the given dep details pertain to it being a proc-macro
    ///
    /// Implicitly dependencies are on the [lib] target from Cargo.toml (of which there is guaranteed
    /// to be at most one).
    ///
    /// We don't explicitly narrow to be considering only the [lib] Target - we rely on the fact that
    /// only one [lib] is allowed in a Package, and so treat the Package synonymously with the [lib]
    /// Target therein. Only the [lib] target is allowed to be labelled as a proc-macro, so checking
    /// if "any" target is a proc-macro is equivalent to checking if the [lib] target is a proc-macro
    /// (and accordingly, whether we need to treat this dep like a proc-macro).
    fn is_proc_macro(&self, dep_package: &Package) -> bool {
        dep_package
            .targets
            .iter()
            .flat_map(|target| target.crate_types.iter())
            .any(|crate_type| crate_type.as_str() == "proc-macro")
    }

    fn buildable_target_for_dep(&self, dep_package: &Package) -> Result<String> {
        // UNWRAP: Guaranteed to exist by checks in WorkspaceSubplanner#produce_build_plan
        self.crate_catalog
            .entry_for_package_id(&dep_package.id)
            .unwrap()
            .workspace_path_and_default_target(&self.settings)
    }

    /// Generates source details for internal crate.
    fn produce_source_details(&self, package: &Package, package_root: &Path) -> SourceDetails {
        SourceDetails {
            git_data: self.source_id.as_ref().filter(|id| id.is_git()).map(|id| {
                let manifest_parent = package.manifest_path.parent().unwrap();
                let path_to_crate_root = manifest_parent.strip_prefix(package_root).unwrap();
                let path_to_crate_root = if path_to_crate_root.components().next().is_some() {
                    Some(path_to_crate_root.to_string())
                } else {
                    None
                };
                GitRepo {
                    remote: id.url().to_string(),
                    commit: id.precise().unwrap().to_owned(),
                    path_to_crate_root,
                }
            }),
        }
    }

    /// Extracts the (one and only) build script target from the provided set of build targets.
    ///
    /// This function mutates the provided list of build arguments. It removes the first (and usually,
    /// only) found build script target.
    fn take_build_script_target(
        &self,
        all_targets: &mut Vec<BuildableTarget>,
    ) -> Option<BuildableTarget> {
        if !self
            .crate_settings
            .and_then(|x| x.gen_buildrs)
            .unwrap_or(self.settings.default_gen_buildrs)
        {
            return None;
        }

        all_targets
            .iter()
            .position(|t| t.kind == "custom-build")
            .map(|idx| all_targets.remove(idx))
    }

    /// Produces the complete set of build targets specified by this crate.
    /// This function may access the file system. See #find_package_root_for_manifest for more
    /// details.
    fn produce_targets(&self, package_root_path: &Path) -> Result<Vec<BuildableTarget>> {
        let mut targets = Vec::new();
        let package = self.crate_catalog_entry.package();
        for target in &package.targets {
            // Bazel uses / as a path delimiter, but / is not the path delimiter on all
            // operating systems (like Mac OS 9, or something people actually use like Windows).
            // Strip off the package root, decompose the path into parts and rejoin
            // them with '/'.
            let package_root_path_str = target
                .src_path
                .strip_prefix(package_root_path)
                .unwrap_or(&target.src_path)
                .components()
                .map(|c| c.as_os_str().to_str())
                .try_fold("".to_owned(), |res, v| Some(format!("{}/{}", res, v?)))
                .ok_or_else(|| {
                    io::Error::new(
                        io::ErrorKind::InvalidData,
                        format!(
                            "{:?} contains non UTF-8 characters and is not a legal path in Bazel",
                            &target.src_path
                        ),
                    )
                })?
                .trim_start_matches('/')
                .to_owned();

            for kind in &target.kind {
                targets.push(BuildableTarget {
                    name: target.name.clone(),
                    path: package_root_path_str.clone(),
                    kind: kind.clone(),
                    edition: target.edition.clone(),
                });
            }
        }

        targets.sort();
        Ok(targets)
    }

    /// Finds the root of a contained git package.
    /// This function needs to access the file system if the dependency is a git dependency in order
    /// to find the true filesystem root of the dependency. The root cause is that git dependencies
    /// often aren't solely the crate of interest, but rather a repository that contains the crate of
    /// interest among others.
    fn find_package_root_for_manifest(&self, manifest_path: &Path) -> Result<PathBuf> {
        let has_git_repo_root = {
            let is_git = self.source_id.as_ref().map_or(false, SourceId::is_git);
            is_git && self.settings.genmode == GenMode::Remote
        };

        // Return manifest path itself if not git
        if !has_git_repo_root {
            // TODO(acmcarther): How do we know parent is valid here?
            // UNWRAP: Pathbuf guaranteed to succeed from Path
            return Ok(PathBuf::from(manifest_path.parent().unwrap()));
        }

        // If package is git package it may be nested under a parent repository. We need to find the
        // package root.
        {
            let mut check_path = manifest_path;
            while let Some(c) = check_path.parent() {
                let joined = c.join(".git");
                if joined.is_dir() {
                    // UNWRAP: Pathbuf guaranteed to succeed from Path
                    return Ok(PathBuf::from(c));
                } else {
                    check_path = c;
                }
            }

            // Reached filesystem root and did not find Git repo
            Err(RazeError::Generic(format!(
                "Unable to locate git repository root for manifest at {:?}. {}",
                manifest_path, PLEASE_FILE_A_BUG
            ))
            .into())
        }
    }
}
