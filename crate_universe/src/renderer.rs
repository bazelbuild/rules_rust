use std::{
    collections::{BTreeMap, BTreeSet, HashMap, HashSet},
    fs::File,
    io::{BufReader, Write},
    path::Path,
};

use anyhow::Context;
use cargo_raze::context::{CrateContext, CrateDependencyContext, CrateTargetedDepContext};
use semver::Version;
use serde::{Deserialize, Serialize};
use tera::{self, Tera};

use crate::{config, resolver::Dependencies};

#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Deserialize, Serialize)]
pub struct RenderConfig {
    pub repo_rule_name: String,
    pub crate_registry_template: String,
    pub rules_rust_workspace_name: String,
}

#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Deserialize, Serialize)]
struct RenderContext {
    pub config: RenderConfig,
    pub hash: String,
    pub transitive_renderable_packages: Vec<RenderablePackage>,
    pub member_packages_version_mapping: Dependencies,
    pub label_to_crates: BTreeMap<String, BTreeSet<String>>,
}

pub struct Renderer {
    context: RenderContext,
    internal_renderer: Tera,
}

// Get default and targeted metadata, collated per Bazel condition (which corresponds to a triple).
// The default metadata is included in every triple.
fn get_per_triple_metadata(package: &CrateContext) -> BTreeMap<String, CrateTargetedDepContext> {
    let mut per_triple_metadata: BTreeMap<String, CrateTargetedDepContext> = BTreeMap::new();

    // Always add a catch-all to cover the non-targeted dep case.
    // We merge in the default_deps after the next loop.
    per_triple_metadata.insert(
        String::from("//conditions:default"),
        CrateTargetedDepContext {
            target: "Default".to_owned(),
            deps: empty_deps_context(),
            conditions: vec!["//conditions:default".to_owned()],
        },
    );

    for dep_context in &package.targeted_deps {
        dep_context.conditions.iter().for_each(|condition| {
            let targeted_dep_ctx = per_triple_metadata.entry(condition.to_owned()).or_insert(
                CrateTargetedDepContext {
                    target: "".to_owned(),
                    deps: empty_deps_context(),
                    conditions: vec![condition.clone()],
                },
            );

            // Mention all the targets that translated into the current condition (ie. current triplet).
            targeted_dep_ctx
                .target
                .push_str(&format!(" {}", &dep_context.target));

            targeted_dep_ctx
                .deps
                .dependencies
                .extend(dep_context.deps.dependencies.iter().cloned());
            targeted_dep_ctx
                .deps
                .proc_macro_dependencies
                .extend(dep_context.deps.proc_macro_dependencies.iter().cloned());
            targeted_dep_ctx
                .deps
                .data_dependencies
                .extend(dep_context.deps.data_dependencies.iter().cloned());
            targeted_dep_ctx
                .deps
                .build_dependencies
                .extend(dep_context.deps.build_dependencies.iter().cloned());
            targeted_dep_ctx.deps.build_proc_macro_dependencies.extend(
                dep_context
                    .deps
                    .build_proc_macro_dependencies
                    .iter()
                    .cloned(),
            );
            targeted_dep_ctx
                .deps
                .build_data_dependencies
                .extend(dep_context.deps.build_data_dependencies.iter().cloned());
            targeted_dep_ctx
                .deps
                .dev_dependencies
                .extend(dep_context.deps.dev_dependencies.iter().cloned());
            targeted_dep_ctx
                .deps
                .aliased_dependencies
                .extend(dep_context.deps.aliased_dependencies.iter().cloned());
        });
    }

    // Now also add the non-targeted deps to each target.
    for ctx in per_triple_metadata.values_mut() {
        ctx.deps
            .dependencies
            .extend(package.default_deps.dependencies.iter().cloned());
        ctx.deps
            .proc_macro_dependencies
            .extend(package.default_deps.proc_macro_dependencies.iter().cloned());
        ctx.deps
            .data_dependencies
            .extend(package.default_deps.data_dependencies.iter().cloned());
        ctx.deps
            .build_dependencies
            .extend(package.default_deps.build_dependencies.iter().cloned());
        ctx.deps.build_proc_macro_dependencies.extend(
            package
                .default_deps
                .build_proc_macro_dependencies
                .iter()
                .cloned(),
        );
        ctx.deps
            .build_data_dependencies
            .extend(package.default_deps.build_data_dependencies.iter().cloned());
        ctx.deps
            .dev_dependencies
            .extend(package.default_deps.dev_dependencies.iter().cloned());
        ctx.deps
            .aliased_dependencies
            .extend(package.default_deps.aliased_dependencies.iter().cloned());
    }

    per_triple_metadata
}

fn empty_deps_context() -> CrateDependencyContext {
    CrateDependencyContext {
        dependencies: vec![],
        proc_macro_dependencies: vec![],
        data_dependencies: vec![],
        build_dependencies: vec![],
        build_proc_macro_dependencies: vec![],
        build_data_dependencies: vec![],
        dev_dependencies: vec![],
        aliased_dependencies: vec![],
    }
}

