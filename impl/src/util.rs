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

use std::{env, fmt, iter::Iterator, path::Path, path::PathBuf, process::Command, str::FromStr};

use anyhow::{anyhow, Result};

use cargo_platform::Cfg;

use cfg_expr::{targets::get_builtin_target_by_triple, Expression, Predicate};
use pathdiff::diff_paths;

pub(crate) const SYSTEM_CARGO_BIN_PATH: &str = "cargo";
pub(crate) const RAZE_LOCKFILE_NAME: &str = "Cargo.raze.lock";

static SUPPORTED_PLATFORM_TRIPLES: &[&str] = &[
  // SUPPORTED_T1_PLATFORM_TRIPLES
  "i686-apple-darwin",
  "i686-pc-windows-msvc",
  "i686-unknown-linux-gnu",
  "x86_64-apple-darwin",
  "x86_64-pc-windows-msvc",
  "x86_64-unknown-linux-gnu",
  // SUPPORTED_T2_PLATFORM_TRIPLES
  "aarch64-apple-darwin",
  "aarch64-apple-ios",
  "aarch64-linux-android",
  "aarch64-unknown-linux-gnu",
  "arm-unknown-linux-gnueabi",
  "i686-linux-android",
  "i686-unknown-freebsd",
  "powerpc-unknown-linux-gnu",
  "s390x-unknown-linux-gnu",
  "wasm32-unknown-unknown",
  "wasm32-wasi",
  "x86_64-apple-ios",
  "x86_64-linux-android",
  "x86_64-unknown-freebsd",
];

/// Determines if the target matches those supported by and defined in rules_rust
///
/// Examples can be seen below:
///
/// | target                                | returns          | reason                                           |
/// | ------------------------------------- | ---------------- | ------------------------------------------------ |
/// | `cfg(not(fuchsia))`                   | `(true, true)`   | `fuchsia` would be considered a 'default' dependency since no supported target maps to it. |
/// | `cfg(unix)`                           | `(true, false)`  | There are supported platforms from the `unix` `target_family` but not all platforms are of the `unix` family. |
/// | `cfg(not(windows))`                   | `(true, false)`  | There are supported platforms in addition to those in the `windows` `target_family` |
/// | `x86_64-apple-darwin`                 | `(true, false)`  | This is a supported target triple but obviously won't match with other triples. |
/// | `unknown-unknown-unknown`             | `(false, false)` | This will not match any triple.                  |
/// | `cfg(foo)`                            | `(false, false)` | `foo` is not a strongly defined cfg value.       |
/// | `cfg(target_os = "redox")`            | `(false, false)` | `redox` is not a supported platform.             |
pub fn is_bazel_supported_platform(target: &str) -> (bool, bool) {
  // Ensure the target is represented as an expression
  let target_exp = match target.starts_with("cfg(") {
    true => target.to_owned(),
    false => format!("cfg(target = \"{}\")", target),
  };

  let expression = match Expression::parse(&target_exp) {
    Ok(exp) => exp,
    // If the target expression cannot be parsed it is not considered a Bazel platform
    Err(_) => {
      return (false, false);
    },
  };

  let mut is_supported = false;
  let mut matches_all = true;

  // Attempt to match the expression
  for target_info in SUPPORTED_PLATFORM_TRIPLES
    .iter()
    .map(|x| get_builtin_target_by_triple(x).unwrap())
  {
    let target_matches = expression.eval(|pred| {
      match pred {
        Predicate::Target(tp) => tp.matches(target_info),
        Predicate::KeyValue {
          key,
          val,
        } => (*key == "target") && (*val == target_info.triple),
        // For now there is no other kind of matching
        _ => false,
      }
    });
    if target_matches {
      is_supported = true;
    } else {
      matches_all = false;
    }
  }

  (is_supported, matches_all)
}

