// Copyright 2018 Google Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

use std::{
  env,
  fs::{self, File},
  io::Write,
  path::{Path, PathBuf},
};

use anyhow::{anyhow, Context, Result};

use cargo_metadata::Metadata;
use docopt::Docopt;

use cargo_raze::{
  checks,
  metadata::{MetadataFetcher, RazeMetadata, RazeMetadataFetcher},
  planning::{BuildPlanner, BuildPlannerImpl, PlannedBuild},
  rendering::FileOutputs,
  rendering::{bazel::BazelRenderer, BuildRenderer, RenderDetails},
  settings::RazeSettings,
  settings::{load_settings, GenMode, SettingsMetadataFetcher},
  util::{find_bazel_workspace_root, find_lockfile, PlatformDetails},
};

use serde::Deserialize;
use url::Url;

#[derive(Debug, Deserialize)]
struct Options {
  flag_verbose: Option<bool>,
  flag_quiet: Option<bool>,
  flag_host: Option<String>,
  flag_color: Option<String>,
  flag_target: Option<String>,
  flag_dryrun: Option<bool>,
  flag_cargo_bin_path: Option<String>,
  flag_output: Option<String>,
  flag_manifest_path: Option<String>,
  flag_generate_lockfile: Option<bool>,
}

const USAGE: &str = r#"
Generate BUILD files for your pre-vendored Cargo dependencies.

Usage:
    cargo-raze (-h | --help)
    cargo-raze (-V | --version)
    cargo-raze [--verbose] [--quiet] [--color=<WHEN>] [--dryrun] [--cargo-bin-path=<PATH>] 
               [--manifest-path=<PATH>] [--output=<PATH>] [--generate-lockfile]

Options:
    -h, --help                          Print this message
    -V, --version                       Print version info and exit
    -v, --verbose                       Use verbose output
    -q, --quiet                         No output printed to stdout
    --color=<WHEN>                      Coloring: auto, always, never
    -d, --dryrun                        Do not emit any files
    --cargo-bin-path=<PATH>             Path to the cargo binary to be used for loading workspace metadata
    --manifest-path=<PATH>              Path to the Cargo.toml file to generate BUILD files for
    --output=<PATH>                     Path to output the generated into.
    --generate-lockfile                 Force a new `Cargo.raze.lock` file to be generated
"#;

fn main() -> Result<()> {
  // Parse options
  let options = parse_options();

  // Load settings
  let (local_metadata, settings) = load_raze_settings(&options)?;

  // Fetch metadata
  let raze_metadata = fetch_raze_metadata(&options, &settings, &local_metadata)?;

  // Do Planning
  let planned_build = do_planning(&settings, &raze_metadata)?;

  // Render BUILD files
  let (render_details, bazel_file_outputs) =
    render_files(&settings, &raze_metadata, &planned_build, &local_metadata)?;

  // Write BUILD files
  write_files(&bazel_file_outputs, &render_details, &settings, &options)?;

  Ok(())
}

fn parse_options() -> Options {
  // When used as a cargo subcommand, the string "raze" will always be
  // passed as the second `argv` entry. We need to remove that to keep
  // the behavior consistent between direct uses and cargo subcommand
  // uses.
  let mut args: Vec<String> = env::args().collect();
  if args.len() > 1 && args[1] == "raze" {
    args.remove(1);
  }

  let options: Options = Docopt::new(USAGE)
    .map(|d| {
      d.version(Some(
        concat!("cargo-raze ", env!("CARGO_PKG_VERSION")).to_string(),
      ))
    })
    .and_then(|d| d.argv(args).parse())
    .and_then(|d| d.deserialize())
    .unwrap_or_else(|e| e.exit());

  options
}

fn load_raze_settings(options: &Options) -> Result<(Metadata, RazeSettings)> {
  let metadata = fetch_local_metadata(options)?;

  // Parse settings with that metadata
  let settings = match load_settings(&metadata) {
    Ok(settings) => settings,
    Err(err) => return Err(anyhow!(err.to_string())),
  };

  if options.flag_verbose.unwrap_or(false) {
    println!("Loaded override settings: {:#?}", settings);
  }

  Ok((metadata, settings))
}

fn fetch_local_metadata(options: &Options) -> Result<Metadata> {
  // Gather basic, offline metadata to parse settings from
  let fetcher = if let Some(cargo_bin_path) = &options.flag_cargo_bin_path {
    SettingsMetadataFetcher {
      cargo_bin_path: PathBuf::from(cargo_bin_path),
    }
  } else {
    SettingsMetadataFetcher::default()
  };

  let working_directory = if let Some(manifest_path) = &options.flag_manifest_path {
    let manifest_path = PathBuf::from(manifest_path).canonicalize()?;
    if !manifest_path.is_file() {
      return Err(anyhow!(
        "manifest path `{}` is not a file.",
        manifest_path.display()
      ));
    }
    // UNWRAP: Unwrap safe due to check above.
    PathBuf::from(manifest_path.parent().unwrap())
  } else {
    env::current_dir()?
  };

  fetcher
    .fetch_metadata(&working_directory, false)
    .with_context(|| {
      format!(
        "Failed to fetch metadata for {}",
        working_directory.display()
      )
    })
}

