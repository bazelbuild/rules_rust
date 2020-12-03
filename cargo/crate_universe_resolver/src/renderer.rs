use cargo_raze::context::{CrateContext, CrateDependencyContext, CrateTargetedDepContext};
use semver::Version;
use std::collections::{BTreeMap, BTreeSet, HashMap, HashSet};
use std::fs::File;
use std::io::Write;
use tera::{self, Context, Tera};

use crate::config;
use crate::resolver::Dependencies;
use std::path::Path;

pub struct RenderConfig {
    pub repo_rule_name: String,
    pub repository_template: String,
    pub rules_rust_workspace_name: String,
}

pub struct Renderer {
    config: RenderConfig,
    hash: String,
    internal_renderer: Tera,
    transitive_packages: Vec<CrateContext>,
    member_packages_version_mapping: Dependencies,
    label_to_crates: BTreeMap<String, BTreeSet<String>>,
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
    pub fn new(
        config: RenderConfig,
        hash: String,
        transitive_packages: Vec<CrateContext>,
        member_packages_version_mapping: Dependencies,
        label_to_crates: BTreeMap<String, BTreeSet<String>>,
    ) -> Renderer {
        let mut internal_renderer = Tera::new("src/not/a/dir/*").unwrap();
        internal_renderer
            .add_raw_templates(vec![
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
            ])
            .unwrap();

        Self {
            config,
            hash,
            internal_renderer,
            transitive_packages,
            member_packages_version_mapping,
            label_to_crates,
        }
    }

