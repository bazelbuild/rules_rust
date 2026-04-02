// Copyright 2020 The Bazel Authors. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

use std::fs::File;
use std::io::{BufRead, BufReader, Read};

pub(crate) fn read_file_to_array(path: &str) -> Result<Vec<String>, String> {
    let file = File::open(path).map_err(|e| e.to_string()).map_err(|err| {
        format!(
            "{} reading path: {:?}, current directory: {:?}",
            err,
            path,
            std::env::current_dir()
        )
    })?;

    read_to_array(file)
}

pub(crate) fn read_stamp_status_with_context(
    path: &str,
    label: &str,
) -> Result<Vec<(String, String)>, String> {
    let file = File::open(path).map_err(|e| {
        format!("failed to read {label} '{}': {e}", path)
    })?;
    stamp_status_to_array(file).map_err(|e| format!("failed to read {label} '{}': {e}", path))
}

fn read_to_array(reader: impl Read) -> Result<Vec<String>, String> {
    let reader = BufReader::new(reader);
    let mut ret = vec![];
    let mut escaped_line = String::new();
    for l in reader.lines() {
        let line = l.map_err(|e| e.to_string())?;
        if line.is_empty() {
            continue;
        }
        // Odd trailing backslashes escape the newline; even counts do not.
        let end_backslash_count = line.chars().rev().take_while(|&c| c == '\\').count();
        let escape = end_backslash_count % 2 == 1;
        // Keep escaped newlines and collapse escaped backslashes.
        let l = line.trim_end_matches('\\');
        escaped_line.push_str(l);
        for _ in 0..end_backslash_count / 2 {
            escaped_line.push('\\');
        }
        if escape {
            // Preserve the logical newline for the next physical line.
            escaped_line.push('\n');
        } else {
            ret.push(escaped_line);
            escaped_line = String::new();
        }
    }
    Ok(ret)
}

fn stamp_status_to_array(reader: impl Read) -> Result<Vec<(String, String)>, String> {
    let escaped_lines = read_to_array(reader)?;
    escaped_lines
        .into_iter()
        .map(|l| {
            let (s1, s2) = l
                .split_once(' ')
                .ok_or_else(|| format!("wrong workspace status file format for \"{l}\""))?;
            Ok((s1.to_owned(), s2.to_owned()))
        })
        .collect()
}

/// Consolidates `-Ldependency` contents into one directory on Windows.
///
/// Returns the number of files linked or copied, skipping missing directories
/// and duplicate filenames.
#[cfg(windows)]
pub(crate) fn consolidate_deps_into(
    dependency_dirs: &[impl AsRef<std::path::Path>],
    unified_dir: &std::path::Path,
) -> usize {
    use std::collections::HashSet;

    let mut seen = HashSet::new();
    let mut count = 0usize;
    for dir in dependency_dirs {
        let entries = match std::fs::read_dir(dir.as_ref()) {
            Ok(e) => e,
            Err(e) => {
                eprintln!(
                    "consolidate_deps: skipping {}: {}",
                    dir.as_ref().display(),
                    e
                );
                continue;
            }
        };
        for entry in entries.flatten() {
            let file_type = match entry.file_type() {
                Ok(ft) => ft,
                Err(_) => continue,
            };
            if !(file_type.is_file() || file_type.is_symlink()) {
                continue;
            }
            let file_name = entry.file_name();
            let file_name_lower = file_name.to_string_lossy().to_ascii_lowercase();
            if !seen.insert(file_name_lower) {
                continue;
            }
            let dest = unified_dir.join(&file_name);
            let src = entry.path();
            match std::fs::hard_link(&src, &dest) {
                Ok(_) => {}
                Err(err) if err.kind() == std::io::ErrorKind::AlreadyExists => {}
                Err(e) => {
                    eprintln!(
                        "consolidate_deps: hard_link {} -> {} failed ({}), falling back to copy",
                        src.display(),
                        dest.display(),
                        e
                    );
                    if let Err(copy_err) = std::fs::copy(&src, &dest) {
                        eprintln!(
                            "consolidate_deps: copy {} -> {} also failed: {}",
                            src.display(),
                            dest.display(),
                            copy_err
                        );
                    }
                }
            }
            count += 1;
        }
    }
    count
}

/// Applies `${key}` -> `value` substitutions to `s`.
///
/// On Windows, also normalizes `/` after verbatim-path substitutions.
pub(crate) fn apply_substitutions(s: &mut String, subst: &[(String, String)]) {
    for (k, v) in subst {
        *s = s.replace(&format!("${{{k}}}"), v);
    }
    #[cfg(windows)]
    if s.contains(r"\\?\") {
        *s = s.replace('/', r"\");
    }
}

#[cfg(test)]
#[path = "test/util.rs"]
mod test;
