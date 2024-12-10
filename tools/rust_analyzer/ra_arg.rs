use anyhow::{bail, Context};
use camino::{Utf8Path, Utf8PathBuf};
use serde::{Deserialize, Serialize};
use std::convert::TryInto;
use std::fmt::Display;
use std::process::Command;
use std::str::FromStr;

/// The argument that `rust-analyzer` can pass to the command.
#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub enum RustAnalyzerArg {
    Path(Utf8PathBuf),
    Buildfile(Utf8PathBuf),
}

impl RustAnalyzerArg {
    /// Consumes itself to return a build file and the targets to build.
    pub fn query_target_details(
        self,
        bazel: &Utf8Path,
        output_base: &Utf8Path,
        workspace: &Utf8Path,
        config_group: Option<&str>,
    ) -> anyhow::Result<(Utf8PathBuf, Vec<String>)> {
        match self {
            Self::Path(file) => {
                let buildfile = query_buildfile_for_source_file(
                    bazel,
                    output_base,
                    workspace,
                    config_group,
                    &file,
                )?;
                query_targets(bazel, output_base, workspace, config_group, &buildfile)
                    .map(|t| (buildfile, t))
            }
            Self::Buildfile(buildfile) => {
                query_targets(bazel, output_base, workspace, config_group, &buildfile)
                    .map(|t| (buildfile, t))
            }
        }
    }
}

impl Display for RustAnalyzerArg {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let arg = serde_json::to_string(self).map_err(|_| std::fmt::Error)?;
        write!(f, "{arg}")
    }
}

impl FromStr for RustAnalyzerArg {
    type Err = anyhow::Error;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        serde_json::from_str(s).map_err(|e| anyhow::anyhow!("rust analyzer argument error: {e}"))
    }
}

/// `rust-analyzer` associates workspaces with buildfiles. Therefore, when it passes in a
/// source file path, we use this function to identify the buildfile the file belongs to.
fn query_buildfile_for_source_file(
    bazel: &Utf8Path,
    output_base: &Utf8Path,
    workspace: &Utf8Path,
    config_group: Option<&str>,
    file: &Utf8Path,
) -> anyhow::Result<Utf8PathBuf> {
    log::info!("running bazel query on source file: {file}");

    let stripped_file = file
        .strip_prefix(workspace)
        .with_context(|| format!("{file} not part of workspace"))?;

    let query_output = Command::new(bazel)
        .current_dir(workspace)
        .env_remove("BAZELISK_SKIP_WRAPPER")
        .env_remove("BUILD_WORKING_DIRECTORY")
        .env_remove("BUILD_WORKSPACE_DIRECTORY")
        .arg(format!("--output_base={output_base}"))
        .arg("query")
        .args(config_group.map(|s| format!("--config={s}")))
        .arg("--output=package")
        .arg(stripped_file)
        .output()
        .with_context(|| format!("failed to run bazel query for source file: {stripped_file}"))?;

    log::debug!("{}", String::from_utf8_lossy(&query_output.stderr));
    log::info!("bazel query for source file {file} finished");

    let text = String::from_utf8(query_output.stdout)?;
    let mut lines = text.lines();

    let package = match lines.next() {
        Some(package) if lines.next().is_none() => package,
        // We were passed a Rust source file path.
        // Technically, if the file is used in multiple packages
        // this will error out.
        //
        // I don't think there's any valid reason for such a situation
        // though, so the check here is more for error handling's sake.
        Some(_) => bail!("multiple packages returned for {stripped_file}"),
        None => bail!("no package found for {stripped_file}"),
    };

    for res in std::fs::read_dir(workspace.join(package))? {
        let entry = res?;
        if entry.file_name() == "BUILD.bazel" || entry.file_name() == "BUILD" {
            return entry.path().try_into().map_err(From::from);
        }
    }

    bail!("no buildfile found for {file}");
}

fn query_targets(
    bazel: &Utf8Path,
    output_base: &Utf8Path,
    workspace: &Utf8Path,
    config_group: Option<&str>,
    buildfile: &Utf8Path,
) -> anyhow::Result<Vec<String>> {
    log::info!("running bazel query on buildfile: {buildfile}");

    let parent_dir = buildfile
        .strip_prefix(workspace)
        .with_context(|| format!("{buildfile} not part of workspace"))?
        .parent();

    let targets = match parent_dir {
        Some(p) if !p.as_str().is_empty() => format!("{p}/..."),
        _ => "//...".to_string(),
    };

    let query_output = Command::new(bazel)
        .current_dir(workspace)
        .env_remove("BAZELISK_SKIP_WRAPPER")
        .env_remove("BUILD_WORKING_DIRECTORY")
        .env_remove("BUILD_WORKSPACE_DIRECTORY")
        .arg(format!("--output_base={output_base}"))
        .arg("query")
        .args(config_group.map(|s| format!("--config={s}")))
        .arg(format!(
            "kind(\"rust_(library|binary|proc_macro|test)\", {targets})"
        ))
        .output()
        .with_context(|| format!("failed to run bazel query for buildfile: {buildfile}"))?;

    log::debug!("{}", String::from_utf8_lossy(&query_output.stderr));
    log::info!("bazel query for buildfile {buildfile} finished");

    let text = String::from_utf8(query_output.stdout)?;
    let targets = text.lines().map(ToOwned::to_owned).collect();

    Ok(targets)
}
