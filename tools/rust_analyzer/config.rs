use std::process::Command;

use anyhow::bail;
use camino::{Utf8Path, Utf8PathBuf};
use clap::{Args, Parser};

#[derive(Debug)]
pub struct Config<T>
where
    T: Args,
{
    /// The path to the Bazel workspace directory. If not specified, uses the result of `bazel info workspace`.
    pub workspace: Utf8PathBuf,

    /// The path to the Bazel execution root. If not specified, uses the result of `bazel info execution_root`.
    pub execution_root: Utf8PathBuf,

    /// The path to the Bazel output user root. If not specified, uses the result of `bazel info output_base`.
    pub output_base: Utf8PathBuf,

    /// The path to a Bazel binary
    pub bazel: Utf8PathBuf,

    /// A `--config` directive that gets passed to Bazel to be able to pass custom configurations.
    pub config_group: Option<String>,

    /// Binary specific config options
    pub specific: T,
}

impl<T> Config<T>
where
    T: Args,
{
    // Parse the configuration flags and supplement with bazel info as needed.
    pub fn parse_and_refine() -> anyhow::Result<Self> {
        let ConfigParser {
            mut workspace,
            mut execution_root,
            mut output_base,
            bazel,
            config_group,
            specific,
        } = ConfigParser::parse();

        if workspace.is_some() && execution_root.is_some() && output_base.is_some() {
            return Ok(Config {
                workspace: workspace.unwrap(),
                execution_root: execution_root.unwrap(),
                output_base: output_base.unwrap(),
                bazel,
                config_group,
                specific,
            });
        }

        // We need some info from `bazel info`. Fetch it now.
        let mut bazel_info_command = Command::new(&bazel);

        // Execute bazel info.
        let output = bazel_info_command
            // Switch to the workspace directory if one was provided.
            .current_dir(workspace.as_deref().unwrap_or(Utf8Path::new(".")))
            .env_remove("BAZELISK_SKIP_WRAPPER")
            .env_remove("BUILD_WORKING_DIRECTORY")
            .env_remove("BUILD_WORKSPACE_DIRECTORY")
            // Set the output_base if one was provided.
            .args(output_base.as_ref().map(|s| format!("--output_base={s}")))
            .arg("info")
            .args(config_group.as_ref().map(|s| format!("--config={s}")))
            .output()?;

        if !output.status.success() {
            let status = output.status;
            let stderr = String::from_utf8_lossy(&output.stderr);
            bail!("Failed to run `bazel info` ({status:?}): {stderr}");
        }

        // Extract the output.
        let output = String::from_utf8(output.stdout)?;

        let iter = output
            .trim()
            .split('\n')
            .filter_map(|line| line.split_once(':'))
            .map(|(k, v)| (k, v.trim()));

        for (k, v) in iter {
            match k {
                "workspace" => workspace = Some(v.into()),
                "execution_root" => execution_root = Some(v.into()),
                "output_base" => output_base = Some(v.into()),
                _ => continue,
            }
        }

        let config = Config {
            workspace: workspace.expect("'workspace' must exist in bazel info"),
            execution_root: execution_root.expect("'execution_root' must exist in bazel info"),
            output_base: output_base.expect("'output_base' must exist in bazel info"),
            bazel,
            config_group,
            specific,
        };

        Ok(config)
    }
}

#[derive(Debug, Parser)]
struct ConfigParser<T>
where
    T: Args,
{
    /// The path to the Bazel workspace directory. If not specified, uses the result of `bazel info workspace`.
    #[clap(long, env = "BUILD_WORKSPACE_DIRECTORY")]
    workspace: Option<Utf8PathBuf>,

    /// The path to the Bazel execution root. If not specified, uses the result of `bazel info execution_root`.
    #[clap(long)]
    execution_root: Option<Utf8PathBuf>,

    /// The path to the Bazel output user root. If not specified, uses the result of `bazel info output_base`.
    #[clap(long, env = "OUTPUT_BASE")]
    output_base: Option<Utf8PathBuf>,

    /// The path to a Bazel binary
    #[clap(long, default_value = "bazel")]
    bazel: Utf8PathBuf,

    /// A `--config` directive that gets passed to Bazel to be able to pass custom configurations.
    #[clap(long)]
    config_group: Option<String>,

    /// Binary specific config options
    #[command(flatten)]
    specific: T,
}