/// Maps a Rust cfg or triple target to Bazel supported triples.
///
/// Note, the Bazel triples must be defined in:
/// https://github.com/bazelbuild/rules_rust/blob/master/rust/platform/platform.bzl
pub fn get_matching_bazel_triples(target: &str) -> Result<Vec<String>> {
  let target_exp = match target.starts_with("cfg(") {
    true => target.to_owned(),
    false => format!("cfg(target = \"{}\")", target),
  };

  let expression = Expression::parse(&target_exp)?;
  let triples: Vec<String> = SUPPORTED_PLATFORM_TRIPLES
    .iter()
    .filter_map(|triple| {
      let target_info = get_builtin_target_by_triple(triple).unwrap();
      match expression.eval(|pred| {
        match pred {
          Predicate::Target(tp) => tp.matches(target_info),
          Predicate::KeyValue {
            key,
            val,
          } => (*key == "target") && (*val == target_info.triple),
          // For now there is no other kind of matching
          _ => false,
        }
      }) {
        true => Some(String::from((*target_info).triple)),
        false => None,
      }
    })
    .collect();

  Ok(triples)
}

/// Produces a list of triples based on a provided whitelist
pub fn filter_bazel_triples(triples: &mut Vec<String>, triples_whitelist: &[String]) {
  // Early-out if the filter list is empty
  if triples_whitelist.is_empty() {
    return;
  }

  // Prune everything that's not found in the whitelist
  triples.retain(|triple| triples_whitelist.iter().any(|i| i == triple));

  triples.sort();
}

/// Returns a list of Bazel targets for use in `select` statements based on a
/// given list of triples.
pub fn generate_bazel_conditions(
  rust_rules_workspace_name: &str,
  triples: &[String],
) -> Result<Vec<String>> {
  // Sanity check ensuring all strings represent real triples
  for triple in triples.iter() {
    if get_builtin_target_by_triple(triple).is_none() {
      return Err(anyhow!("Not a triple: '{}'", triple));
    }
  }

  let mut bazel_triples: Vec<String> = triples
    .iter()
    .map(|triple| format!("@{}//rust/platform:{}", rust_rules_workspace_name, triple))
    .collect();

  bazel_triples.sort();

  Ok(bazel_triples)
}

/// Returns whether or not the given path is a Bazel workspace root
pub fn is_bazel_workspace_root(dir: &Path) -> bool {
  let workspace_files = [dir.join("WORKSPACE.bazel"), dir.join("WORKSPACE")];

  for workspace in workspace_files.iter() {
    if workspace.exists() {
      return true;
    }
  }

  false
}

/// Returns a path to a Bazel workspace root based on the current working
/// directory, otherwise None if not workspace is detected.
pub fn find_bazel_workspace_root(manifest_path: &Path) -> Option<PathBuf> {
  let mut dir = if manifest_path.is_dir() {
    Some(manifest_path)
  } else {
    manifest_path.parent()
  };

  while let Some(current_dir) = dir {
    if is_bazel_workspace_root(current_dir) {
      return Some(PathBuf::from(current_dir));
    }

    dir = match current_dir.parent() {
      Some(parent) => Some(parent),
      None => None,
    };
  }

  None
}

pub struct PlatformDetails {
  target_triple: String,
  attrs: Vec<Cfg>,
}

pub struct LimitedResults<T> {
  pub items: Vec<T>,
  pub count_extras: usize,
}

impl PlatformDetails {
  pub fn new_using_rustc(target_triple: &str) -> Result<Self> {
    let attrs = fetch_attrs(target_triple)?;
    Ok(Self::new(target_triple.to_owned(), attrs))
  }

  pub fn new(target_triple: String, attrs: Vec<Cfg>) -> Self {
    Self {
      target_triple,
      attrs,
    }
  }

  #[allow(dead_code)]
  pub fn target_triple(&self) -> &str {
    &self.target_triple
  }

  pub fn attrs(&self) -> &Vec<Cfg> {
    &self.attrs
  }
}

impl<T> LimitedResults<T> {
  pub fn is_empty(&self) -> bool {
    self.items.is_empty()
  }
}