impl Renderer {
    fn new_tera() -> Tera {
        let mut internal_renderer = Tera::new("src/not/a/dir/*").unwrap();

        internal_renderer.register_function(
            "crate_to_repo_rule_name",
            |args: &HashMap<String, tera::Value>| {
                let value = config::crate_to_repo_rule_name(
                    string_arg(args, "repo_rule_name")?,
                    string_arg(args, "package_name")?,
                    string_arg(args, "package_version")?,
                );
                Ok(tera::Value::String(value))
            },
        );

        internal_renderer.register_function(
            "crate_to_label",
            |args: &HashMap<String, tera::Value>| {
                let value = config::crate_to_label(
                    string_arg(args, "repo_rule_name")?,
                    string_arg(args, "package_name")?,
                    string_arg(args, "package_version")?,
                );
                Ok(tera::Value::String(value))
            },
        );

        internal_renderer
            .add_raw_templates(vec![
                (
                    "templates/lockfile.template",
                    include_str!("templates/lockfile.template"),
                ),
                (
                    "templates/helper_functions.template",
                    include_str!("templates/helper_functions.template"),
                ),
                (
                    "templates/partials/build_script.template",
                    include_str!("templates/partials/build_script.template"),
                ),
                (
                    "templates/partials/rust_binary.template",
                    include_str!("templates/partials/rust_binary.template"),
                ),
                (
                    "templates/partials/rust_library.template",
                    include_str!("templates/partials/rust_library.template"),
                ),
                (
                    "templates/partials/common_attrs.template",
                    include_str!("templates/partials/common_attrs.template"),
                ),
                (
                    "templates/crate.BUILD.template",
                    include_str!("templates/crate.BUILD.template"),
                ),
                (
                    "templates/partials/targeted_aliases.template",
                    include_str!("templates/partials/targeted_aliases.template"),
                ),
                (
                    "templates/partials/targeted_dependencies.template",
                    include_str!("templates/partials/targeted_dependencies.template"),
                ),
                (
                    "templates/partials/targeted_data_dependencies.template",
                    include_str!("templates/partials/targeted_data_dependencies.template"),
                ),
                (
                    "templates/partials/targeted_build_script_dependencies.template",
                    include_str!("templates/partials/targeted_build_script_dependencies.template"),
                ),
                (
                    "templates/partials/targeted_build_script_data_dependencies.template",
                    include_str!(
                        "templates/partials/targeted_build_script_data_dependencies.template"
                    ),
                ),
                (
                    "templates/partials/default_data_dependencies.template",
                    include_str!("templates/partials/default_data_dependencies.template"),
                ),
                (
                    "templates/partials/git_repository.template",
                    include_str!("templates/partials/git_repository.template"),
                ),
                (
                    "templates/partials/http_archive.template",
                    include_str!("templates/partials/http_archive.template"),
                ),
            ])
            .unwrap();

        internal_renderer
    }

    pub fn new(
        config: RenderConfig,
        hash: String,
        transitive_packages: Vec<CrateContext>,
        member_packages_version_mapping: Dependencies,
        label_to_crates: BTreeMap<String, BTreeSet<String>>,
    ) -> Renderer {
        let transitive_renderable_packages = transitive_packages
            .into_iter()
            .map(|mut crate_context| {
                let per_triple_metadata = get_per_triple_metadata(&crate_context);

                if let Some(git_repo) = &crate_context.source_details.git_data {
                    if let Some(prefix_to_strip) = &git_repo.path_to_crate_root {
                        for mut target in crate_context
                            .targets
                            .iter_mut()
                            .chain(crate_context.build_script_target.iter_mut())
                        {
                            let path = Path::new(&target.path);
                            let prefix_to_strip_path = Path::new(prefix_to_strip);
                            target.path = path
                                .strip_prefix(prefix_to_strip_path)
                                .unwrap()
                                .to_str()
                                .unwrap()
                                .to_owned();
                        }
                    }
                }

                let is_proc_macro = crate_context
                    .targets
                    .iter()
                    .any(|target| target.kind == "proc-macro");

                RenderablePackage {
                    crate_context,
                    per_triple_metadata,
                    is_proc_macro,
                }
            })
            .collect();

        Self {
            context: RenderContext {
                config,
                hash,
                transitive_renderable_packages,
                member_packages_version_mapping,
                label_to_crates,
            },
            internal_renderer: Renderer::new_tera(),
        }
    }

    pub fn new_from_lockfile(lockfile: &Path) -> anyhow::Result<Renderer> {
        // Open the file in read-only mode with buffer.
        let file = File::open(lockfile)?;
        let reader = BufReader::new(file);

        Ok(Self {
            context: serde_json::from_reader(reader)?,
            internal_renderer: Renderer::new_tera(),
        })
    }

    pub fn render<Out: Write>(&self, output: &mut Out) -> anyhow::Result<()> {
        self.render_workspaces(output)?;
        writeln!(output, "")?;
        self.render_helper_functions(output)?;

        Ok(())
    }

