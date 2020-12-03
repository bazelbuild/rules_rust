use anyhow::{anyhow, Context};
use log::*;
use crate_universe_resolver::config::Config;
use std::io::{BufRead, BufReader};
use std::path::PathBuf;
use structopt::StructOpt;

// Options which don't affect the contents of the generated should be on this struct.
// These fields are not factored into cache keys.
//
// Anything which affects the contents of the generated output should live on `config::Config`.
#[derive(StructOpt)]
struct Opt {
    #[structopt(long)]
    repo_name: String,
    #[structopt(long = "input_path", parse(from_os_str))]
    input_path: PathBuf,
    #[structopt(long = "output_path", parse(from_os_str))]
    output_path: PathBuf,
    #[structopt(long = "lockfile", parse(from_os_str))]
    lockfile: Option<PathBuf>,
    #[structopt(long = "update-lockfile")]
    update_lockfile: bool,
}

fn main() -> anyhow::Result<()> {
    env_logger::init();

    let opt = Opt::from_args();

    trace!("Parsing config from {:?}", opt.input_path);

    let config: Config = {
        let config_file = std::fs::File::open(&opt.input_path)
            .with_context(|| format!("Failed to open config file at {:?}", opt.input_path))?;
        serde_json::from_reader(config_file)
            .with_context(|| format!("Failed to parse config file {:?}", opt.input_path))?
    };
    let lockfile = opt.lockfile;
    let repo_name = opt.repo_name;
    let output_path = opt.output_path;

    trace!("Preprocessing config");
    let mut resolver = config.preprocess()?;

    if opt.update_lockfile {
        if lockfile.is_none() {
            eprintln!("Not updating lockfile for `crate_universe` repository with name \"{}\" because it has no `lockfile` attribute.", repo_name);
        }
    } else if let Some(lockfile) = lockfile {
        let mut lockfile_format_version_line = String::new();
        let mut lockfile_hash_line = String::new();
        {
            std::fs::File::open(&lockfile)
                .map(BufReader::new)
                .and_then(|mut f| {
                    f.read_line(&mut lockfile_format_version_line)?;
                    f.read_line(&mut lockfile_hash_line)?;
                    Ok(())
                })
                .with_context(|| format!("Failed to read lockfile header from {:?}", lockfile))?;
        }
        if lockfile_format_version_line != "# rules_rust crate_universe file format 1\n" {
            return Err(anyhow!("Unrecognized lockfile format"));
        }
        if let Some(lockfile_hash) = lockfile_hash_line.strip_prefix("# config hash ") {
            if resolver.digest()? == lockfile_hash.trim() {
                std::fs::copy(&lockfile, &output_path).with_context(|| {
                    format!(
                        "Failed to copy lockfile from {:?} to {:?}",
                        lockfile, output_path
                    )
                })?;
                return Ok(());
            } else {
                return Err(anyhow!("rules_rust_external: Lockfile at {} is out of date, please either:\n1. Re-run bazel with the environment variable `RULES_RUST_UPDATE_CRATE_UNIVERSE_LOCKFILE=true`, to update the lockfile\n2. Remove the `lockfile` attribute from the `crate_universe` repository rule with name \"{}\" to use floating dependency versions", lockfile.display(), repo_name));
            }
        } else {
            return Err(anyhow!("Invalid lockfile"));
        }
    }

    // This will contain the mapping of the workspace member (i.e. toplevel) packages' direct
    // dependencies package names to their package Bazel repository name (e.g. `bzip2 ->
    // bzip2__0_3_3`), allowing the user to easily express dependencies with a `package()` macro
    // without knowing the version in advance.
    trace!("Resolving transitive dependencies");
    let consolidator = resolver.resolve()?;
    trace!("Consolidating overrides");
    let renderer = consolidator.consolidate()?;

    trace!("Rendering output to: {:?}", output_path);
    let output_file = std::fs::File::create(&output_path)
        .with_context(|| format!("Could not create output file {:?}", output_path))?;
    renderer
        .render(&output_file)
        .context("Could not render deps")?;

    if opt.update_lockfile {
        if let Some(lockfile) = lockfile.as_ref() {
            std::fs::copy(&output_path, lockfile).with_context(|| {
                format!(
                    "Error updating lockfile at {:?} from {:?}",
                    lockfile, output_path
                )
            })?;
        }
    }

    Ok(())
}