impl<T: fmt::Debug> fmt::Debug for LimitedResults<T> {
  fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
    if self.count_extras > 0 {
      write!(f, "{:?} and {} others", &self.items, self.count_extras)
    } else {
      write!(f, "{:?}", &self.items)
    }
  }
}

pub fn collect_up_to<T, U: Iterator<Item = T>>(max: usize, iter: U) -> LimitedResults<T> {
  let mut items = Vec::new();
  let mut count_extras = 0;
  for item in iter {
    // Spill extra crates into a counter to avoid overflowing terminal
    if items.len() < max {
      items.push(item);
    } else {
      count_extras += 1;
    }
  }

  LimitedResults {
    items,
    count_extras,
  }
}

pub fn sanitize_ident(ident: &str) -> String {
  slug::slugify(&ident).replace("-", "_")
}

/// Gets the proper system attributes for the provided platform triple using rustc.
fn fetch_attrs(target: &str) -> Result<Vec<Cfg>> {
  let args = vec![format!("--target={}", target), "--print=cfg".to_owned()];

  let output = Command::new("rustc").args(&args).output()?;

  if !output.status.success() {
    panic!(format!(
      "getting target attrs for {} failed with status: '{}' \nstdout: {}\nstderr: {}",
      target,
      output.status,
      String::from_utf8(output.stdout).unwrap_or_else(|_| "[unparseable bytes]".to_owned()),
      String::from_utf8(output.stderr).unwrap_or_else(|_| "[unparseable bytes]".to_owned())
    ))
  }

  let attr_str =
    String::from_utf8(output.stdout).expect("successful run of rustc's output to be utf8");

  Ok(
    attr_str
      .lines()
      .map(Cfg::from_str)
      .map(|cfg| cfg.expect("attrs from rustc should be parsable into Cargo Cfg"))
      .collect(),
  )
}

pub fn get_workspace_member_path(manifest_path: &Path, workspace_root: &Path) -> Option<PathBuf> {
  assert!(manifest_path.ends_with("Cargo.toml"));
  // UNWRAP: A manifest path should always be a path to a 'Cargo.toml' file which should always have a parent directory
  diff_paths(manifest_path.parent().unwrap(), workspace_root)
}

pub fn package_ident(package_name: &str, package_version: &str) -> String {
  format!("{}-{}", package_name, package_version)
}

/// Locates a lockfile for the associated crate. A `Cargo.raze.lock` file in the
/// [RazeSettings::workspace_path](crate::settings::RazeSettings::workspace_path)
/// direcotry will take precidence over a standard `Cargo.lock` file.
pub fn find_lockfile(cargo_workspace_root: &Path, raze_output_dir: &Path) -> Option<PathBuf> {
  // The custom raze lockfile will always take precidence
  let raze_lockfile = raze_output_dir.join(RAZE_LOCKFILE_NAME);
  if raze_lockfile.exists() {
    return Some(raze_lockfile);
  }

  // If there is an existing standard lockfile, use it.
  let cargo_lockfile = cargo_workspace_root.join("Cargo.lock");
  if cargo_lockfile.exists() {
    return Some(cargo_lockfile);
  }

  // No lockfile is available.
  None
}

/// Locates a cargo binary form either an evironment variable or PATH
pub fn cargo_bin_path() -> PathBuf {
  // Get path to the current binary
  let cargo_path =
    PathBuf::from(env::var("CARGO").unwrap_or_else(|_| SYSTEM_CARGO_BIN_PATH.to_string()));

  cargo_path
}

#[cfg(test)]
mod tests {
  use std::fs::File;

  use tempfile::TempDir;

  use super::*;

  #[test]
  fn test_collect_up_to_works_for_zero() {
    let test_items: Vec<u32> = Vec::new();
    let results = collect_up_to(10, test_items.iter());
    assert!(results.is_empty());
  }

