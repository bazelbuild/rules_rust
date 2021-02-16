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

extern crate cargo;
extern crate cargo_raze;
extern crate serde;
#[macro_use]
extern crate serde_derive;
extern crate docopt;
extern crate home;
extern crate serde_json;

use cargo::util::CargoResult;
use cargo::util::Config;
use cargo::CargoError;
use cargo::CliResult;
use docopt::Docopt;
use std::env;
use std::error::Error as StdError;
use std::fmt;
use std::fs::File;
use std::io::Write;
use std::path::PathBuf;
use std::string::ToString;

use cargo_raze::metadata::CargoInternalsMetadataFetcher;
use cargo_raze::metadata::CargoWorkspaceFiles;
use cargo_raze::metadata::MetadataFetcher;

#[derive(Debug)]
struct DumpError(String);

#[derive(Debug, Deserialize)]
struct Options {
  arg_path_to_toml: String,
  flag_noinfer_lock_file: Option<bool>,
  flag_output_file: Option<String>,
  flag_pretty_print: bool,
}

#[derive(Debug)]
struct ValidatedOptions {
  path_to_toml: String,
  infer_lock_file: bool,
  pretty_print: bool,
  output_file_opt: Option<String>,
}

const USAGE: &'static str = r#"
Loads and serializes metadata for a provided Cargo.toml

Usage:
    dump_metadata <path-to-toml> [options]

Options:
    -h, --help                  Print this message
    --noinfer-lock-file         Disable inferring lock file from toml path
    --pretty-print              Whether or not to pretty-print the output
    --output-file=<path>        A filepath to print the generated output to
"#;

impl StdError for DumpError {}
impl fmt::Display for DumpError {
  fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
    write!(f, "dump_metadata failed with cause: \"{}\"", self.0)
  }
}

fn validate_opts(options: &Options) -> Result<ValidatedOptions, String> {
  let mut infer_lock_file = true;
  if options.flag_noinfer_lock_file.is_some() {
    infer_lock_file = !options.flag_noinfer_lock_file.unwrap() // CHECKED above
  }

  Ok(ValidatedOptions {
    path_to_toml: options.arg_path_to_toml.clone(),
    infer_lock_file: infer_lock_file,
    pretty_print: options.flag_pretty_print.clone(),
    output_file_opt: options.flag_output_file.clone(),
  })
}

fn find_workspace_files(options: &ValidatedOptions) -> CargoResult<CargoWorkspaceFiles> {
  let opt_toml_path = PathBuf::from(&options.path_to_toml);

  // Find abs path to toml
  let abs_toml_path = if opt_toml_path.is_absolute() {
    opt_toml_path.canonicalize()?
  } else {
    env::current_dir()
      .map_err(|e| CargoError::from(DumpError(e.to_string())))?
      .join(opt_toml_path)
      .canonicalize()?
  };

  // Verify that toml file exists
  {
    File::open(&abs_toml_path).map_err(|e| {
      CargoError::from(DumpError(format!(
        "opening {:?}: {}",
        abs_toml_path,
        e.to_string()
      )))
    })?;
  }

  // Try to find an associated lock file
  let mut abs_lock_path_opt = None;
  if options.infer_lock_file {
    let expected_abs_lock_path = abs_toml_path
      .parent()
      .unwrap() // CHECKED: Toml must live in a dir
      .join("Cargo.lock");

    if File::open(&abs_toml_path).is_ok() {
      abs_lock_path_opt = Some(expected_abs_lock_path);
    }
  }

  Ok(CargoWorkspaceFiles {
    toml_path: abs_toml_path,
    lock_path_opt: abs_lock_path_opt,
  })
}

fn dump_metadata(options: ValidatedOptions, cargo_config: &mut Config) -> CargoResult<()> {
  let workspace_files = find_workspace_files(&options)?;

  let mut metadata_fetcher = CargoInternalsMetadataFetcher::new(&cargo_config);
  let metadata = metadata_fetcher.fetch_metadata(workspace_files)?;
  let output_text = if options.pretty_print {
    serde_json::to_string_pretty(&metadata)?
  } else {
    serde_json::to_string(&metadata)?
  };

  if options.output_file_opt.is_none() {
    println!("{}", output_text)
  } else {
    let output_file_path = options.output_file_opt.unwrap(); // CHECKED above
    let mut file_out = File::create(&output_file_path)?;
    file_out.write_all(output_text.as_bytes())?;
  }

  Ok(())
}

fn real_main(validated_opts: ValidatedOptions, cargo_config: &mut Config) -> CliResult {
  dump_metadata(validated_opts, cargo_config)?;

  Ok(())
}

fn make_cargo_config(validated_opts: &ValidatedOptions) -> CargoResult<Config> {
  // Sets the config cwd based on the manifest path. This is sort of backwards, but we're emulating
  // how cargo handles "manifest-path".
  //
  // N.B. Config does not expose a constructor that accepts cwd only, and does not allow
  // overwriting cwd later, so we need to emulate `default` but use our own CWD

  let config_cwd = {
    // CHECKED toml file must have dir (even if it's just ".")
    PathBuf::from(&validated_opts.path_to_toml)
      .parent()
      .unwrap()
      .to_path_buf()
  };

  let homedir = home::cargo_home_with_cwd(&config_cwd)?;

  Ok(Config::new(cargo::core::Shell::new(), config_cwd, homedir))
}

fn main() {
  let opts: Options = Docopt::new(USAGE)
    .and_then(|d| d.deserialize())
    .unwrap_or_else(|e| e.exit());
  let validated_opts = validate_opts(&opts).unwrap();

  let mut config = make_cargo_config(&validated_opts).unwrap();

  let result = real_main(validated_opts, &mut config);

  if let Err(e) = result {
    cargo::exit_with_error(e, &mut *config.shell());
  }
}