fn fetch_raze_metadata(
  options: &Options,
  settings: &RazeSettings,
  local_metadata: &Metadata,
) -> Result<RazeMetadata> {
  let metadata_fetcher: RazeMetadataFetcher = match options.flag_cargo_bin_path {
    Some(ref cargo_bin_path) => RazeMetadataFetcher::new(
      cargo_bin_path,
      Url::parse(&settings.registry)?,
      Url::parse(&settings.index_url)?,
    ),
    None => RazeMetadataFetcher::default(),
  };

  let cargo_raze_working_dir =
    find_bazel_workspace_root(&local_metadata.workspace_root).unwrap_or(env::current_dir()?);

  let binary_dep_info = if settings.genmode == GenMode::Remote {
    Some(&settings.binary_deps)
  } else {
    None
  };

  let reused_lockfile = if !options.flag_generate_lockfile.unwrap_or(false) {
    find_lockfile(
      &local_metadata.workspace_root,
      &cargo_raze_working_dir.join(settings.workspace_path.trim_start_matches('/')),
    )
  } else {
    None
  };

  let raze_metadata = metadata_fetcher.fetch_metadata(
    &local_metadata.workspace_root,
    binary_dep_info,
    reused_lockfile,
  )?;

  checks::check_metadata(&raze_metadata, &settings, &cargo_raze_working_dir)?;
  Ok(raze_metadata)
}

fn do_planning(settings: &RazeSettings, metadata: &RazeMetadata) -> Result<PlannedBuild> {
  let platform_details = match &settings.target {
    Some(target) => Some(PlatformDetails::new_using_rustc(target)?),
    None => None,
  };

  BuildPlannerImpl::new(metadata.clone(), settings.clone()).plan_build(platform_details)
}

fn render_files(
  settings: &RazeSettings,
  metadata: &RazeMetadata,
  planned_build: &PlannedBuild,
  local_metadata: &Metadata,
) -> Result<(RenderDetails, Vec<FileOutputs>)> {
  let cargo_raze_working_dir =
    find_bazel_workspace_root(&local_metadata.workspace_root).unwrap_or(env::current_dir()?);

  let mut bazel_renderer = BazelRenderer::new();
  let render_details = RenderDetails {
    cargo_root: metadata.cargo_workspace_root.clone(),
    path_prefix: PathBuf::from(&settings.workspace_path.trim_start_matches('/')),
    package_aliases_dir: settings.package_aliases_dir.clone(),
    vendored_buildfile_name: settings.output_buildfile_suffix.clone(),
    bazel_root: cargo_raze_working_dir,
    rust_rules_workspace_name: settings.rust_rules_workspace_name.clone(),
    experimental_api: settings.experimental_api,
    render_package_aliases: settings.render_package_aliases,
  };
  let bazel_file_outputs = match &settings.genmode {
    GenMode::Vendored => bazel_renderer.render_planned_build(&render_details, &planned_build)?,
    GenMode::Remote => {
      bazel_renderer.render_remote_planned_build(&render_details, &planned_build)?
    }, /* exhaustive, we control the definition */
    // There are no file outputs to produce if `genmode` is Unspecified
    GenMode::Unspecified => Vec::new(),
  };

  Ok((render_details, bazel_file_outputs))
}

fn write_files(
  bazel_file_outputs: &[FileOutputs],
  render_details: &RenderDetails,
  settings: &RazeSettings,
  options: &Options,
) -> Result<()> {
  if settings.genmode == GenMode::Remote {
    let remote_dir = render_details
      .bazel_root
      .join(&render_details.path_prefix)
      .join("remote");
    // Clean out the "remote" directory so users can easily see what build files are relevant
    if remote_dir.exists() {
      let build_glob = format!("{}/BUILD*.bazel", remote_dir.display());
      for entry in glob::glob(&build_glob)? {
        if let Ok(path) = entry {
          fs::remove_file(path)?;
        }
      }
    }
  }

  for output in bazel_file_outputs.iter() {
    if options.flag_dryrun.unwrap_or(false) {
      println!("{}:\n{}", output.path.display(), output.contents);
      continue;
    }
    // Ensure all parent directories exist
    if let Some(parent) = &output.path.parent() {
      fs::create_dir_all(parent)?
    }
    write_to_file(
      &output.path,
      &output.contents,
      options.flag_verbose.unwrap_or(false),
    )?;
  }

  Ok(())
}

/// Writes rendered files to filesystem.
fn write_to_file(path: &Path, contents: &str, verbose: bool) -> Result<()> {
  File::create(&path).and_then(|mut f| f.write_all(contents.as_bytes()))?;
  if verbose {
    println!("Generated {} successfully", path.display());
  }
  Ok(())
}
