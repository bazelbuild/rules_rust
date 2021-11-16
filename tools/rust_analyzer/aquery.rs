use std::collections::{BTreeMap, HashMap};
use std::fs::File;
use std::option::Option;
use std::path::Path;
use std::path::PathBuf;
use std::process::Command;

use serde::Deserialize;

#[derive(Debug, Deserialize)]
struct Output {
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

#[derive(Clone, Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct CrateSpec {
    pub crate_id: String,
    pub display_name: String,
    pub edition: String,
    pub root_module: String,
    pub is_workspace_member: bool,
    pub deps: Vec<String>,
    pub proc_macro_dylib_path: Option<String>,
    pub source: Option<CrateSpecSource>,
    pub cfg: Vec<String>,
    pub env: HashMap<String, String>,
    pub target: String,
}

#[derive(Clone, Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct CrateSpecSource {
    pub exclude_dirs: Vec<String>,
    pub include_dirs: Vec<String>,
}

pub fn get_crate_specs(
    bazel: &Path,
    workspace: &Path,
    execution_root: &Path,
    targets: &[&str],
    rules_rust_name: &str,
) -> anyhow::Result<Vec<CrateSpec>> {
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

    // Read all crate specs, deduplicating crates with the same ID. This happens when
    // a rust_test depends on a rust_library, for example.
    let mut crate_specs: BTreeMap<String, CrateSpec> = BTreeMap::new();
    for file in crate_spec_files {
        let spec: CrateSpec = serde_json::from_reader(File::open(file)?)?;
        log::debug!("{:?}", spec);
        if let Some(existing) = crate_specs.get_mut(&spec.crate_id) {
            existing.deps.extend(spec.deps);
            existing.deps.sort();
            existing.deps.dedup();
        } else {
            crate_specs.insert(spec.crate_id.clone(), spec);
        }
    }

    Ok(crate_specs.into_values().collect())
}

fn parse_aquery_output_files(
    execution_root: &Path,
    aquery_stdout: &str,
) -> anyhow::Result<Vec<PathBuf>> {
    let out: Output = serde_json::from_str(aquery_stdout)?;

    let artifacts = out
        .artifacts
        .iter()
        .map(|a| (a.id, a))
        .collect::<HashMap<_, _>>();
    let path_fragments = out
        .path_fragments
        .iter()
        .map(|pf| (pf.id, pf))
        .collect::<HashMap<_, _>>();

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
    fragments: &HashMap<u32, &PathFragment>,
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
