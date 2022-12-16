//! Library for generating rust_project.json files from a `Vec<CrateSpec>`
//! See official documentation of file format at https://rust-analyzer.github.io/manual.html

use std::collections::{BTreeMap, BTreeSet, HashMap};
use std::io::ErrorKind;
use std::path::Path;

use anyhow::anyhow;
use serde::Serialize;

use crate::aquery::CrateSpec;

/// A `rust-project.json` workspace representation. See
/// [rust-analyzer documentation][rd] for a thorough description of this interface.
/// [rd]: https://rust-analyzer.github.io/manual.html#non-cargo-based-projects
#[derive(Debug, Serialize)]
pub struct RustProject {
    /// The path to a Rust sysroot.
    sysroot: Option<String>,

    /// Path to the directory with *source code* of
    /// sysroot crates.
    sysroot_src: Option<String>,

    /// The set of crates comprising the current
    /// project. Must include all transitive
    /// dependencies as well as sysroot crate (libstd,
    /// libcore and such).
    crates: Vec<Crate>,
}

/// A `rust-project.json` crate representation. See
/// [rust-analyzer documentation][rd] for a thorough description of this interface.
/// [rd]: https://rust-analyzer.github.io/manual.html#non-cargo-based-projects
#[derive(Debug, Serialize)]
pub struct Crate {
    /// A name used in the package's project declaration
    #[serde(skip_serializing_if = "Option::is_none")]
    display_name: Option<String>,

    /// Path to the root module of the crate.
    root_module: String,

    /// Edition of the crate.
    edition: String,

    /// Dependencies
    deps: Vec<Dependency>,

    /// Should this crate be treated as a member of current "workspace".
    #[serde(skip_serializing_if = "Option::is_none")]
    is_workspace_member: Option<bool>,

    /// Optionally specify the (super)set of `.rs` files comprising this crate.
    #[serde(skip_serializing_if = "Option::is_none")]
    source: Option<Source>,

    /// The set of cfgs activated for a given crate, like
    /// `["unix", "feature=\"foo\"", "feature=\"bar\""]`.
    cfg: Vec<String>,

    /// Target triple for this Crate.
    #[serde(skip_serializing_if = "Option::is_none")]
    target: Option<String>,

    /// Environment variables, used for the `env!` macro
    #[serde(skip_serializing_if = "Option::is_none")]
    env: Option<BTreeMap<String, String>>,

    /// Whether the crate is a proc-macro crate.
    is_proc_macro: bool,

    /// For proc-macro crates, path to compiled proc-macro (.so file).
    #[serde(skip_serializing_if = "Option::is_none")]
    proc_macro_dylib_path: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct Source {
    include_dirs: Vec<String>,
    exclude_dirs: Vec<String>,
}

#[derive(Debug, Serialize)]
pub struct Dependency {
    /// Index of a crate in the `crates` array.
    #[serde(rename = "crate")]
    crate_index: usize,

