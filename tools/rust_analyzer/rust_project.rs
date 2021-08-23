// Library for generating rust_project.json files from a Vec<CrateSpec>
// See official documentation of file format at https://rust-analyzer.github.io/manual.html

use serde::Serialize;
use std::collections::HashMap;
use anyhow::anyhow;
use crate::aquery::CrateSpec;
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
    crate_index: u32,
    name: String,
}

pub fn generate_rust_project(execroot: &Path, crates: &Vec<CrateSpec>) -> anyhow::Result<RustProject> {
    let mut p = RustProject {
        sysroot_src: Some((execroot.to_string_lossy() + "/external/rust_linux_x86_64/lib/rustlib/src/library").to_string()),
        crates: Vec::new(),
    };

    let mut unmerged_crates: Vec<&CrateSpec> = crates.iter().collect();
    let mut skipped_crates: Vec<&CrateSpec> = Vec::new();
    let mut merged_crates_index = HashMap::new();

    while !unmerged_crates.is_empty() {
        let num_unmerged = unmerged_crates.len();
        for c in unmerged_crates.iter() {
            if c.deps.iter().any(|dep| !merged_crates_index.contains_key(dep)) {
                skipped_crates.push(c);
            } else {
                merged_crates_index.insert(c.crate_id.clone(), p.crates.len() as u32);
                p.crates.push(Crate {
                    display_name: Some(c.display_name.clone()),
                    root_module: c.root_module.replace("__EXEC_ROOT__", &execroot.to_string_lossy()),
                    edition: c.edition.clone(),
                    deps: c.deps.iter().map(|dep| Dependency {
                        crate_index: *merged_crates_index.get(dep).expect("failed to find dependency on second lookup"),
                        name: c.display_name.clone(),
                    }).collect(),
                    is_workspace_member: Some(c.is_workspace_member),
                    source: c.source.as_ref().map(|s| Source {
                        exclude_dirs: s.exclude_dirs.iter().map(|d| d.replace("__EXEC_ROOT__", &execroot.to_string_lossy())).collect(),
                        include_dirs: s.include_dirs.iter().map(|d| d.replace("__EXEC_ROOT__", &execroot.to_string_lossy())).collect(),
                    }),
                    cfg: c.cfg.clone(),
                    target: Some(c.target.clone()),
                    env: Some(c.env.clone()),
                    is_proc_macro: c.proc_macro_dylib_path.is_some(),
                    proc_macro_dylib_path: c.proc_macro_dylib_path.clone(),
                });
            }
        }

        if num_unmerged == skipped_crates.len() {
            return Err(anyhow!("Failed to make progress on building crate dependency graph"));
        }
        std::mem::swap(&mut unmerged_crates, &mut skipped_crates);
        skipped_crates.clear();
    }

    Ok(p)
}

pub fn write_rust_project(w: &mut impl std::io::Write, rust_project: &RustProject) {
    serde_json::to_writer(w, rust_project);
}