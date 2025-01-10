use std::process::Command;

use camino::Utf8Path;

/// Trait used for extending [`Command`] when the purpose is to invoke `bazel`
/// while preserving its builder pattern capabilities.
pub trait BazelCommand {
    fn new_bazel_command(
        bazel: &Utf8Path,
        workspace: Option<&Utf8Path>,
        output_base: Option<&Utf8Path>,
    ) -> Self;
}

impl BazelCommand for Command {
    fn new_bazel_command(
        bazel: &Utf8Path,
        workspace: Option<&Utf8Path>,
        output_base: Option<&Utf8Path>,
    ) -> Self {
        let mut cmd = Self::new(bazel);

        cmd
            // Switch to the workspace directory if one was provided.
            .current_dir(workspace.unwrap_or(Utf8Path::new(".")))
            .env_remove("BAZELISK_SKIP_WRAPPER")
            .env_remove("BUILD_WORKING_DIRECTORY")
            .env_remove("BUILD_WORKSPACE_DIRECTORY")
            // Set the output_base if one was provided.
            .args(output_base.map(|s| format!("--output_base={s}")));

        cmd
    }
}
