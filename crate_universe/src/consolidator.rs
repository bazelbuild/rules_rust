use std::collections::{BTreeMap, BTreeSet};

use anyhow::anyhow;

use crate::{
    context::CrateContext,
    renderer::{RenderConfig, Renderer},
    resolver::Dependencies,
};

#[derive(Debug, Default)]
pub struct ConsolidatorOverride {
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

    pub features_to_remove: BTreeSet<String>,
}

pub struct ConsolidatorConfig {
    // Mapping of crate name to override struct.
    pub overrides: BTreeMap<String, ConsolidatorOverride>,
}

pub struct Consolidator {
    consolidator_config: ConsolidatorConfig,
    render_config: RenderConfig,
    digest: String,
    resolved_packages: Vec<CrateContext>,
    member_packages_version_mapping: Dependencies,
    label_to_crates: BTreeMap<String, BTreeSet<String>>,
}

impl Consolidator {
    pub(crate) fn new(
        consolidator_config: ConsolidatorConfig,
        render_config: RenderConfig,
        digest: String,
        resolved_packages: Vec<CrateContext>,
        member_packages_version_mapping: Dependencies,
        label_to_crates: BTreeMap<String, BTreeSet<String>>,
    ) -> Self {
        Consolidator {
            consolidator_config,
            render_config,
            digest,
            resolved_packages,
            member_packages_version_mapping,
            label_to_crates,
        }
    }

    pub fn consolidate(self) -> anyhow::Result<Renderer> {
        let Self {
            mut consolidator_config,
            render_config,
            digest,
            mut resolved_packages,
            member_packages_version_mapping,
            label_to_crates,
        } = self;

        let mut names_and_versions_to_count = BTreeMap::new();
        for pkg in &resolved_packages {
            *names_and_versions_to_count
                .entry((pkg.pkg_name.clone(), pkg.pkg_version.clone()))
                .or_insert(0_usize) += 1_usize;
        }
        let duplicates: Vec<_> = names_and_versions_to_count
            .into_iter()
            .filter_map(|((name, version), value)| {
                if value > 1 {
                    Some(format!("{} {}", name, version))
                } else {
                    None
                }
            })
            .collect();
        if !duplicates.is_empty() {
            return Err(anyhow!(
                "Got duplicate sources for identical crate name and version combination{}: {}",
                if duplicates.len() == 1 { "" } else { "s" },
                duplicates.join(", ")
            ));
        }

        // Apply overrides specified in the crate_universe repo rule.
        for pkg in &mut resolved_packages {
            if let Some(overryde) = consolidator_config.overrides.remove(&pkg.pkg_name) {
                // Add extra dependencies.
                // TODO: What should this actually do?
                // pkg.targeted_deps.extend();
                // Add extra environment variables.
                pkg.raze_settings
                    .additional_env
                    .extend(overryde.extra_rustc_env_vars.into_iter());
                // Add extra build script environment variables.
                pkg.raze_settings
                    .buildrs_additional_environment_variables
                    .extend(overryde.extra_build_script_env_vars.into_iter());

                let features_to_remove = overryde.features_to_remove;
                pkg.features.retain(|f| !features_to_remove.contains(f));
            }
        }

        Ok(Renderer::new(
            render_config,
            digest,
            resolved_packages,
            member_packages_version_mapping,
            label_to_crates,
        ))
    }
}
