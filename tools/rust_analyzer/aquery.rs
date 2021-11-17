use std::collections::{BTreeMap, BTreeSet};
use std::fs::File;
use std::option::Option;
use std::path::Path;
use std::path::PathBuf;
use std::process::Command;

use anyhow::Context;
use serde::Deserialize;

#[derive(Debug, Deserialize)]
struct AqueryOutput {
    artifacts: Vec<Artifact>,
    actions: Vec<Action>,
    #[serde(rename = "pathFragments")]
    path_fragments: Vec<PathFragment>,
}

#[derive(Debug, Deserialize)]
struct Artifact {
    id: u32,
    #[serde(rename = "pathFragmentId")]
    path_fragment_id: u32,
}

#[derive(Debug, Deserialize)]
struct PathFragment {
    id: u32,
    label: String,
    #[serde(rename = "parentId")]
    parent_id: Option<u32>,
}

#[derive(Debug, Deserialize)]
struct Action {
    #[serde(rename = "outputIds")]
    output_ids: Vec<u32>,
}

#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct CrateSpec {
    pub crate_id: String,
    pub display_name: String,
    pub edition: String,
    pub root_module: String,
    pub is_workspace_member: bool,
    pub deps: BTreeSet<String>,
    pub proc_macro_dylib_path: Option<String>,
    pub source: Option<CrateSpecSource>,
    pub cfg: Vec<String>,
    pub env: BTreeMap<String, String>,
    pub target: String,
}

#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct CrateSpecSource {
    pub exclude_dirs: Vec<String>,
    pub include_dirs: Vec<String>,
}

pub fn get_crate_specs(
    bazel: &Path,
    workspace: &Path,
    execution_root: &Path,
    targets: &[String],
    rules_rust_name: &str,
) -> anyhow::Result<BTreeSet<CrateSpec>> {
    log::debug!("Get crate specs with targets: {:?}", targets);
    let target_pattern = targets
        .iter()
        .map(|t| format!("deps({})", t))
        .collect::<Vec<_>>()
        .join("+");

    let aquery_output = Command::new(bazel)
        .current_dir(workspace)
        .arg("aquery")
        .arg("--include_aspects")
        .arg(format!(
            "--aspects={}//rust:defs.bzl%rust_analyzer_aspect",
            rules_rust_name
        ))
        .arg("--output_groups=rust_analyzer_crate_spec")
        .arg(format!(
            r#"outputs(".*[.]rust_analyzer_crate_spec",{})"#,
            target_pattern
        ))
        .arg("--output=jsonproto")
        .output()?;

    let crate_spec_files =
        parse_aquery_output_files(execution_root, &String::from_utf8(aquery_output.stdout)?)?;

    let crate_specs = crate_spec_files
        .into_iter()
        .map(|file| {
            let f = File::open(&file)
                .with_context(|| format!("Failed to open file: {}", file.display()))?;
            serde_json::from_reader(f)
                .with_context(|| format!("Failed to deserialize file: {}", file.display()))
        })
        .collect::<anyhow::Result<Vec<CrateSpec>>>()?;

    consolidate_crate_specs(crate_specs)
}

fn parse_aquery_output_files(
    execution_root: &Path,
    aquery_stdout: &str,
) -> anyhow::Result<Vec<PathBuf>> {
    let out: AqueryOutput = serde_json::from_str(aquery_stdout)?;

    let artifacts = out
        .artifacts
        .iter()
        .map(|a| (a.id, a))
        .collect::<BTreeMap<_, _>>();
    let path_fragments = out
        .path_fragments
        .iter()
        .map(|pf| (pf.id, pf))
        .collect::<BTreeMap<_, _>>();

    let mut output_files: Vec<PathBuf> = Vec::new();
    for action in out.actions {
        for output_id in action.output_ids {
            let artifact = artifacts
                .get(&output_id)
                .expect("internal consistency error in bazel output");
            let path = path_from_fragments(artifact.path_fragment_id, &path_fragments)?;
            let path = execution_root.join(path);
            if path.exists() {
                output_files.push(path);
            } else {
                log::warn!("Skipping missing crate_spec file: {:?}", path);
            }
        }
    }

    Ok(output_files)
}

fn path_from_fragments(
    id: u32,
    fragments: &BTreeMap<u32, &PathFragment>,
) -> anyhow::Result<PathBuf> {
    let path_fragment = fragments
        .get(&id)
        .expect("internal consistency error in bazel output");

    let buf = match path_fragment.parent_id {
        Some(parent_id) => path_from_fragments(parent_id, fragments)?
            .join(PathBuf::from(&path_fragment.label.clone())),
        None => PathBuf::from(&path_fragment.label.clone()),
    };

    Ok(buf)
}

