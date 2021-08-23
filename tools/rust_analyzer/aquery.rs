use log;
use std::fs::File;
use std::option::Option;
use std::collections::HashMap;
use std::path::PathBuf;
use std::process::Command;
use serde::Deserialize;

#[derive(Deserialize)]
struct Output {
    artifacts: Vec<Artifact>,
    actions: Vec<Action>,
    #[serde(rename = "pathFragments")]
    path_fragments: Vec<PathFragment>,
}

#[derive(Deserialize)]
struct Artifact {
    id: u32,
    #[serde(rename = "pathFragmentId")]
    path_fragment_id: u32,
}

#[derive(Deserialize)]
struct PathFragment {
    id: u32,
    label: String,
    #[serde(rename = "parentId")]
    parent_id: Option<u32>,
}

#[derive(Deserialize)]
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

pub fn get_crate_specs(targets: &[&str]) -> anyhow::Result<Vec<CrateSpec>> {
    log::debug!("Get crate specs with targets: {:?}", targets);    
    let target_pattern = targets.into_iter()
        .map(|t| format!("deps({})", t))
        .collect::<Vec<_>>()
        .join("+");

    let aquery_output = Command::new("bazel")
        // .current_dir(config.workspace.as_ref().unwrap())
        .arg("aquery")
        .arg("--include_aspects")
        .arg("--aspects=@rules_rust//rust:defs.bzl%rust_analyzer_aspect")
        .arg("--output_groups=rust_analyzer_crate_spec")
        .arg(format!(r#"outputs(".*[.]rust_analyzer_crate_spec",{})"#, target_pattern))
        .arg("--output=jsonproto")
        .output()?;

    let s = String::from_utf8(aquery_output.stdout)?;
    log::trace!("Output: {}", s);
    let o: Output = serde_json::from_str(&s)?;

    let artifacts = o.artifacts.iter().map(|a| (a.id, a)).collect::<HashMap<_,_>>();
    let path_fragments = o.path_fragments.iter().map(|pf| (pf.id, pf)).collect::<HashMap<_,_>>();

    let mut crate_specs = Vec::new();
    for action in o.actions {
        for output_id in action.output_ids {
            let artifact = artifacts.get(&output_id).expect("internal consistency error in bazel output");
            let path = path_from_fragments(artifact.path_fragment_id, &path_fragments)?;

            log::debug!("Found crate spec file: {:?}", path);
            if path.exists() {
                crate_specs.push(serde_json::from_reader(File::open(path)?)?);
            } else {
                log::warn!("File {} does not exist.", path.to_string_lossy());
            }
        }
    }

    Ok(crate_specs)
}

fn path_from_fragments(id: u32, fragments: &HashMap<u32, &PathFragment>) -> anyhow::Result<PathBuf> {
    let path_fragment = fragments.get(&id).expect("internal consistency error in bazel output");

    let buf = match path_fragment.parent_id {
        Some(parent_id) => {
            path_from_fragments(parent_id, fragments)?.join(PathBuf::from(&path_fragment.label.clone()))
        },
        None => PathBuf::from(&path_fragment.label.clone())
    };

    Ok(buf)
}