//! Tools for rendering and writing BUILD and other Starlark files

mod template_engine;

use std::collections::BTreeMap;
use std::fs;
use std::path::{Path, PathBuf};
use std::str::FromStr;

use anyhow::{bail, Context as AnyhowContext, Result};

use crate::config::RenderConfig;
use crate::context::Context;
use crate::rendering::template_engine::TemplateEngine;
use crate::splicing::default_splicing_package_crate_id;
use crate::utils::starlark::Label;

pub struct Renderer {
    config: RenderConfig,
    engine: TemplateEngine,
}

impl Renderer {
    pub fn new(config: RenderConfig) -> Self {
        let engine = TemplateEngine::new(&config);
        Self { config, engine }
    }

    pub fn render(&self, context: &Context) -> Result<BTreeMap<PathBuf, String>> {
        let mut output = BTreeMap::new();

        output.extend(self.render_build_files(context)?);
        output.extend(self.render_crates_module(context)?);

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

    fn render_crates_module(&self, context: &Context) -> Result<BTreeMap<PathBuf, String>> {
        let module_label = render_module_label(&self.config.crates_module_template, "defs.bzl")
            .context("Failed to resolve string to module file label")?;
        let module_build_label =
            render_module_label(&self.config.crates_module_template, "BUILD.bazel")
                .context("Failed to resolve string to module file label")?;

        let mut map = BTreeMap::new();
        map.insert(
            Renderer::label_to_path(&module_label),
            self.engine.render_module_bzl(context)?,
        );
        map.insert(
            Renderer::label_to_path(&module_build_label),
            self.engine.render_module_build_file(context)?,
        );

        Ok(map)
    }

    fn render_build_files(&self, context: &Context) -> Result<BTreeMap<PathBuf, String>> {
        let default_splicing_package_id = default_splicing_package_crate_id();
        self.engine
            .render_crate_build_files(context)?
            .into_iter()
            // Do not render the default splicing package
            .filter(|(id, _)| *id != &default_splicing_package_id)
            // Do not render local packages
            .filter(|(id, _)| !context.workspace_members.contains_key(id))
            .map(|(id, content)| {
                let ctx = &context.crates[id];
                let label = match render_build_file_template(
                    &self.config.build_file_template,
                    &ctx.name,
                    &ctx.version,
                ) {
                    Ok(label) => label,
                    Err(e) => bail!(e),
                };

                let filename = Renderer::label_to_path(&label);

                Ok((filename, content))
            })
            .collect()
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
}

/// Write a set of [CrateContext][crate::context::CrateContext] to disk.
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
            println!("{}\n", content);
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
pub fn render_platform_constraint_label(template: &str, triple: &str) -> String {
    template.replace("{triple}", triple)
}

fn render_build_file_template(template: &str, name: &str, version: &str) -> Result<Label> {
    Label::from_str(
        &template
            .replace("{name}", name)
            .replace("{version}", version),
    )
}

#[cfg(test)]
mod test {
    use super::*;

    use crate::config::{Config, CrateId, VendorMode};
    use crate::context::crate_context::{CrateContext, Rule};
    use crate::context::{BuildScriptAttributes, CommonAttributes, Context, TargetAttributes};
    use crate::metadata::Annotations;
    use crate::test;

    fn mock_render_config() -> RenderConfig {
        serde_json::from_value(serde_json::json!({
            "repository_name": "test_rendering",
            "regen_command": "cargo_bazel_regen_command",
        }))
        .unwrap()
    }

    fn mock_target_attributes() -> TargetAttributes {
        TargetAttributes {
            crate_name: "mock_crate".to_owned(),
            crate_root: Some("src/root.rs".to_owned()),
            ..TargetAttributes::default()
        }
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
                targets: vec![Rule::Library(mock_target_attributes())],
                ..CrateContext::default()
            },
        );

        let renderer = Renderer::new(mock_render_config());
        let output = renderer.render(&context).unwrap();

        let build_file_content = output
            .get(&PathBuf::from("BUILD.mock_crate-0.1.0.bazel"))
            .unwrap();

        assert!(build_file_content.contains("rust_library("));
        assert!(build_file_content.contains("name = \"mock_crate\""));
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
                targets: vec![Rule::BuildScript(TargetAttributes {
                    crate_name: "build_script_build".to_owned(),
                    crate_root: Some("build.rs".to_owned()),
                    ..TargetAttributes::default()
                })],
                // Build script attributes are required.
                build_script_attrs: Some(BuildScriptAttributes::default()),
                ..CrateContext::default()
            },
        );

        let renderer = Renderer::new(mock_render_config());
        let output = renderer.render(&context).unwrap();

        let build_file_content = output
            .get(&PathBuf::from("BUILD.mock_crate-0.1.0.bazel"))
            .unwrap();

        assert!(build_file_content.contains("cargo_build_script("));
        assert!(build_file_content.contains("name = \"build_script_build\""));

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
                targets: vec![Rule::ProcMacro(mock_target_attributes())],
                ..CrateContext::default()
            },
        );

        let renderer = Renderer::new(mock_render_config());
        let output = renderer.render(&context).unwrap();

        let build_file_content = output
            .get(&PathBuf::from("BUILD.mock_crate-0.1.0.bazel"))
            .unwrap();

        assert!(build_file_content.contains("rust_proc_macro("));
        assert!(build_file_content.contains("name = \"mock_crate\""));
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
                targets: vec![Rule::Binary(mock_target_attributes())],
                ..CrateContext::default()
            },
        );

        let renderer = Renderer::new(mock_render_config());
        let output = renderer.render(&context).unwrap();

        let build_file_content = output
            .get(&PathBuf::from("BUILD.mock_crate-0.1.0.bazel"))
            .unwrap();

        assert!(build_file_content.contains("rust_binary("));
        assert!(build_file_content.contains("name = \"mock_crate__bin\""));
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
                targets: vec![Rule::Binary(mock_target_attributes())],
                additive_build_file_content: Some(
                    "# Hello World from additive section!".to_owned(),
                ),
                ..CrateContext::default()
            },
        );

        let renderer = Renderer::new(mock_render_config());
        let output = renderer.render(&context).unwrap();

        let build_file_content = output
            .get(&PathBuf::from("BUILD.mock_crate-0.1.0.bazel"))
            .unwrap();

        assert!(build_file_content.contains("# Hello World from additive section!"));
    }

    #[test]
    fn render_aliases() {
        let annotations = Annotations::new(
            test::metadata::alias(),
            test::lockfile::alias(),
            Config::default(),
        )
        .unwrap();
        let context = Context::new(annotations).unwrap();

        let renderer = Renderer::new(mock_render_config());
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
                targets: vec![Rule::Library(mock_target_attributes())],
                ..CrateContext::default()
            },
        );

        let renderer = Renderer::new(mock_render_config());
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
                targets: vec![Rule::Library(mock_target_attributes())],
                ..CrateContext::default()
            },
        );

        // Enable remote vendor mode
        let config = RenderConfig {
            vendor_mode: Some(VendorMode::Remote),
            ..mock_render_config()
        };

        let renderer = Renderer::new(config);
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
                targets: vec![Rule::Library(mock_target_attributes())],
                ..CrateContext::default()
            },
        );

        // Enable local vendor mode
        let config = RenderConfig {
            vendor_mode: Some(VendorMode::Local),
            ..mock_render_config()
        };

        let renderer = Renderer::new(config);
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
                targets: vec![Rule::Library(mock_target_attributes())],
                common_attrs: CommonAttributes {
                    rustc_flags: rustc_flags.clone(),
                    ..CommonAttributes::default()
                },
                ..CrateContext::default()
            },
        );

        // Enable local vendor mode
        let config = RenderConfig {
            vendor_mode: Some(VendorMode::Local),
            ..mock_render_config()
        };

        let renderer = Renderer::new(config);
        let output = renderer.render(&context).unwrap();

        let build_file_content = output
            .get(&PathBuf::from("BUILD.mock_crate-0.1.0.bazel"))
            .unwrap();

        // Strip all spaces from the generated BUILD file and ensure it has the flags
        // represented by `rustc_flags` in the same order.
        assert!(build_file_content.replace(' ', "").contains(
            &rustc_flags
                .iter()
                .map(|s| format!("\"{}\",", s))
                .collect::<Vec<String>>()
                .join("\n")
        ));
    }
}