    /// The display name of the crate.
    name: String,
}

pub fn generate_rust_project(
    sysroot: &str,
    sysroot_src: &str,
    crates: &BTreeSet<CrateSpec>,
) -> anyhow::Result<RustProject> {
    let mut project = RustProject {
        sysroot: Some(sysroot.into()),
        sysroot_src: Some(sysroot_src.into()),
        crates: Vec::new(),
    };

    let mut unmerged_crates: Vec<&CrateSpec> = crates.iter().collect();
    let mut skipped_crates: Vec<&CrateSpec> = Vec::new();
    let mut merged_crates_index: HashMap<String, usize> = HashMap::new();

    while !unmerged_crates.is_empty() {
        for c in unmerged_crates.iter() {
            if c.deps
                .iter()
                .any(|dep| !merged_crates_index.contains_key(dep))
            {
                log::trace!(
                    "Skipped crate {} because missing deps: {:?}",
                    &c.crate_id,
                    c.deps
                        .iter()
                        .filter(|dep| !merged_crates_index.contains_key(*dep))
                        .cloned()
                        .collect::<Vec<_>>()
                );
                skipped_crates.push(c);
            } else {
                log::trace!("Merging crate {}", &c.crate_id);
                merged_crates_index.insert(c.crate_id.clone(), project.crates.len());
                project.crates.push(Crate {
                    display_name: Some(c.display_name.clone()),
                    root_module: c.root_module.clone(),
                    edition: c.edition.clone(),
                    deps: c
                        .deps
                        .iter()
                        .map(|dep| {
                            let crate_index = *merged_crates_index
                                .get(dep)
                                .expect("failed to find dependency on second lookup");
                            let dep_crate = &project.crates[crate_index];
                            Dependency {
                                crate_index,
                                name: dep_crate
                                    .display_name
                                    .as_ref()
                                    .expect("all crates should have display_name")
                                    .clone(),
                            }
                        })
                        .collect(),
                    is_workspace_member: Some(c.is_workspace_member),
                    source: c.source.as_ref().map(|s| Source {
                        exclude_dirs: s.exclude_dirs.clone(),
                        include_dirs: s.include_dirs.clone(),
                    }),
                    cfg: c.cfg.clone(),
                    target: Some(c.target.clone()),
                    env: Some(c.env.clone()),
                    is_proc_macro: c.proc_macro_dylib_path.is_some(),
                    proc_macro_dylib_path: c.proc_macro_dylib_path.clone(),
                });
            }
        }

        // This should not happen, but if it does exit to prevent infinite loop.
        if unmerged_crates.len() == skipped_crates.len() {
            log::debug!(
                "Did not make progress on {} unmerged crates. Crates: {:?}",
                skipped_crates.len(),
                skipped_crates
            );
            return Err(anyhow!(
                "Failed to make progress on building crate dependency graph"
            ));
        }
        std::mem::swap(&mut unmerged_crates, &mut skipped_crates);
        skipped_crates.clear();
    }

    Ok(project)
}

pub fn write_rust_project(
    rust_project_path: &Path,
    execution_root: &Path,
    output_base: &Path,
    rust_project: &RustProject,
) -> anyhow::Result<()> {
    let execution_root = execution_root
        .to_str()
        .ok_or_else(|| anyhow!("execution_root is not valid UTF-8"))?;

    let output_base = output_base
        .to_str()
        .ok_or_else(|| anyhow!("output_base is not valid UTF-8"))?;

    // Try to remove the existing rust-project.json. It's OK if the file doesn't exist.
    match std::fs::remove_file(rust_project_path) {
        Ok(_) => {}
        Err(err) if err.kind() == ErrorKind::NotFound => {}
        Err(err) => {
            return Err(anyhow!(
                "Unexpected error removing old rust-project.json: {}",
                err
            ))
        }
    }

    // Render the `rust-project.json` file and replace the exec root
    // placeholders with the path to the local exec root.
    let rust_project_content = serde_json::to_string(rust_project)?
        .replace("__EXEC_ROOT__", execution_root)
        .replace("__OUTPUT_BASE__", output_base);

    // Write the new rust-project.json file.
    std::fs::write(rust_project_path, rust_project_content)?;

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    use std::collections::BTreeSet;

    use crate::aquery::CrateSpec;

    /// A simple example with a single crate and no dependencies.
    #[test]
    fn generate_rust_project_single() {
        let project = generate_rust_project(
            "sysroot",
            "sysroot_src",
            &BTreeSet::from([CrateSpec {
                crate_id: "ID-example".into(),
                display_name: "example".into(),
                edition: "2018".into(),
                root_module: "example/lib.rs".into(),
                is_workspace_member: true,
                deps: BTreeSet::new(),
                proc_macro_dylib_path: None,
                source: None,
                cfg: vec!["test".into(), "debug_assertions".into()],
                env: BTreeMap::new(),
                target: "x86_64-unknown-linux-gnu".into(),
                crate_type: "rlib".into(),
            }]),
        )
        .expect("expect success");

        assert_eq!(project.crates.len(), 1);
        let c = &project.crates[0];
        assert_eq!(c.display_name, Some("example".into()));
        assert_eq!(c.root_module, "example/lib.rs");
        assert_eq!(c.deps.len(), 0);
    }

    /// An example with a one crate having two dependencies.
    #[test]
    fn generate_rust_project_with_deps() {
        let project = generate_rust_project(
            "sysroot",
            "sysroot_src",
            &BTreeSet::from([
                CrateSpec {
                    crate_id: "ID-example".into(),
                    display_name: "example".into(),
                    edition: "2018".into(),
                    root_module: "example/lib.rs".into(),
                    is_workspace_member: true,
                    deps: BTreeSet::from(["ID-dep_a".into(), "ID-dep_b".into()]),
                    proc_macro_dylib_path: None,
                    source: None,
                    cfg: vec!["test".into(), "debug_assertions".into()],
                    env: BTreeMap::new(),
                    target: "x86_64-unknown-linux-gnu".into(),
                    crate_type: "rlib".into(),
                },
                CrateSpec {
                    crate_id: "ID-dep_a".into(),
                    display_name: "dep_a".into(),
                    edition: "2018".into(),
                    root_module: "dep_a/lib.rs".into(),
                    is_workspace_member: false,
                    deps: BTreeSet::new(),
                    proc_macro_dylib_path: None,
                    source: None,
                    cfg: vec!["test".into(), "debug_assertions".into()],
                    env: BTreeMap::new(),
                    target: "x86_64-unknown-linux-gnu".into(),
                    crate_type: "rlib".into(),
                },
                CrateSpec {
                    crate_id: "ID-dep_b".into(),
                    display_name: "dep_b".into(),
                    edition: "2018".into(),
                    root_module: "dep_b/lib.rs".into(),
                    is_workspace_member: false,
                    deps: BTreeSet::new(),
                    proc_macro_dylib_path: None,
                    source: None,
                    cfg: vec!["test".into(), "debug_assertions".into()],
                    env: BTreeMap::new(),
                    target: "x86_64-unknown-linux-gnu".into(),
                    crate_type: "rlib".into(),
                },
            ]),
        )
        .expect("expect success");

        assert_eq!(project.crates.len(), 3);
        // Both dep_a and dep_b should be one of the first two crates.
        assert!(
            Some("dep_a".into()) == project.crates[0].display_name
                || Some("dep_a".into()) == project.crates[1].display_name
        );
        assert!(
            Some("dep_b".into()) == project.crates[0].display_name
                || Some("dep_b".into()) == project.crates[1].display_name
        );
        let c = &project.crates[2];
        assert_eq!(c.display_name, Some("example".into()));
    }
}