    pub fn render_lockfile(&self, lockfile_path: &Path) -> anyhow::Result<()> {
        let mut lockfile_file = std::fs::File::create(lockfile_path)
            .with_context(|| format!("Could not create lockfile file: {:?}", lockfile_path))?;
        let content = serde_json::to_string_pretty(&self.context)
            .with_context(|| format!("Could not seralize render context: {:?}", self.context))?;
        write!(lockfile_file, "{}\n", &content)?;

        Ok(())
    }

    // TODO: Public for `tests/renderer.rs`, unit tests should added here instead
    pub fn render_workspaces<Out: Write>(&self, output: &mut Out) -> anyhow::Result<()> {
        let mut context = tera::Context::new();
        context.insert("lockfile_hash", &self.context.hash);
        context.insert("crates", &self.context.transitive_renderable_packages);
        context.insert("repo_rule_name", &self.context.config.repo_rule_name);
        context.insert(
            "repository_http_template",
            &self.context.config.crate_registry_template,
        );
        let rendered_repository_rules = self
            .internal_renderer
            .render("templates/lockfile.template", &context)?;

        write!(output, "{}", &rendered_repository_rules)?;

        Ok(())
    }

    // TODO: Public for `tests/renderer.rs`, unit tests should added here instead
    pub fn render_helper_functions<Out: Write>(&self, output: &mut Out) -> anyhow::Result<()> {
        let mut crate_repo_names_inner = BTreeMap::new();
        crate_repo_names_inner.extend(&self.context.member_packages_version_mapping.normal);
        crate_repo_names_inner.extend(&self.context.member_packages_version_mapping.build);
        crate_repo_names_inner.extend(&self.context.member_packages_version_mapping.dev);

        let renderable_packages: Vec<_> = self
            .context
            .transitive_renderable_packages
            .iter()
            .filter(|krate| {
                crate_repo_names_inner.get(&krate.crate_context.pkg_name)
                    == Some(&&krate.crate_context.pkg_version)
            })
            .collect();

        let (proc_macro_crates, default_crates): (Vec<_>, Vec<_>) = self
            .context
            .member_packages_version_mapping
            .normal
            .iter()
            .partition(|(name, version)| {
                self.context
                    .transitive_renderable_packages
                    .iter()
                    .any(|package| {
                        *package.crate_context.pkg_name == **name
                            && package.crate_context.pkg_version == **version
                            && package.is_proc_macro
                    })
            });

        let mut kind_to_labels_to_crate_names = BTreeMap::new();
        kind_to_labels_to_crate_names
            .insert(Kind::Normal, self.label_to_crate_names(&default_crates));
        kind_to_labels_to_crate_names.insert(
            Kind::Dev,
            self.label_to_crate_names(
                &self
                    .context
                    .member_packages_version_mapping
                    .dev
                    .iter()
                    .collect(),
            ),
        );
        kind_to_labels_to_crate_names.insert(
            Kind::Build,
            self.label_to_crate_names(
                &self
                    .context
                    .member_packages_version_mapping
                    .build
                    .iter()
                    .collect(),
            ),
        );
        kind_to_labels_to_crate_names.insert(
            Kind::ProcMacro,
            self.label_to_crate_names(&proc_macro_crates),
        );

        let mut context = tera::Context::new();
        context.insert("crates", &renderable_packages);
        context.insert("repo_rule_name", &self.context.config.repo_rule_name);
        context.insert(
            "kind_to_labels_to_crate_names",
            &kind_to_labels_to_crate_names,
        );
        let rendered_helper_functions = self
            .internal_renderer
            .render("templates/helper_functions.template", &context)?;

        write!(output, "{}", &rendered_helper_functions)?;

        Ok(())
    }

    fn label_to_crate_names(
        &self,
        crates: &Vec<(&String, &Version)>,
    ) -> BTreeMap<String, Vec<String>> {
        let crate_names: HashSet<&String> = crates.iter().map(|(name, _)| *name).collect();
        self.context
            .label_to_crates
            .iter()
            .map(|(label, all_crates)| {
                let value = all_crates
                    .iter()
                    .filter(|crate_name| crate_names.contains(crate_name))
                    .map(|crate_name| crate_name.to_owned())
                    .collect::<Vec<_>>();
                (label.clone(), value)
            })
            .collect()
    }

    pub fn matches_digest(&self, digest: &str) -> bool {
        self.context.hash == digest
    }
}

fn string_arg<'a, 'b>(
    args: &'a HashMap<String, tera::Value>,
    name: &'b str,
) -> Result<&'a str, tera::Error> {
    let value = args
        .get(name)
        .ok_or_else(|| tera::Error::msg(&format!("Missing argument {:?}", name)))?;
    value.as_str().ok_or_else(|| {
        tera::Error::msg(&format!(
            "Wrong argument type, expected string for {:?}",
            name
        ))
    })
}

#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
struct RenderablePackage {
    crate_context: CrateContext,
    per_triple_metadata: BTreeMap<String, CrateTargetedDepContext>,
    is_proc_macro: bool,
}

#[derive(Hash, PartialEq, Eq, PartialOrd, Ord, Serialize)]
enum Kind {
    Normal,
    Dev,
    Build,
    ProcMacro,
}
