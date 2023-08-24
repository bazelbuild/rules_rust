//! Tools for rendering and writing BUILD and other Starlark files

mod template_engine;

use std::collections::{BTreeMap, BTreeSet};
use std::fs;
use std::iter::FromIterator;
use std::path::{Path, PathBuf};
use std::str::FromStr;

use anyhow::{bail, Context as AnyhowContext, Result};
use indoc::formatdoc;
use itertools::Itertools;

use crate::config::{RenderConfig, VendorMode};
use crate::context::crate_context::{CrateContext, CrateDependency, Rule};
use crate::context::{Context, TargetAttributes};
use crate::rendering::template_engine::TemplateEngine;
use crate::splicing::default_splicing_package_crate_id;
use crate::utils::starlark::{
    self, Alias, CargoBuildScript, CommonAttrs, Data, ExportsFiles, Filegroup, Glob, Label, Load,
    Package, RustBinary, RustLibrary, RustProcMacro, Select, SelectDict, SelectList, SelectMap,
    Starlark, TargetCompatibleWith,
};
use crate::utils::{self, sanitize_repository_name};

// Configuration remapper used to convert from cfg expressions like "cfg(unix)"
// to platform labels like "@rules_rust//rust/platform:x86_64-unknown-linux-gnu".
pub(crate) type Platforms = BTreeMap<String, BTreeSet<String>>;

pub struct Renderer {
    config: RenderConfig,
    supported_platform_triples: BTreeSet<String>,
    generate_target_compatible_with: bool,
    engine: TemplateEngine,
}

impl Renderer {
    pub fn new(
        config: RenderConfig,
        supported_platform_triples: BTreeSet<String>,
        generate_target_compatible_with: bool,
    ) -> Self {
        let engine = TemplateEngine::new(&config);
        Self {
            config,
            supported_platform_triples,
            generate_target_compatible_with,
            engine,
        }
    }

    pub fn render(&self, context: &Context) -> Result<BTreeMap<PathBuf, String>> {
        let mut output = BTreeMap::new();

        let platforms = self.render_platform_labels(context);
        output.extend(self.render_build_files(context, &platforms)?);
        output.extend(self.render_crates_module(context, &platforms)?);

        if let Some(vendor_mode) = &self.config.vendor_mode {
            match vendor_mode {
                crate::config::VendorMode::Local => {
                    // Nothing to do for local vendor crate
                }
                crate::config::VendorMode::Remote => {
                    output.extend(self.render_vendor_support_files(context)?);
                }
            }
        }

        Ok(output)
    }

    fn render_platform_labels(&self, context: &Context) -> BTreeMap<String, BTreeSet<String>> {
        context
            .conditions
            .iter()
            .map(|(cfg, triples)| {
                (
                    cfg.clone(),
                    triples
                        .iter()
                        .map(|triple| {
                            render_platform_constraint_label(
                                &self.config.platforms_template,
                                triple,
                            )
                        })
                        .collect(),
                )
            })
            .collect()
    }

    fn render_crates_module(
        &self,
        context: &Context,
        platforms: &Platforms,
    ) -> Result<BTreeMap<PathBuf, String>> {
        let module_label = render_module_label(&self.config.crates_module_template, "defs.bzl")
            .context("Failed to resolve string to module file label")?;
        let module_build_label =
            render_module_label(&self.config.crates_module_template, "BUILD.bazel")
                .context("Failed to resolve string to module file label")?;

        let mut map = BTreeMap::new();
        map.insert(
            Renderer::label_to_path(&module_label),
            self.engine.render_module_bzl(context, platforms)?,
        );
        map.insert(
            Renderer::label_to_path(&module_build_label),
            self.render_module_build_file(context)?,
        );

        Ok(map)
    }