    pub fn render(&self, mut output_file: &File) -> anyhow::Result<()> {
        let build_files = self
            .transitive_packages
            .iter()
            .map(|package| {
                let mut package = package;
                let per_triple_metadata = get_per_triple_metadata(&package);

                let mut backing_package;
                if let Some(git_repo) = &package.source_details.git_data {
                    if let Some(prefix_to_strip) = &git_repo.path_to_crate_root {
                        backing_package = package.clone();
                        for mut target in backing_package
                            .targets
                            .iter_mut()
                            .chain(backing_package.build_script_target.iter_mut())
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

                        package = &backing_package;
                    }
                }

                let mut context = Context::new();
                context.insert("crate", &package);
                context.insert("targeted_metadata", &per_triple_metadata);
                let rendered_crate_build_file = self
                    .internal_renderer
                    .render("templates/crate.BUILD.template", &context)?;
                // TODO: Write test which has transitive deps on two proc-macro2 0.1.10 and 1.0.21 which differ in build-script-having-ness.
                Ok((
                    (package.pkg_name.clone(), package.pkg_version.clone()),
                    rendered_crate_build_file,
                ))
            })
            .collect::<Result<HashMap<_, _>, tera::Error>>()?;

        write!(
            output_file,
            r#"# rules_rust crate_universe file format 1
# config hash {hash}

load("@bazel_tools//tools/build_defs/repo:git.bzl", "new_git_repository")

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

def pinned_rust_install():
"#,
            hash = self.hash,
        )?;
        for package in &self.transitive_packages {
            let package_version = format!("{}", package.pkg_version);
            if let Some(git_repo) = &package.source_details.git_data {
                write!(
                    output_file,
                    r#"    new_git_repository(
        name = "{repository_name}",
        strip_prefix = "{strip_prefix}",
        build_file_content = """{build_file_content}""",
        remote = "{git_remote}",
        # TODO: tag?
        commit = "{git_commit}",
    )

"#,
                    // TODO: Don't copy this implementation from workspace_path_and_default_target
                    repository_name =
                        config::crate_to_repo_rule_name(&self.config.repo_rule_name, &package.pkg_name, &package_version),
                    build_file_content = build_files
                        .get(&(package.pkg_name.clone(), package.pkg_version.clone()))
                        .unwrap(),
                    git_remote = git_repo.remote,
                    git_commit = git_repo.commit,
                    strip_prefix = git_repo.path_to_crate_root.clone().unwrap_or_default(),
                )?;
            } else {
                write!(
                    output_file,
                    r#"    http_archive(
        name = "{repository_name}",
        # TODO: Allow configuring where rust_library comes from
        build_file_content = """{build_file_content}""",{maybe_crate_sha256}
        strip_prefix = "{name}-{version}",
        type = "tar.gz",
        url = "{url}",
    )

"#,
                    // TODO: Don't copy this implementation from workspace_path_and_default_target
                    repository_name =
                        config::crate_to_repo_rule_name(&self.config.repo_rule_name, &package.pkg_name, &package_version),
                    name = package.pkg_name,
                    version = package.pkg_version,
                    maybe_crate_sha256 = if let Some(crate_sha256) = &package.sha256 {
                        format!("\n        sha256 = \"{}\",", crate_sha256)
                    } else {
                        String::new()
                    },
                    url = self
                        .config
                        .repository_template
                        .replace("{crate}", &package.pkg_name)
                        .replace("{version}", &package.pkg_version.to_string()),
                    build_file_content = build_files
                        .get(&(package.pkg_name.clone(), package.pkg_version.clone()))
                        .unwrap(),
                )?;
            }
        }

        let (proc_macro_crates, default_crates): (Vec<_>, Vec<_>) = self
            .member_packages_version_mapping
            .normal
            .iter()
            .partition(|(name, version)| {
                self.transitive_packages
                    .iter()
                    .find(|package| *package.pkg_name == **name && package.pkg_version == **version)
                    // UNWRAP: cargo-metadata should ensure any package we're looking up is in the transitive packages.
                    .unwrap()
                    .targets
                    .iter()
                    .any(|target| target.kind == "proc-macro")
            });

        let mut crate_repo_names_inner = BTreeMap::new();
        crate_repo_names_inner.extend(&self.member_packages_version_mapping.normal);
        crate_repo_names_inner.extend(&self.member_packages_version_mapping.build);
        crate_repo_names_inner.extend(&self.member_packages_version_mapping.dev);

        // Now, create the crate() macro for the user.
        write!(
            output_file,
            r##"
CRATE_TARGET_NAMES = {{
{crate_repo_names_inner}}}

def crate(crate_name):
    """Return the name of the target for the given crate.
    """
    target_name = CRATE_TARGET_NAMES.get(crate_name)
    if target_name == None:
        fail("Unknown crate name: {{}}".format(crate_name))
    return target_name

def all_deps():
    """Return all standard dependencies explicitly listed in the Cargo.toml or packages list."""
    return [
        crate(crate_name) for crate_name in [{crate_names}
        ]
    ]

def all_proc_macro_deps():
    """Return all proc-macro dependencies explicitly listed in the Cargo.toml or packages list."""
    return [
        crate(crate_name) for crate_name in [{proc_macro_crate_names}
        ]
    ]

def crates_from(label):
    mapping = {{
        {label_to_crates}
    }}
    return mapping[_absolutify(label)]

def dev_crates_from(label):
    mapping = {{
        {label_to_dev_crates}
    }}
    return mapping[_absolutify(label)]

def build_crates_from(label):
    mapping = {{
        {label_to_build_crates}
    }}
    return mapping[_absolutify(label)]

def proc_macro_crates_from(label):
    mapping = {{
        {label_to_proc_macro_crates}
    }}
    return mapping[_absolutify(label)]

def _absolutify(label):
    if label.startswith("//") or label.startswith("@"):
        return label
    if label.startswith(":"):
        return "//" + native.package_name() + label
    return "//" + native.package_name() + ":" + label
"##,
            crate_repo_names_inner = crate_repo_names_inner
                .iter()
                .map(|(crate_name, crate_version)| format!(
                    r#"    "{}": "{}",{newline}"#,
                    crate_name,
                    config::crate_to_label(&self.config.repo_rule_name, &crate_name, &crate_version.to_string()),
                    newline = '\n',
                ))
                .collect::<Vec<String>>()
                .join(""),
            crate_names = default_crates
                .iter()
                .map(|(crate_name, _crate_version)| format!(
                    r#"{newline}            "{}","#,
                    crate_name,
                    newline = '\n'
                ))
                .collect::<Vec<String>>()
                .join(""),
            proc_macro_crate_names = proc_macro_crates
                .iter()
                .map(|(crate_name, _crate_version)| format!(
                    r#"{newline}            "{}","#,
                    crate_name,
                    newline = '\n'
                ))
                .collect::<Vec<String>>()
                .join(""),
            label_to_crates =
                label_to_crates(&default_crates, &self.label_to_crates).join("\n    "),
            label_to_dev_crates = label_to_crates(
                &self.member_packages_version_mapping.dev.iter().collect(),
                &self.label_to_crates,
            )
            .join("\n    "),
            label_to_build_crates = label_to_crates(
                &self.member_packages_version_mapping.build.iter().collect(),
                &self.label_to_crates
            )
            .join("\n    "),
            label_to_proc_macro_crates =
                label_to_crates(&proc_macro_crates, &self.label_to_crates).join("\n    "),
        )?;
        Ok(())
    }
}

fn label_to_crates(
    crates: &Vec<(&String, &Version)>,
    label_to_crates: &BTreeMap<String, BTreeSet<String>>,
) -> Vec<String> {
    let crate_names: HashSet<&String> = crates.iter().map(|(name, _)| *name).collect();
    label_to_crates
        .iter()
        .map(|(label, all_crates)| {
            let values = all_crates
                .iter()
                .filter(|crate_name| crate_names.contains(crate_name))
                .map(|crate_name| format!(r#"crate("{}")"#, crate_name))
                .collect::<Vec<_>>()
                .join(", ");
            format!(r#""{label}": [{values}],"#, label = label, values = values)
        })
        .collect::<Vec<_>>()
}
