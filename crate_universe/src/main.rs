use std::path::{Path, PathBuf};

use anyhow::{anyhow, Context};
use crate_universe_resolver::{config::Config, renderer::Renderer};
use indoc::indoc;
use log::*;
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
    #[structopt(long = "repository_dir", parse(from_os_str))]
    repository_dir: PathBuf,
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

    let lockfile = &opt.lockfile;
    if opt.update_lockfile {
        if lockfile.is_none() {
            eprintln!("Not updating lockfile for `crate_universe` repository with name \"{}\" because it has no `lockfile` attribute.", opt.repo_name);
        }
    } else if let Some(lockfile) = lockfile {
        return reuse_lockfile(config, &lockfile, &opt);
    }

    generate_dependencies(config, &opt)
}

fn reuse_lockfile(config: Config, lockfile: &Path, opt: &Opt) -> anyhow::Result<()> {
    trace!("Preprocessing config");
    let repository_name = config.repository_name.clone();

    let mut resolver = config.preprocess()?;

    let renderer = Renderer::new_from_lockfile(lockfile)?;

    // TODO: Add lockfile versioning and check that here

    if !renderer.matches_digest(&resolver.digest()?) {
        return Err(anyhow!(
            indoc! { r#"
            "rules_rust_external: Lockfile at {} is out of date, please either:
            1. Re-run bazel with the environment variable `RULES_RUST_REPIN=true`, to update the lockfile.
            2. Remove the `lockfile` attribute from the `crate_universe` repository rule with name `{}` to use floating dependency versions.
        "# },
            lockfile.display(),
            repository_name,
        ));
    }

    renderer.render(&opt.repository_dir)
}

fn generate_dependencies(config: Config, opt: &Opt) -> anyhow::Result<()> {
    trace!("Preprocessing config");
    let resolver = config.preprocess()?;

    // This will contain the mapping of the workspace member (i.e. toplevel) packages' direct
    // dependencies package names to their package Bazel repository name (e.g. `bzip2 ->
    // bzip2__0_3_3`), allowing the user to easily express dependencies with a `package()` macro
    // without knowing the version in advance.
    trace!("Resolving transitive dependencies");
    let consolidator = resolver.resolve()?;
    trace!("Consolidating overrides");
    let renderer = consolidator.consolidate()?;

    renderer.render(&opt.repository_dir)?;

    let lockfile = &opt.lockfile;

    if opt.update_lockfile {
        if let Some(lockfile) = lockfile.as_ref() {
            renderer
                .render_lockfile(lockfile)
                .context("Failed to update lockfile")?;
        }
    }

    Ok(())
}