/// Read all crate specs, deduplicating crates with the same ID. This happens when
/// a rust_test depends on a rust_library, for example.
fn consolidate_crate_specs(crate_specs: Vec<CrateSpec>) -> anyhow::Result<BTreeSet<CrateSpec>> {
    let mut consolidated_specs: BTreeMap<String, CrateSpec> = BTreeMap::new();
    for spec in crate_specs.into_iter() {
        log::debug!("{:?}", spec);
        if let Some(existing) = consolidated_specs.get_mut(&spec.crate_id) {
            existing.deps.extend(spec.deps);
        } else {
            consolidated_specs.insert(spec.crate_id.clone(), spec);
        }
    }

    Ok(consolidated_specs.into_values().collect())
}

#[cfg(test)]
mod test {
    use super::*;

    #[test]
    fn consolidate_lib_then_test_specs() {
        let crate_specs = vec![
            CrateSpec {
                crate_id: "ID-mylib.rs".into(),
                display_name: "mylib".into(),
                edition: "2018".into(),
                root_module: "mylib.rs".into(),
                is_workspace_member: true,
                deps: BTreeSet::from(["ID-lib_dep.rs".into()]),
                proc_macro_dylib_path: None,
                source: None,
                cfg: vec!["test".into(), "debug_assertions".into()],
                env: BTreeMap::new(),
                target: "x86_64-unknown-linux-gnu".into(),
            },
            CrateSpec {
                crate_id: "ID-extra_test_dep.rs".into(),
                display_name: "extra_test_dep".into(),
                edition: "2018".into(),
                root_module: "extra_test_dep.rs".into(),
                is_workspace_member: true,
                deps: BTreeSet::new(),
                proc_macro_dylib_path: None,
                source: None,
                cfg: vec!["test".into(), "debug_assertions".into()],
                env: BTreeMap::new(),
                target: "x86_64-unknown-linux-gnu".into(),
            },
            CrateSpec {
                crate_id: "ID-lib_dep.rs".into(),
                display_name: "lib_dep".into(),
                edition: "2018".into(),
                root_module: "lib_dep.rs".into(),
                is_workspace_member: true,
                deps: BTreeSet::new(),
                proc_macro_dylib_path: None,
                source: None,
                cfg: vec!["test".into(), "debug_assertions".into()],
                env: BTreeMap::new(),
                target: "x86_64-unknown-linux-gnu".into(),
            },
            CrateSpec {
                crate_id: "ID-mylib.rs".into(),
                display_name: "mylib_test".into(),
                edition: "2018".into(),
                root_module: "mylib.rs".into(),
                is_workspace_member: true,
                deps: BTreeSet::from(["ID-extra_test_dep.rs".into()]),
                proc_macro_dylib_path: None,
                source: None,
                cfg: vec!["test".into(), "debug_assertions".into()],
                env: BTreeMap::new(),
                target: "x86_64-unknown-linux-gnu".into(),
            },
        ];

        assert_eq!(
            consolidate_crate_specs(crate_specs).unwrap(),
            BTreeSet::from([
                CrateSpec {
                    crate_id: "ID-mylib.rs".into(),
                    display_name: "mylib".into(),
                    edition: "2018".into(),
                    root_module: "mylib.rs".into(),
                    is_workspace_member: true,
                    deps: BTreeSet::from(["ID-lib_dep.rs".into(), "ID-extra_test_dep.rs".into()]),
                    proc_macro_dylib_path: None,
                    source: None,
                    cfg: vec!["test".into(), "debug_assertions".into()],
                    env: BTreeMap::new(),
                    target: "x86_64-unknown-linux-gnu".into(),
                },
                CrateSpec {
                    crate_id: "ID-extra_test_dep.rs".into(),
                    display_name: "extra_test_dep".into(),
                    edition: "2018".into(),
                    root_module: "extra_test_dep.rs".into(),
                    is_workspace_member: true,
                    deps: BTreeSet::new(),
                    proc_macro_dylib_path: None,
                    source: None,
                    cfg: vec!["test".into(), "debug_assertions".into()],
                    env: BTreeMap::new(),
                    target: "x86_64-unknown-linux-gnu".into(),
                },
                CrateSpec {
                    crate_id: "ID-lib_dep.rs".into(),
                    display_name: "lib_dep".into(),
                    edition: "2018".into(),
                    root_module: "lib_dep.rs".into(),
                    is_workspace_member: true,
                    deps: BTreeSet::new(),
                    proc_macro_dylib_path: None,
                    source: None,
                    cfg: vec!["test".into(), "debug_assertions".into()],
                    env: BTreeMap::new(),
                    target: "x86_64-unknown-linux-gnu".into(),
                },
            ])
        );
    }