  #[test]
  fn test_collect_up_to_works_for_one() {
    let test_items = vec![1];
    let results = collect_up_to(10, test_items.iter());
    assert_eq!(results.items, vec![&1]);
    assert!(!results.is_empty());
  }

  #[test]
  fn test_collect_up_to_works_for_others_and_bounds_correctly() {
    let test_items = vec![1, 2, 3];
    let results = collect_up_to(2, test_items.iter());
    assert_eq!(results.items, vec![&1, &2]);
    assert_eq!(results.count_extras, 1);
    assert!(!results.is_empty());
  }

  #[test]
  fn detecting_workspace_root() {
    let bazel_root = TempDir::new().unwrap();
    let manifest = bazel_root.as_ref().join("Cargo.toml");

    // Starting within the temp directory, we'll find that there are no WORKSPACE.bazel files
    // and thus return None to indicate a Bazel workspace root could not be found.
    assert_eq!(find_bazel_workspace_root(&manifest), None);

    // After creating a WORKSPACE.bazel file in that directory, we expect to find to be
    // returned a path to the temporary directory
    File::create(bazel_root.path().join("WORKSPACE.bazel")).unwrap();
    assert_eq!(
      find_bazel_workspace_root(&manifest)
        .unwrap()
        .canonicalize()
        .unwrap(),
      bazel_root.into_path().canonicalize().unwrap()
    );
  }

  #[test]
  fn detect_bazel_platforms() {
    assert_eq!(
      is_bazel_supported_platform("cfg(not(fuchsia))"),
      (true, true)
    );
    assert_eq!(
      is_bazel_supported_platform("cfg(not(target_os = \"redox\"))"),
      (true, true)
    );
    assert_eq!(is_bazel_supported_platform("cfg(unix)"), (true, false));
    assert_eq!(
      is_bazel_supported_platform("cfg(not(windows))"),
      (true, false)
    );
    assert_eq!(
      is_bazel_supported_platform("cfg(target = \"x86_64-apple-darwin\")"),
      (true, false)
    );
    assert_eq!(
      is_bazel_supported_platform("x86_64-apple-darwin"),
      (true, false)
    );
    assert_eq!(
      is_bazel_supported_platform("unknown-unknown-unknown"),
      (false, false)
    );
    assert_eq!(is_bazel_supported_platform("cfg(foo)"), (false, false));
    assert_eq!(
      is_bazel_supported_platform("cfg(target_os = \"redox\")"),
      (false, false)
    );
  }

  #[test]
  fn all_supported_platform_triples_unwrap() {
    for triple in SUPPORTED_PLATFORM_TRIPLES.iter() {
      get_builtin_target_by_triple(triple).unwrap();
    }
  }

  #[test]
  fn generate_condition_strings() {
    assert_eq!(
      generate_bazel_conditions(
        "rules_rust",
        &vec![
          "aarch64-unknown-linux-gnu".to_string(),
          "aarch64-apple-ios".to_string(),
        ]
      )
      .unwrap(),
      vec![
        "@rules_rust//rust/platform:aarch64-apple-ios",
        "@rules_rust//rust/platform:aarch64-unknown-linux-gnu",
      ]
    );

    assert_eq!(
      generate_bazel_conditions("rules_rust", &vec!["aarch64-unknown-linux-gnu".to_string()])
        .unwrap(),
      vec!["@rules_rust//rust/platform:aarch64-unknown-linux-gnu"]
    );

    assert!(generate_bazel_conditions(
      "rules_rust",
      &vec![
        "aarch64-unknown-linux-gnu".to_string(),
        "unknown-unknown-unknown".to_string(),
      ]
    )
    .is_err());

    assert!(
      generate_bazel_conditions("rules_rust", &vec!["unknown-unknown-unknown".to_string()])
        .is_err()
    );

    assert!(generate_bazel_conditions(
      "rules_rust",
      &vec!["foo".to_string(), "bar".to_string(), "baz".to_string()]
    )
    .is_err());
  }
}
