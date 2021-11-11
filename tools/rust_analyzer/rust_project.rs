// Library for generating rust_project.json files from a Vec<CrateSpec>
// See official documentation of file format at https://rust-analyzer.github.io/manual.html

use crate::aquery::CrateSpec;
use anyhow::anyhow;
use serde::Serialize;
use std::collections::HashMap;
use std::io::ErrorKind;
use std::path::Path;

#[derive(Serialize)]
pub struct RustProject {
    sysroot_src: Option<String>,
    crates: Vec<Crate>,
}

#[derive(Serialize)]
pub struct Crate {
    #[serde(skip_serializing_if = "Option::is_none")]
    display_name: Option<String>,
    root_module: String,
    edition: String,
    deps: Vec<Dependency>,
    #[serde(skip_serializing_if = "Option::is_none")]
    is_workspace_member: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    source: Option<Source>,
    cfg: Vec<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    target: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    env: Option<HashMap<String, String>>,
    is_proc_macro: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    proc_macro_dylib_path: Option<String>,
}

#[derive(Serialize)]
pub struct Source {
    include_dirs: Vec<String>,
    exclude_dirs: Vec<String>,
}

#[derive(Serialize)]
pub struct Dependency {
    /// Index of a crate in the `crates` array.
    #[serde(rename = "crate")]
    crate_index: usize,
    name: String,
}

pub fn generate_rust_project(
    sysroot_src: &str,
    crates: &Vec<CrateSpec>,
) -> anyhow::Result<RustProject> {
    let mut project = RustProject {
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
                            let dep_crate = &project.crates[crate_index as usize];
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
    rust_project: &RustProject,
) -> anyhow::Result<()> {
    let execution_root = execution_root
        .to_str()
        .ok_or(anyhow!("execution_root is not valid UTF-8"))?;

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

    // Write the new rust-project.json file.
    std::fs::write(
        rust_project_path,
        serde_json::to_string(rust_project)?.replace("__EXEC_ROOT__", &execution_root),
    )?;

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::aquery::CrateSpec;

    #[test]
    // A simple example with a single crate and no dependencies.
    fn generate_rust_project_single() {
        let project = generate_rust_project(
            "sysroot",
            &vec![CrateSpec {
                crate_id: "ID-example".into(),
                display_name: "example".into(),
                edition: "2018".into(),
                root_module: "example/lib.rs".into(),
                is_workspace_member: true,
                deps: vec![],
                proc_macro_dylib_path: None,
                source: None,
                cfg: vec!["test".into(), "debug_assertions".into()],
                env: HashMap::new(),
                target: "x86_64-unknown-linux-gnu".into(),
            }],
        )
        .expect("expect success");

        assert_eq!(project.crates.len(), 1);
        let c = &project.crates[0];
        assert_eq!(c.display_name, Some("example".into()));
        assert_eq!(c.root_module, "example/lib.rs");
        assert_eq!(c.deps.len(), 0);
    }

    #[test]
    // An example with a one crate having two dependencies.
    fn generate_rust_project_with_deps() {
        let project = generate_rust_project(
            "sysroot",
            &vec![
                CrateSpec {
                    crate_id: "ID-example".into(),
                    display_name: "example".into(),
                    edition: "2018".into(),
                    root_module: "example/lib.rs".into(),
                    is_workspace_member: true,
                    deps: vec!["ID-dep_a".into(), "ID-dep_b".into()],
                    proc_macro_dylib_path: None,
                    source: None,
                    cfg: vec!["test".into(), "debug_assertions".into()],
                    env: HashMap::new(),
                    target: "x86_64-unknown-linux-gnu".into(),
                },
                CrateSpec {
                    crate_id: "ID-dep_a".into(),
                    display_name: "dep_a".into(),
                    edition: "2018".into(),
                    root_module: "dep_a/lib.rs".into(),
                    is_workspace_member: false,
                    deps: vec![],
                    proc_macro_dylib_path: None,
                    source: None,
                    cfg: vec!["test".into(), "debug_assertions".into()],
                    env: HashMap::new(),
                    target: "x86_64-unknown-linux-gnu".into(),
                },
                CrateSpec {
                    crate_id: "ID-dep_b".into(),
                    display_name: "dep_b".into(),
                    edition: "2018".into(),
                    root_module: "dep_b/lib.rs".into(),
                    is_workspace_member: false,
                    deps: vec![],
                    proc_macro_dylib_path: None,
                    source: None,
                    cfg: vec!["test".into(), "debug_assertions".into()],
                    env: HashMap::new(),
                    target: "x86_64-unknown-linux-gnu".into(),
                },
            ],
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