    #[test]
    fn consolidate_test_then_lib_specs() {
        let crate_specs = vec![
            CrateSpec {
                crate_id: "ID-mylib.rs".into(),
                display_name: "mylib_test".into(),
                edition: "2018".into(),
                root_module: "mylib.rs".into(),
                is_workspace_member: true,
                deps: BTreeSet::from(["ID-extra_test_dep.rs".into()]),
                proc_macro_dylib_path: None,
                source: None,
                cfg: vec!["test".into(), "debug_assertions".into()],
                env: BTreeMap::new(),
                target: "x86_64-unknown-linux-gnu".into(),
            },
            CrateSpec {
                crate_id: "ID-mylib.rs".into(),
                display_name: "mylib".into(),
                edition: "2018".into(),
                root_module: "mylib.rs".into(),
                is_workspace_member: true,
                deps: BTreeSet::from(["ID-lib_dep.rs".into()]),
                proc_macro_dylib_path: None,
                source: None,
                cfg: vec!["test".into(), "debug_assertions".into()],
                env: BTreeMap::new(),
                target: "x86_64-unknown-linux-gnu".into(),
            },
            CrateSpec {
                crate_id: "ID-extra_test_dep.rs".into(),
                display_name: "extra_test_dep".into(),
                edition: "2018".into(),
                root_module: "extra_test_dep.rs".into(),
                is_workspace_member: true,
                deps: BTreeSet::new(),
                proc_macro_dylib_path: None,
                source: None,
                cfg: vec!["test".into(), "debug_assertions".into()],
                env: BTreeMap::new(),
                target: "x86_64-unknown-linux-gnu".into(),
            },
            CrateSpec {
                crate_id: "ID-lib_dep.rs".into(),
                display_name: "lib_dep".into(),
                edition: "2018".into(),
                root_module: "lib_dep.rs".into(),
                is_workspace_member: true,
                deps: BTreeSet::new(),
                proc_macro_dylib_path: None,
                source: None,
                cfg: vec!["test".into(), "debug_assertions".into()],
                env: BTreeMap::new(),
                target: "x86_64-unknown-linux-gnu".into(),
            },
        ];

        assert_eq!(
            consolidate_crate_specs(crate_specs).unwrap(),
            BTreeSet::from([
                CrateSpec {
                    crate_id: "ID-mylib.rs".into(),
                    // TODO: It's probably better if the display name matches the library target
                    // after the specs are consolidated.
                    display_name: "mylib_test".into(),
                    edition: "2018".into(),
                    root_module: "mylib.rs".into(),
                    is_workspace_member: true,
                    deps: BTreeSet::from(["ID-lib_dep.rs".into(), "ID-extra_test_dep.rs".into()]),
                    proc_macro_dylib_path: None,
                    source: None,
                    cfg: vec!["test".into(), "debug_assertions".into()],
                    env: BTreeMap::new(),
                    target: "x86_64-unknown-linux-gnu".into(),
                },
                CrateSpec {
                    crate_id: "ID-extra_test_dep.rs".into(),
                    display_name: "extra_test_dep".into(),
                    edition: "2018".into(),
                    root_module: "extra_test_dep.rs".into(),
                    is_workspace_member: true,
                    deps: BTreeSet::new(),
                    proc_macro_dylib_path: None,
                    source: None,
                    cfg: vec!["test".into(), "debug_assertions".into()],
                    env: BTreeMap::new(),
                    target: "x86_64-unknown-linux-gnu".into(),
                },
                CrateSpec {
                    crate_id: "ID-lib_dep.rs".into(),
                    display_name: "lib_dep".into(),
                    edition: "2018".into(),
                    root_module: "lib_dep.rs".into(),
                    is_workspace_member: true,
                    deps: BTreeSet::new(),
                    proc_macro_dylib_path: None,
                    source: None,
                    cfg: vec!["test".into(), "debug_assertions".into()],
                    env: BTreeMap::new(),
                    target: "x86_64-unknown-linux-gnu".into(),
                },
            ])
        );
    }
}