    fn render_module_build_file(&self, context: &Context) -> Result<String> {
        let mut starlark = Vec::new();

        // Banner comment for top of the file.
        let header = self.engine.render_header()?;
        starlark.push(Starlark::Verbatim(header));

        // Package visibility, exported bzl files.
        let package = Package::default_visibility_public();
        starlark.push(Starlark::Package(package));

        let mut exports_files = ExportsFiles {
            paths: BTreeSet::from(["cargo-bazel.json".to_owned(), "defs.bzl".to_owned()]),
            globs: Glob {
                include: BTreeSet::from(["*.bazel".to_owned()]),
                exclude: BTreeSet::new(),
            },
        };
        if let Some(VendorMode::Remote) = self.config.vendor_mode {
            exports_files.paths.insert("crates.bzl".to_owned());
        }
        starlark.push(Starlark::ExportsFiles(exports_files));

        let filegroup = Filegroup {
            name: "srcs".to_owned(),
            srcs: Glob {
                include: BTreeSet::from(["*.bazel".to_owned(), "*.bzl".to_owned()]),
                exclude: BTreeSet::new(),
            },
        };
        starlark.push(Starlark::Filegroup(filegroup));

        // An `alias` for each direct dependency of a workspace member crate.
        let mut dependencies = Vec::new();
        for dep in context.workspace_member_deps() {
            let krate = &context.crates[&dep.id];
            if let Some(library_target_name) = &krate.library_target_name {
                let rename = dep.alias.as_ref().unwrap_or(&krate.name);
                dependencies.push(Alias {
                    // If duplicates exist, include version to disambiguate them.
                    name: if context.has_duplicate_workspace_member_dep(dep) {
                        format!("{}-{}", rename, krate.version)
                    } else {
                        rename.clone()
                    },
                    actual: self.crate_label(&krate.name, &krate.version, library_target_name),
                    tags: BTreeSet::from(["manual".to_owned()]),
                });
            }

            for (alias, target) in &krate.extra_aliased_targets {
                dependencies.push(Alias {
                    name: alias.clone(),
                    actual: self.crate_label(&krate.name, &krate.version, target),
                    tags: BTreeSet::from(["manual".to_owned()]),
                });
            }
        }

        let duplicates: Vec<_> = dependencies
            .iter()
            .map(|alias| &alias.name)
            .duplicates()
            .sorted()
            .collect();

        assert!(
            duplicates.is_empty(),
            "Found duplicate aliases that must be changed (Check your `extra_aliased_targets`): {:#?}",
            duplicates
        );

        if !dependencies.is_empty() {
            let comment = "# Workspace Member Dependencies".to_owned();
            starlark.push(Starlark::Verbatim(comment));
            starlark.extend(dependencies.into_iter().map(Starlark::Alias));
        }

        // An `alias` for each binary dependency.
        let mut binaries = Vec::new();
        for crate_id in &context.binary_crates {
            let krate = &context.crates[crate_id];
            for rule in &krate.targets {
                if let Rule::Binary(bin) = rule {
                    binaries.push(Alias {
                        // If duplicates exist, include version to disambiguate them.
                        name: if context.has_duplicate_binary_crate(crate_id) {
                            format!("{}-{}__{}", krate.name, krate.version, bin.crate_name)
                        } else {
                            format!("{}__{}", krate.name, bin.crate_name)
                        },
                        actual: self.crate_label(
                            &krate.name,
                            &krate.version,
                            &format!("{}__bin", bin.crate_name),
                        ),
                        tags: BTreeSet::from(["manual".to_owned()]),
                    });
                }
            }
        }
        if !binaries.is_empty() {
            let comment = "# Binaries".to_owned();
            starlark.push(Starlark::Verbatim(comment));
            starlark.extend(binaries.into_iter().map(Starlark::Alias));
        }

        let starlark = starlark::serialize(&starlark)?;
        Ok(starlark)
    }

    fn render_build_files(
        &self,
        context: &Context,
        platforms: &Platforms,
    ) -> Result<BTreeMap<PathBuf, String>> {
        let default_splicing_package_id = default_splicing_package_crate_id();
        context
            .crates
            .keys()
            // Do not render the default splicing package
            .filter(|id| *id != &default_splicing_package_id)
            // Do not render local packages
            .filter(|id| !context.workspace_members.contains_key(id))
            .map(|id| {
                let label = match render_build_file_template(
                    &self.config.build_file_template,
                    &id.name,
                    &id.version,
                ) {
                    Ok(label) => label,
                    Err(e) => bail!(e),
                };

                let filename = Renderer::label_to_path(&label);
                let content = self.render_one_build_file(platforms, &context.crates[id])?;
                Ok((filename, content))
            })
            .collect()
    }

    fn render_one_build_file(&self, platforms: &Platforms, krate: &CrateContext) -> Result<String> {
        let mut starlark = Vec::new();

        // Banner comment for top of the file.
        let header = self.engine.render_header()?;
        starlark.push(Starlark::Verbatim(header));

        // Loads: map of bzl file to set of items imported from that file. These
        // get inserted into `starlark` at the bottom of this function.
        let mut loads: BTreeMap<String, BTreeSet<String>> = BTreeMap::new();
        let mut load = |bzl: &str, item: &str| {
            loads
                .entry(bzl.to_owned())
                .or_default()
                .insert(item.to_owned())
        };

        let disable_visibility = "# buildifier: disable=bzl-visibility".to_owned();
        starlark.push(Starlark::Verbatim(disable_visibility));
        starlark.push(Starlark::Load(Load {
            bzl: "@rules_rust//crate_universe/private:selects.bzl".to_owned(),
            items: BTreeSet::from(["selects".to_owned()]),
        }));

        // Package visibility.
        let package = Package::default_visibility_public();
        starlark.push(Starlark::Package(package));

        if let Some(license) = &krate.license {
            starlark.push(Starlark::Verbatim(formatdoc! {r#"
                # licenses([
                #     "TODO",  # {license}
                # ])
            "#}));
        }

        for rule in &krate.targets {
            match rule {
                Rule::BuildScript(target) => {
                    load("@rules_rust//cargo:defs.bzl", "cargo_build_script");
                    let cargo_build_script =
                        self.make_cargo_build_script(platforms, krate, target)?;
                    starlark.push(Starlark::CargoBuildScript(cargo_build_script));
                    starlark.push(Starlark::Alias(Alias {
                        name: target.crate_name.clone(),
                        actual: format!("{}_build_script", krate.name),
                        tags: BTreeSet::from(["manual".to_owned()]),
                    }));
                }
                Rule::ProcMacro(target) => {
                    load("@rules_rust//rust:defs.bzl", "rust_proc_macro");
                    let rust_proc_macro = self.make_rust_proc_macro(platforms, krate, target)?;
                    starlark.push(Starlark::RustProcMacro(rust_proc_macro));
                }
                Rule::Library(target) => {
                    load("@rules_rust//rust:defs.bzl", "rust_library");
                    let rust_library = self.make_rust_library(platforms, krate, target)?;
                    starlark.push(Starlark::RustLibrary(rust_library));
                }
                Rule::Binary(target) => {
                    load("@rules_rust//rust:defs.bzl", "rust_binary");
                    let rust_binary = self.make_rust_binary(platforms, krate, target)?;
                    starlark.push(Starlark::RustBinary(rust_binary));
                }
            }
        }

        if let Some(additive_build_file_content) = &krate.additive_build_file_content {
            let comment = "# Additive BUILD file content".to_owned();
            starlark.push(Starlark::Verbatim(comment));
            starlark.push(Starlark::Verbatim(additive_build_file_content.clone()));
        }

        // Insert all the loads immediately after the header banner comment.
        let loads = loads
            .into_iter()
            .map(|(bzl, items)| Starlark::Load(Load { bzl, items }));
        starlark.splice(1..1, loads);

        let starlark = starlark::serialize(&starlark)?;
        Ok(starlark)
    }

    fn make_cargo_build_script(
        &self,
        platforms: &Platforms,
        krate: &CrateContext,
        target: &TargetAttributes,
    ) -> Result<CargoBuildScript> {
        let empty_set = BTreeSet::<String>::new();
        let empty_list = SelectList::<String>::default();
        let empty_deps = SelectList::<CrateDependency>::default();
        let attrs = krate.build_script_attrs.as_ref();

        Ok(CargoBuildScript {
            // Because `cargo_build_script` does some invisible target name
            // mutating to determine the package and crate name for a build
            // script, the Bazel target name of any build script cannot be the
            // Cargo canonical name of "cargo_build_script" without losing out
            // on having certain Cargo environment variables set.
            //
            // Do not change this name to "cargo_build_script".
            name: format!("{}_build_script", krate.name),
            aliases: self
                .make_aliases(krate, true, false)
                .remap_configurations(platforms),
            build_script_env: attrs
                .map_or_else(SelectDict::default, |attrs| attrs.build_script_env.clone())
                .remap_configurations(platforms),
            compile_data: make_data(
                platforms,
                &empty_set,
                attrs.map_or(&empty_list, |attrs| &attrs.compile_data),
            ),
            crate_features: SelectList::from(&krate.common_attrs.crate_features)
                .map_configuration_names(|triple| {
                    render_platform_constraint_label(&self.config.platforms_template, &triple)
                }),
            crate_name: utils::sanitize_module_name(&target.crate_name),
            crate_root: target.crate_root.clone(),
            data: make_data(
                platforms,
                attrs.map_or(&empty_set, |attrs| &attrs.data_glob),
                attrs.map_or(&empty_list, |attrs| &attrs.data),
            ),
            deps: self
                .make_deps(
                    attrs.map_or(&empty_deps, |attrs| &attrs.deps),
                    attrs.map_or(&empty_set, |attrs| &attrs.extra_deps),
                )
                .remap_configurations(platforms),
            link_deps: self
                .make_deps(
                    attrs.map_or(&empty_deps, |attrs| &attrs.link_deps),
                    attrs.map_or(&empty_set, |attrs| &attrs.extra_link_deps),
                )
                .remap_configurations(platforms),
            edition: krate.common_attrs.edition.clone(),
            linker_script: krate.common_attrs.linker_script.clone(),
            links: attrs.and_then(|attrs| attrs.links.clone()),
            proc_macro_deps: self
                .make_deps(
                    attrs.map_or(&empty_deps, |attrs| &attrs.proc_macro_deps),
                    attrs.map_or(&empty_set, |attrs| &attrs.extra_proc_macro_deps),
                )
                .remap_configurations(platforms),
            rustc_env: attrs
                .map_or_else(SelectDict::default, |attrs| attrs.rustc_env.clone())
                .remap_configurations(platforms),
            rustc_env_files: attrs
                .map_or_else(SelectList::default, |attrs| attrs.rustc_env_files.clone())
                .remap_configurations(platforms),
            rustc_flags: {
                let mut rustc_flags =
                    attrs.map_or_else(SelectList::default, |attrs| attrs.rustc_flags.clone());
                // In most cases, warnings in 3rd party crates are not
                // interesting as they're out of the control of consumers. The
                // flag here silences warnings. For more details see:
                // https://doc.rust-lang.org/rustc/lints/levels.html
                rustc_flags.insert("--cap-lints=allow".to_owned(), None);
                rustc_flags.remap_configurations(platforms)
            },
            srcs: target.srcs.clone(),
            tags: {
                let mut tags = BTreeSet::from_iter(krate.common_attrs.tags.iter().cloned());
                tags.insert("cargo-bazel".to_owned());
                tags.insert("manual".to_owned());
                tags.insert("noclippy".to_owned());
                tags.insert("norustfmt".to_owned());
                tags.insert(format!("crate-name={}", krate.name));
                tags
            },
            tools: attrs
                .map_or_else(SelectList::default, |attrs| attrs.tools.clone())
                .remap_configurations(platforms),
            toolchains: attrs.map_or_else(BTreeSet::new, |attrs| attrs.toolchains.clone()),
            version: krate.common_attrs.version.clone(),
            visibility: BTreeSet::from(["//visibility:private".to_owned()]),
        })
    }

    fn make_rust_proc_macro(
        &self,
        platforms: &Platforms,
        krate: &CrateContext,
        target: &TargetAttributes,
    ) -> Result<RustProcMacro> {
        Ok(RustProcMacro {
            name: target.crate_name.clone(),
            deps: self
                .make_deps(&krate.common_attrs.deps, &krate.common_attrs.extra_deps)
                .remap_configurations(platforms),
            proc_macro_deps: self
                .make_deps(
                    &krate.common_attrs.proc_macro_deps,
                    &krate.common_attrs.extra_proc_macro_deps,
                )
                .remap_configurations(platforms),
            aliases: self
                .make_aliases(krate, false, false)
                .remap_configurations(platforms),
            common: self.make_common_attrs(platforms, krate, target)?,
        })
    }

    fn make_rust_library(
        &self,
        platforms: &Platforms,
        krate: &CrateContext,
        target: &TargetAttributes,
    ) -> Result<RustLibrary> {
        Ok(RustLibrary {
            name: target.crate_name.clone(),
            deps: self
                .make_deps(&krate.common_attrs.deps, &krate.common_attrs.extra_deps)
                .remap_configurations(platforms),
            proc_macro_deps: self
                .make_deps(
                    &krate.common_attrs.proc_macro_deps,
                    &krate.common_attrs.extra_proc_macro_deps,
                )
                .remap_configurations(platforms),
            aliases: self
                .make_aliases(krate, false, false)
                .remap_configurations(platforms),
            common: self.make_common_attrs(platforms, krate, target)?,
            disable_pipelining: krate.disable_pipelining,
        })
    }

    fn make_rust_binary(
        &self,
        platforms: &Platforms,
        krate: &CrateContext,
        target: &TargetAttributes,
    ) -> Result<RustBinary> {
        Ok(RustBinary {
            name: format!("{}__bin", target.crate_name),
            deps: {
                let mut deps =
                    self.make_deps(&krate.common_attrs.deps, &krate.common_attrs.extra_deps);
                if let Some(library_target_name) = &krate.library_target_name {
                    deps.insert(format!(":{library_target_name}"), None);
                }
                deps.remap_configurations(platforms)
            },
            proc_macro_deps: self
                .make_deps(
                    &krate.common_attrs.proc_macro_deps,
                    &krate.common_attrs.extra_proc_macro_deps,
                )
                .remap_configurations(platforms),
            aliases: self
                .make_aliases(krate, false, false)
                .remap_configurations(platforms),
            common: self.make_common_attrs(platforms, krate, target)?,
        })
    }

    fn make_common_attrs(
        &self,
        platforms: &Platforms,
        krate: &CrateContext,
        target: &TargetAttributes,
    ) -> Result<CommonAttrs> {
        Ok(CommonAttrs {
            compile_data: make_data(
                platforms,
                &krate.common_attrs.compile_data_glob,
                &krate.common_attrs.compile_data,
            ),
            crate_features: SelectList::from(&krate.common_attrs.crate_features)
                .map_configuration_names(|triple| {
                    render_platform_constraint_label(&self.config.platforms_template, &triple)
                }),
            crate_root: target.crate_root.clone(),
            data: make_data(
                platforms,
                &krate.common_attrs.data_glob,
                &krate.common_attrs.data,
            ),
            edition: krate.common_attrs.edition.clone(),
            linker_script: krate.common_attrs.linker_script.clone(),
            rustc_env: krate
                .common_attrs
                .rustc_env
                .clone()
                .remap_configurations(platforms),
            rustc_env_files: krate
                .common_attrs
                .rustc_env_files
                .clone()
                .remap_configurations(platforms),
            rustc_flags: {
                let mut rustc_flags = krate.common_attrs.rustc_flags.clone();
                // In most cases, warnings in 3rd party crates are not
                // interesting as they're out of the control of consumers. The
                // flag here silences warnings. For more details see:
                // https://doc.rust-lang.org/rustc/lints/levels.html
                rustc_flags.insert(0, "--cap-lints=allow".to_owned());
                rustc_flags
            },
            srcs: target.srcs.clone(),
            tags: {
                let mut tags = BTreeSet::from_iter(krate.common_attrs.tags.iter().cloned());
                tags.insert("cargo-bazel".to_owned());
                tags.insert("manual".to_owned());
                tags.insert("noclippy".to_owned());
                tags.insert("norustfmt".to_owned());
                tags.insert(format!("crate-name={}", krate.name));
                tags
            },
            target_compatible_with: self.generate_target_compatible_with.then(|| {
                TargetCompatibleWith::new(
                    self.supported_platform_triples
                        .iter()
                        .map(|triple| {
                            render_platform_constraint_label(
                                &self.config.platforms_template,
                                triple,
                            )
                        })
                        .collect(),
                )
            }),
            version: krate.common_attrs.version.clone(),
        })
    }

    /// Filter a crate's dependencies to only ones with aliases
    fn make_aliases(
        &self,
        krate: &CrateContext,
        build: bool,
        include_dev: bool,
    ) -> SelectDict<String> {
        let mut dep_lists = Vec::new();
        if build {
            if let Some(build_script_attrs) = &krate.build_script_attrs {
                dep_lists.push(&build_script_attrs.deps);
                dep_lists.push(&build_script_attrs.proc_macro_deps);
            }
        } else {
            dep_lists.push(&krate.common_attrs.deps);
            dep_lists.push(&krate.common_attrs.proc_macro_deps);
            if include_dev {
                dep_lists.push(&krate.common_attrs.deps_dev);
                dep_lists.push(&krate.common_attrs.proc_macro_deps_dev);
            }
        }

        let mut aliases = SelectDict::default();
        for (dep, conf) in dep_lists.into_iter().flat_map(|deps| {
            deps.configurations().into_iter().flat_map(move |conf| {
                deps.get_iter(conf)
                    .expect("Iterating over known keys should never panic")
                    .map(move |dep| (dep, conf))
            })
        }) {
            if let Some(alias) = &dep.alias {
                let label = self.crate_label(&dep.id.name, &dep.id.version, &dep.target);
                aliases.insert(label, alias.clone(), conf.cloned());
            }
        }
        aliases
    }

    fn make_deps(
        &self,
        deps: &SelectList<CrateDependency>,
        extra_deps: &BTreeSet<String>,
    ) -> SelectList<String> {
        let mut deps = deps
            .clone()
            .map(|dep| self.crate_label(&dep.id.name, &dep.id.version, &dep.target));
        for extra_dep in extra_deps {
            deps.insert(extra_dep.clone(), None);
        }
        deps
    }

    fn render_vendor_support_files(&self, context: &Context) -> Result<BTreeMap<PathBuf, String>> {
        let module_label = render_module_label(&self.config.crates_module_template, "crates.bzl")
            .context("Failed to resolve string to module file label")?;

        let mut map = BTreeMap::new();
        map.insert(
            Renderer::label_to_path(&module_label),
            self.engine.render_vendor_module_file(context)?,
        );

        Ok(map)
    }

    fn label_to_path(label: &Label) -> PathBuf {
        match &label.package {
            Some(package) => PathBuf::from(format!("{}/{}", package, label.target)),
            None => PathBuf::from(&label.target),
        }
    }

    fn crate_label(&self, name: &str, version: &str, target: &str) -> String {
        sanitize_repository_name(&render_crate_bazel_label(
            &self.config.crate_label_template,
            &self.config.repository_name,
            name,
            version,
            target,
        ))
    }
}

/// Write a set of [crate::context::crate_context::CrateContext] to disk.
pub fn write_outputs(
    outputs: BTreeMap<PathBuf, String>,
    out_dir: &Path,
    dry_run: bool,
) -> Result<()> {
    let outputs: BTreeMap<PathBuf, String> = outputs
        .into_iter()
        .map(|(path, content)| (out_dir.join(path), content))
        .collect();

    if dry_run {
        for (path, content) in outputs {
            println!(
                "==============================================================================="
            );
            println!("{}", path.display());
            println!(
                "==============================================================================="
            );
            println!("{content}\n");
        }
    } else {
        for (path, content) in outputs {
            // Ensure the output directory exists
            fs::create_dir_all(
                path.parent()
                    .expect("All file paths should have valid directories"),
            )?;

            fs::write(&path, content.as_bytes())
                .context(format!("Failed to write file to disk: {}", path.display()))?;
        }
    }

    Ok(())
}

/// Render the Bazel label of a crate
pub fn render_crate_bazel_label(
    template: &str,
    repository_name: &str,
    name: &str,
    version: &str,
    target: &str,
) -> String {
    template
        .replace("{repository}", repository_name)
        .replace("{name}", name)
        .replace("{version}", version)
        .replace("{target}", target)
}

/// Render the Bazel label of a crate
pub fn render_crate_bazel_repository(
    template: &str,
    repository_name: &str,
    name: &str,
    version: &str,
) -> String {
    template
        .replace("{repository}", repository_name)
        .replace("{name}", name)
        .replace("{version}", version)
}

/// Render the Bazel label of a crate
pub fn render_crate_build_file(template: &str, name: &str, version: &str) -> String {
    template
        .replace("{name}", name)
        .replace("{version}", version)
}

/// Render the Bazel label of a vendor module label
pub fn render_module_label(template: &str, name: &str) -> Result<Label> {
    Label::from_str(&template.replace("{file}", name))
}

/// Render the Bazel label of a platform triple
fn render_platform_constraint_label(template: &str, triple: &str) -> String {
    template.replace("{triple}", triple)
}

fn render_build_file_template(template: &str, name: &str, version: &str) -> Result<Label> {
    Label::from_str(
        &template
            .replace("{name}", name)
            .replace("{version}", version),
    )
}

fn make_data(platforms: &Platforms, glob: &BTreeSet<String>, select: &SelectList<String>) -> Data {
    const COMMON_GLOB_EXCLUDES: &[&str] = &[
        "**/* *",
        "BUILD.bazel",
        "BUILD",
        "WORKSPACE.bazel",
        "WORKSPACE",
        ".tmp_git_root/**/*",
    ];

    Data {
        glob: Glob {
            include: glob.clone(),
            exclude: COMMON_GLOB_EXCLUDES
                .iter()
                .map(|&glob| glob.to_owned())
                .collect(),
        },
        select: select.clone().remap_configurations(platforms),
    }
}

#[cfg(test)]
mod test {
    use super::*;

    use indoc::indoc;
    use std::collections::BTreeSet;

    use crate::config::{Config, CrateId, VendorMode};
    use crate::context::crate_context::{CrateContext, Rule};
    use crate::context::{
        BuildScriptAttributes, CommonAttributes, Context, CrateFeatures, TargetAttributes,
    };
    use crate::metadata::Annotations;
    use crate::test;
    use crate::utils::starlark::SelectList;

    fn mock_target_attributes() -> TargetAttributes {
        TargetAttributes {
            crate_name: "mock_crate".to_owned(),
            crate_root: Some("src/root.rs".to_owned()),
            ..TargetAttributes::default()
        }
    }

    fn mock_render_config(vendor_mode: Option<VendorMode>) -> RenderConfig {
        RenderConfig {
            repository_name: "test_rendering".to_owned(),
            regen_command: "cargo_bazel_regen_command".to_owned(),
            vendor_mode,
            ..RenderConfig::default()
        }
    }

    fn mock_supported_platform_triples() -> BTreeSet<String> {
        BTreeSet::from([
            "aarch64-apple-darwin".to_owned(),
            "aarch64-apple-ios".to_owned(),
            "aarch64-linux-android".to_owned(),
            "aarch64-pc-windows-msvc".to_owned(),
            "aarch64-unknown-linux-gnu".to_owned(),
            "arm-unknown-linux-gnueabi".to_owned(),
            "armv7-unknown-linux-gnueabi".to_owned(),
            "i686-apple-darwin".to_owned(),
            "i686-linux-android".to_owned(),
            "i686-pc-windows-msvc".to_owned(),
            "i686-unknown-freebsd".to_owned(),
            "i686-unknown-linux-gnu".to_owned(),
            "powerpc-unknown-linux-gnu".to_owned(),
            "s390x-unknown-linux-gnu".to_owned(),
            "wasm32-unknown-unknown".to_owned(),
            "wasm32-wasi".to_owned(),
            "x86_64-apple-darwin".to_owned(),
            "x86_64-apple-ios".to_owned(),
            "x86_64-linux-android".to_owned(),
            "x86_64-pc-windows-msvc".to_owned(),
            "x86_64-unknown-freebsd".to_owned(),
            "x86_64-unknown-linux-gnu".to_owned(),
        ])
    }

    #[test]
    fn render_rust_library() {
        let mut context = Context::default();
        let crate_id = CrateId::new("mock_crate".to_owned(), "0.1.0".to_owned());
        context.crates.insert(
            crate_id.clone(),
            CrateContext {
                name: crate_id.name,
                version: crate_id.version,
                targets: BTreeSet::from([Rule::Library(mock_target_attributes())]),
                ..CrateContext::default()
            },
        );

        let renderer = Renderer::new(
            mock_render_config(None),
            mock_supported_platform_triples(),
            true,
        );
        let output = renderer.render(&context).unwrap();

        let build_file_content = output
            .get(&PathBuf::from("BUILD.mock_crate-0.1.0.bazel"))
            .unwrap();

        assert!(build_file_content.contains("rust_library("));
        assert!(build_file_content.contains("name = \"mock_crate\""));
        assert!(build_file_content.contains("\"crate-name=mock_crate\""));
    }

    #[test]
    fn test_disable_pipelining() {
        let mut context = Context::default();
        let crate_id = CrateId::new("mock_crate".to_owned(), "0.1.0".to_owned());
        context.crates.insert(
            crate_id.clone(),
            CrateContext {
                name: crate_id.name,
                version: crate_id.version,
                targets: BTreeSet::from([Rule::Library(mock_target_attributes())]),
                disable_pipelining: true,
                ..CrateContext::default()
            },
        );

        let renderer = Renderer::new(
            mock_render_config(None),
            mock_supported_platform_triples(),
            true,
        );
        let output = renderer.render(&context).unwrap();

        let build_file_content = output
            .get(&PathBuf::from("BUILD.mock_crate-0.1.0.bazel"))
            .unwrap();

        assert!(build_file_content.contains("disable_pipelining = True"));
    }

    #[test]
    fn render_cargo_build_script() {
        let mut context = Context::default();
        let crate_id = CrateId::new("mock_crate".to_owned(), "0.1.0".to_owned());
        context.crates.insert(
            crate_id.clone(),
            CrateContext {
                name: crate_id.name,
                version: crate_id.version,
                targets: BTreeSet::from([Rule::BuildScript(TargetAttributes {
                    crate_name: "build_script_build".to_owned(),
                    crate_root: Some("build.rs".to_owned()),
                    ..TargetAttributes::default()
                })]),
                // Build script attributes are required.
                build_script_attrs: Some(BuildScriptAttributes::default()),
                ..CrateContext::default()
            },
        );

        let renderer = Renderer::new(
            mock_render_config(None),
            mock_supported_platform_triples(),
            true,
        );
        let output = renderer.render(&context).unwrap();

        let build_file_content = output
            .get(&PathBuf::from("BUILD.mock_crate-0.1.0.bazel"))
            .unwrap();

        assert!(build_file_content.contains("cargo_build_script("));
        assert!(build_file_content.contains("name = \"build_script_build\""));
        assert!(build_file_content.contains("\"crate-name=mock_crate\""));

        // Ensure `cargo_build_script` requirements are met
        assert!(build_file_content.contains("name = \"mock_crate_build_script\""));
    }

    #[test]
    fn render_proc_macro() {
        let mut context = Context::default();
        let crate_id = CrateId::new("mock_crate".to_owned(), "0.1.0".to_owned());
        context.crates.insert(
            crate_id.clone(),
            CrateContext {
                name: crate_id.name,
                version: crate_id.version,
                targets: BTreeSet::from([Rule::ProcMacro(mock_target_attributes())]),
                ..CrateContext::default()
            },
        );

        let renderer = Renderer::new(
            mock_render_config(None),
            mock_supported_platform_triples(),
            true,
        );
        let output = renderer.render(&context).unwrap();

        let build_file_content = output
            .get(&PathBuf::from("BUILD.mock_crate-0.1.0.bazel"))
            .unwrap();

        assert!(build_file_content.contains("rust_proc_macro("));
        assert!(build_file_content.contains("name = \"mock_crate\""));
        assert!(build_file_content.contains("\"crate-name=mock_crate\""));
    }

    #[test]
    fn render_binary() {
        let mut context = Context::default();
        let crate_id = CrateId::new("mock_crate".to_owned(), "0.1.0".to_owned());
        context.crates.insert(
            crate_id.clone(),
            CrateContext {
                name: crate_id.name,
                version: crate_id.version,
                targets: BTreeSet::from([Rule::Binary(mock_target_attributes())]),
                ..CrateContext::default()
            },
        );

        let renderer = Renderer::new(
            mock_render_config(None),
            mock_supported_platform_triples(),
            true,
        );
        let output = renderer.render(&context).unwrap();

        let build_file_content = output
            .get(&PathBuf::from("BUILD.mock_crate-0.1.0.bazel"))
            .unwrap();

        assert!(build_file_content.contains("rust_binary("));
        assert!(build_file_content.contains("name = \"mock_crate__bin\""));
        assert!(build_file_content.contains("\"crate-name=mock_crate\""));
    }

    #[test]
    fn render_additive_build_contents() {
        let mut context = Context::default();
        let crate_id = CrateId::new("mock_crate".to_owned(), "0.1.0".to_owned());
        context.crates.insert(
            crate_id.clone(),
            CrateContext {
                name: crate_id.name,
                version: crate_id.version,
                targets: BTreeSet::from([Rule::Binary(mock_target_attributes())]),
                additive_build_file_content: Some(
                    "# Hello World from additive section!".to_owned(),
                ),
                ..CrateContext::default()
            },
        );

        let renderer = Renderer::new(
            mock_render_config(None),
            mock_supported_platform_triples(),
            true,
        );
        let output = renderer.render(&context).unwrap();

        let build_file_content = output
            .get(&PathBuf::from("BUILD.mock_crate-0.1.0.bazel"))
            .unwrap();

        assert!(build_file_content.contains("# Hello World from additive section!"));
    }

    #[test]
    fn render_aliases() {
        let config = Config {
            generate_binaries: true,
            ..Config::default()
        };
        let annotations =
            Annotations::new(test::metadata::alias(), test::lockfile::alias(), config).unwrap();
        let context = Context::new(annotations).unwrap();

        let renderer = Renderer::new(
            mock_render_config(None),
            mock_supported_platform_triples(),
            true,
        );
        let output = renderer.render(&context).unwrap();

        let build_file_content = output.get(&PathBuf::from("BUILD.bazel")).unwrap();

        assert!(build_file_content.contains(r#"name = "names-0.12.1-dev__names","#));
        assert!(build_file_content.contains(r#"name = "names-0.13.0__names","#));
    }

    #[test]
    fn render_crate_repositories() {
        let mut context = Context::default();
        let crate_id = CrateId::new("mock_crate".to_owned(), "0.1.0".to_owned());
        context.crates.insert(
            crate_id.clone(),
            CrateContext {
                name: crate_id.name,
                version: crate_id.version,
                targets: BTreeSet::from([Rule::Library(mock_target_attributes())]),
                ..CrateContext::default()
            },
        );

        let renderer = Renderer::new(
            mock_render_config(None),
            mock_supported_platform_triples(),
            true,
        );
        let output = renderer.render(&context).unwrap();

        let defs_module = output.get(&PathBuf::from("defs.bzl")).unwrap();

        assert!(defs_module.contains("def crate_repositories():"));
    }

    #[test]
    fn remote_remote_vendor_mode() {
        let mut context = Context::default();
        let crate_id = CrateId::new("mock_crate".to_owned(), "0.1.0".to_owned());
        context.crates.insert(
            crate_id.clone(),
            CrateContext {
                name: crate_id.name,
                version: crate_id.version,
                targets: BTreeSet::from([Rule::Library(mock_target_attributes())]),
                ..CrateContext::default()
            },
        );

        // Enable remote vendor mode
        let renderer = Renderer::new(
            mock_render_config(Some(VendorMode::Remote)),
            mock_supported_platform_triples(),
            true,
        );
        let output = renderer.render(&context).unwrap();

        let defs_module = output.get(&PathBuf::from("defs.bzl")).unwrap();
        assert!(defs_module.contains("def crate_repositories():"));

        let crates_module = output.get(&PathBuf::from("crates.bzl")).unwrap();
        assert!(crates_module.contains("def crate_repositories():"));
    }

    #[test]
    fn remote_local_vendor_mode() {
        let mut context = Context::default();
        let crate_id = CrateId::new("mock_crate".to_owned(), "0.1.0".to_owned());
        context.crates.insert(
            crate_id.clone(),
            CrateContext {
                name: crate_id.name,
                version: crate_id.version,
                targets: BTreeSet::from([Rule::Library(mock_target_attributes())]),
                ..CrateContext::default()
            },
        );

        // Enable local vendor mode
        let renderer = Renderer::new(
            mock_render_config(Some(VendorMode::Local)),
            mock_supported_platform_triples(),
            true,
        );
        let output = renderer.render(&context).unwrap();

        // Local vendoring does not produce a `crate_repositories` macro
        let defs_module = output.get(&PathBuf::from("defs.bzl")).unwrap();
        assert!(!defs_module.contains("def crate_repositories():"));

        // Local vendoring does not produce a `crates.bzl` file.
        assert!(output.get(&PathBuf::from("crates.bzl")).is_none());
    }

    #[test]
    fn duplicate_rustc_flags() {
        let mut context = Context::default();
        let crate_id = CrateId::new("mock_crate".to_owned(), "0.1.0".to_owned());

        let rustc_flags = vec![
            "-l".to_owned(),
            "dylib=ssl".to_owned(),
            "-l".to_owned(),
            "dylib=crypto".to_owned(),
        ];

        context.crates.insert(
            crate_id.clone(),
            CrateContext {
                name: crate_id.name,
                version: crate_id.version,
                targets: BTreeSet::from([Rule::Library(mock_target_attributes())]),
                common_attrs: CommonAttributes {
                    rustc_flags: rustc_flags.clone(),
                    ..CommonAttributes::default()
                },
                ..CrateContext::default()
            },
        );

        // Enable local vendor mode
        let renderer = Renderer::new(
            mock_render_config(Some(VendorMode::Local)),
            mock_supported_platform_triples(),
            true,
        );
        let output = renderer.render(&context).unwrap();

        let build_file_content = output
            .get(&PathBuf::from("BUILD.mock_crate-0.1.0.bazel"))
            .unwrap();

        // Strip all spaces from the generated BUILD file and ensure it has the flags
        // represented by `rustc_flags` in the same order.
        assert!(build_file_content.replace(' ', "").contains(
            &rustc_flags
                .iter()
                .map(|s| format!("\"{s}\","))
                .collect::<Vec<String>>()
                .join("\n")
        ));
    }

    #[test]
    fn test_render_build_file_deps() {
        let config: Config = serde_json::from_value(serde_json::json!({
            "generate_binaries": false,
            "generate_build_scripts": false,
            "rendering": {
                "repository_name": "multi_cfg_dep",
                "regen_command": "bazel test //crate_universe:unit_test",
            },
            "supported_platform_triples": [
                "x86_64-apple-darwin",
                "x86_64-unknown-linux-gnu",
                "aarch64-apple-darwin",
                "aarch64-unknown-linux-gnu",
            ],
        }))
        .unwrap();
        let metadata = test::metadata::multi_cfg_dep();
        let lockfile = test::lockfile::multi_cfg_dep();

        let annotations = Annotations::new(metadata, lockfile, config.clone()).unwrap();
        let context = Context::new(annotations).unwrap();

        let renderer = Renderer::new(config.rendering, config.supported_platform_triples, true);
        let output = renderer.render(&context).unwrap();

        let build_file_content = output
            .get(&PathBuf::from("BUILD.cpufeatures-0.2.7.bazel"))
            .unwrap();

        // This is unfortunately somewhat brittle. Alas. Ultimately we wish to demonstrate that the
        // original cfg(...) strings are preserved in the `deps` list for ease of debugging.
        let expected = indoc! {r#"
            deps = select({
                "@rules_rust//rust/platform:aarch64-apple-darwin": [
                    "@multi_cfg_dep__libc-0.2.117//:libc",  # cfg(all(target_arch = "aarch64", target_vendor = "apple"))
                ],
                "@rules_rust//rust/platform:aarch64-unknown-linux-gnu": [
                    "@multi_cfg_dep__libc-0.2.117//:libc",  # cfg(all(target_arch = "aarch64", target_os = "linux"))
                ],
                "//conditions:default": [],
            }),
        "#};

        assert!(
            build_file_content.contains(&expected.replace('\n', "\n    ")),
            "{}",
            build_file_content,
        );
    }

    #[test]
    fn legacy_crate_features() {
        let mut context = Context::default();
        let crate_id = CrateId::new("mock_crate".to_owned(), "0.1.0".to_owned());
        context.crates.insert(
            crate_id.clone(),
            CrateContext {
                name: crate_id.name,
                version: crate_id.version,
                targets: BTreeSet::from([Rule::Library(mock_target_attributes())]),
                common_attrs: CommonAttributes {
                    crate_features: CrateFeatures::LegacySet(BTreeSet::from([
                        "foo".to_owned(),
                        "bar".to_owned(),
                    ])),
                    ..CommonAttributes::default()
                },
                ..CrateContext::default()
            },
        );

        let renderer = Renderer::new(
            mock_render_config(None),
            mock_supported_platform_triples(),
            true,
        );
        let output = renderer.render(&context).unwrap();

        let build_file_content = output
            .get(&PathBuf::from("BUILD.mock_crate-0.1.0.bazel"))
            .unwrap();
        assert!(build_file_content.replace(' ', "").contains(
            &r#"crate_features = [
    "bar",
    "foo",
],"#
            .replace(' ', "")
        ));
    }
    #[test]
    fn crate_features_by_target() {
        let mut context = Context::default();
        let crate_id = CrateId::new("mock_crate".to_owned(), "0.1.0".to_owned());
        let mut features = SelectList::default();
        features.insert("foo".to_owned(), Some("aarch64-apple-darwin".to_owned()));
        features.insert("bar".to_owned(), None);
        context.crates.insert(
            crate_id.clone(),
            CrateContext {
                name: crate_id.name,
                version: crate_id.version,
                targets: BTreeSet::from([Rule::Library(mock_target_attributes())]),
                common_attrs: CommonAttributes {
                    crate_features: CrateFeatures::SelectList(features),
                    ..CommonAttributes::default()
                },
                ..CrateContext::default()
            },
        );

        let renderer = Renderer::new(
            mock_render_config(None),
            mock_supported_platform_triples(),
            true,
        );
        let output = renderer.render(&context).unwrap();

        let build_file_content = output
            .get(&PathBuf::from("BUILD.mock_crate-0.1.0.bazel"))
            .unwrap();
        assert!(build_file_content.replace(' ', "").contains(
            &r#"crate_features = [
        "bar",
    ] + select({
    "@rules_rust//rust/platform:aarch64-apple-darwin": [
        "foo",
    ],
    "//conditions:default": [],
}),"#
                .replace(' ', "")
        ));
    }
}
