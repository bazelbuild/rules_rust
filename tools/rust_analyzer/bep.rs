//! Parse Bazel's Build Event Protocol (BEP) JSON stream to discover the
//! `rust-analyzer` crate spec files produced by `rust_analyzer_aspect`.
//!
//! BEP replaces a separate `bazel aquery` round-trip with a side-effect of
//! the `bazel build` that's already running. The aspect declares its output
//! group; BEP reports each target/aspect completion with the file sets it
//! produced. Walking those is O(events) — much cheaper than rescanning the
//! action graph for the same data.

use std::{
    collections::BTreeMap,
    fs::File,
    io::{BufRead, BufReader},
};

use anyhow::{Context, Result};
use camino::{Utf8Path, Utf8PathBuf};
use serde::Deserialize;

/// Output group name the `rust_analyzer_aspect` puts the per-crate spec files
/// in. Must match the key used in [`OutputGroupInfo`] in
/// `rust/private/rust_analyzer.bzl`.
pub const SPEC_OUTPUT_GROUP: &str = "rust_analyzer_crate_spec";

/// Output group rustc-emitted diagnostics land in when
/// `--@rules_rust//rust/settings:rustc_output_diagnostics=true` is set. See
/// [`generate_output_diagnostics`] in `rust/private/utils.bzl`.
pub const RUSTC_OUTPUT_GROUP: &str = "rustc_output";

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct BuildEvent {
    #[serde(default)]
    id: Option<EventId>,
    #[serde(default)]
    named_set_of_files: Option<NamedSetOfFiles>,
    #[serde(default)]
    completed: Option<Completed>,
    #[serde(default)]
    action: Option<ActionPayload>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct EventId {
    #[serde(default)]
    named_set: Option<NamedSetId>,
    #[serde(default)]
    action_completed: Option<ActionCompletedId>,
}

#[derive(Debug, Deserialize)]
struct ActionCompletedId {}

#[derive(Debug, Deserialize)]
struct ActionPayload {
    #[serde(default)]
    stderr: Option<BepFile>,
}

#[derive(Debug, Deserialize)]
struct NamedSetId {
    id: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct NamedSetOfFiles {
    #[serde(default)]
    files: Vec<BepFile>,
    #[serde(default)]
    file_sets: Vec<FileSetRef>,
}

#[derive(Debug, Deserialize)]
struct BepFile {
    /// Either `uri` or `name`/`pathPrefix` may be populated depending on
    /// Bazel version. We prefer `uri` (a `file://` URL) when available.
    #[serde(default)]
    uri: Option<String>,
    #[serde(default)]
    name: Option<String>,
    #[serde(default, rename = "pathPrefix")]
    path_prefix: Vec<String>,
}

#[derive(Debug, Deserialize)]
struct FileSetRef {
    id: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct Completed {
    #[serde(default)]
    output_group: Vec<OutputGroup>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct OutputGroup {
    name: String,
    #[serde(default)]
    file_sets: Vec<FileSetRef>,
}

/// Read a BEP JSONL file and return every path that appears in the named
/// output group of any completed target or aspect, deduplicated. Paths are
/// absolute on the local filesystem.
pub fn parse_output_group_paths(
    bep_path: &Utf8Path,
    output_group: &str,
    execution_root: &Utf8Path,
) -> Result<Vec<Utf8PathBuf>> {
    let file = File::open(bep_path).with_context(|| format!("opening BEP file {bep_path}"))?;
    let reader = BufReader::new(file);

    // First pass: collect every named file set and every matching fileset id.
    let mut file_sets: BTreeMap<String, NamedSetOfFiles> = BTreeMap::new();
    let mut matching_fileset_ids: Vec<String> = Vec::new();

    for line in reader.lines() {
        let line = line.with_context(|| format!("reading BEP file {bep_path}"))?;
        if line.is_empty() {
            continue;
        }
        // Skip BEP events we don't recognize rather than failing the whole
        // discovery on a forward-compatible field.
        let event: BuildEvent = match serde_json::from_str(&line) {
            Ok(e) => e,
            Err(_) => continue,
        };

        if let Some(named_set) = event.named_set_of_files {
            if let Some(EventId {
                named_set: Some(NamedSetId { id }),
                ..
            }) = event.id
            {
                file_sets.insert(id, named_set);
            }
        } else if let Some(completed) = event.completed {
            for group in completed.output_group {
                if group.name == output_group {
                    for fileset in group.file_sets {
                        matching_fileset_ids.push(fileset.id);
                    }
                }
            }
        }
    }

    // Walk the named file sets transitively, gathering file URIs.
    let mut paths: Vec<Utf8PathBuf> = Vec::new();
    let mut visited: std::collections::BTreeSet<String> = std::collections::BTreeSet::new();
    let mut stack: Vec<String> = matching_fileset_ids;
    while let Some(id) = stack.pop() {
        if !visited.insert(id.clone()) {
            continue;
        }
        let Some(set) = file_sets.get(&id) else {
            continue;
        };
        for file in &set.files {
            if let Some(path) = file_to_path(file) {
                let mut absolute_path = path;
                if !absolute_path.is_absolute() {
                    absolute_path = execution_root.join(absolute_path);
                }

                paths.push(absolute_path);
            }
        }
        for child in &set.file_sets {
            stack.push(child.id.clone());
        }
    }

    paths.sort();
    paths.dedup();
    Ok(paths)
}

/// Convenience wrapper for the `rust_analyzer_crate_spec` output group used
/// during project discovery.
pub fn parse_spec_paths(
    bep_path: &Utf8Path,
    execution_root: &Utf8Path,
) -> Result<Vec<Utf8PathBuf>> {
    parse_output_group_paths(bep_path, SPEC_OUTPUT_GROUP, execution_root)
}

/// Return the stderr file path captured for every completed Bazel action
/// in the BEP, regardless of label. With `error_format=json` set on the
/// build, those files contain rustc's machine-readable diagnostics — the
/// only place to read them when the action fails (failed actions don't
/// produce their declared `.rustc-output` artifacts).
///
/// We deliberately do NOT filter by the saved-file's target label.
/// That matches `cargo check`'s behavior: when a dep of the edited
/// crate fails, cargo surfaces the dep's rustc errors at the dep's
/// file paths, and rust-analyzer renders them there. Filtering by the
/// saved-file's label silently drops every upstream failure, which
/// surfaces in the editor as "no diagnostics anywhere" — the user has
/// no idea why their save produced nothing.
pub fn parse_action_stderr_paths(bep_path: &Utf8Path) -> Result<Vec<Utf8PathBuf>> {
    let file = File::open(bep_path).with_context(|| format!("opening BEP file {bep_path}"))?;
    let reader = BufReader::new(file);

    let mut paths: Vec<Utf8PathBuf> = Vec::new();
    for line in reader.lines() {
        let line = line.with_context(|| format!("reading BEP file {bep_path}"))?;
        if line.is_empty() {
            continue;
        }
        let event: BuildEvent = match serde_json::from_str(&line) {
            Ok(e) => e,
            Err(_) => continue,
        };
        if event
            .id
            .as_ref()
            .and_then(|i| i.action_completed.as_ref())
            .is_none()
        {
            continue;
        }
        let action = match event.action {
            Some(a) => a,
            None => continue,
        };
        if let Some(stderr) = action.stderr {
            if let Some(path) = file_to_path(&stderr) {
                paths.push(path);
            }
        }
    }
    paths.sort();
    paths.dedup();
    Ok(paths)
}

fn file_to_path(file: &BepFile) -> Option<Utf8PathBuf> {
    if let Some(uri) = &file.uri {
        if let Some(rest) = uri.strip_prefix("file://") {
            let decoded = percent_decode(rest);
            return Some(Utf8PathBuf::from(strip_uri_drive_prefix(&decoded)));
        }
    }
    // Fallback: reconstruct from pathPrefix + name. Bazel uses this form
    // when the file lives in bazel-out and the absolute URI isn't reported.
    if let Some(name) = &file.name {
        if !file.path_prefix.is_empty() {
            let mut path = Utf8PathBuf::from(&file.path_prefix[0]);
            for segment in file.path_prefix.iter().skip(1) {
                path.push(segment);
            }
            path.push(name);
            return Some(path);
        }
    }
    None
}

/// `file://` URIs on Windows look like `file:///C:/path` — after stripping
/// the `file://` scheme prefix, the result is `/C:/path` where the leading
/// `/` is the URI authority separator, NOT part of the actual filesystem
/// path. Strip it when the next characters are `<drive-letter>:` so the
/// resulting `C:/path` parses as a valid Windows path.
///
/// Safe on POSIX: a real POSIX file URI `file:///foo/bar` strips to
/// `/foo/bar` which doesn't match the `/<letter>:` shape, so the path
/// passes through unchanged.
fn strip_uri_drive_prefix(s: &str) -> &str {
    let bytes = s.as_bytes();
    if bytes.len() >= 3 && bytes[0] == b'/' && bytes[1].is_ascii_alphabetic() && bytes[2] == b':' {
        &s[1..]
    } else {
        s
    }
}

fn percent_decode(s: &str) -> String {
    let bytes = s.as_bytes();
    let mut out = Vec::with_capacity(bytes.len());
    let mut i = 0;
    while i < bytes.len() {
        if bytes[i] == b'%' && i + 2 < bytes.len() {
            if let (Some(hi), Some(lo)) = (hex_digit(bytes[i + 1]), hex_digit(bytes[i + 2])) {
                out.push(hi * 16 + lo);
                i += 3;
                continue;
            }
        }
        out.push(bytes[i]);
        i += 1;
    }
    // The decoded URI path must be valid UTF-8 on the platforms we support.
    String::from_utf8(out).unwrap_or_else(|e| String::from_utf8_lossy(e.as_bytes()).into_owned())
}

fn hex_digit(b: u8) -> Option<u8> {
    match b {
        b'0'..=b'9' => Some(b - b'0'),
        b'a'..=b'f' => Some(b - b'a' + 10),
        b'A'..=b'F' => Some(b - b'A' + 10),
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn percent_decode_basic() {
        assert_eq!(percent_decode("/path/with%20space"), "/path/with space");
        assert_eq!(percent_decode("noop"), "noop");
        assert_eq!(percent_decode("a%2Fb"), "a/b");
    }

    #[test]
    fn strip_uri_drive_prefix_handles_windows_and_posix() {
        // Windows: `file:///C:/path` → after `file://` strip → `/C:/path`.
        // The leading `/` is the URI authority separator and must go.
        assert_eq!(
            strip_uri_drive_prefix("/C:/path/to/file"),
            "C:/path/to/file"
        );
        assert_eq!(strip_uri_drive_prefix("/D:/other"), "D:/other");
        // POSIX: `file:///foo/bar` → `/foo/bar`. Leading `/` IS the path root.
        assert_eq!(strip_uri_drive_prefix("/foo/bar"), "/foo/bar");
        assert_eq!(
            strip_uri_drive_prefix("/abs/lib.spec.json"),
            "/abs/lib.spec.json"
        );
        // Edge cases.
        assert_eq!(strip_uri_drive_prefix(""), "");
        assert_eq!(strip_uri_drive_prefix("/"), "/");
        assert_eq!(
            strip_uri_drive_prefix("C:/already_clean"),
            "C:/already_clean"
        );
    }

    #[test]
    fn parse_spec_paths_resolves_nested_filesets() {
        let dir = tempdir();
        let bep_path = dir.join("bep.json");
        std::fs::write(
            &bep_path,
            r#"{"id":{"namedSet":{"id":"0"}},"namedSetOfFiles":{"files":[{"uri":"file:///abs/foo.rust_analyzer_crate_spec.json"}],"fileSets":[{"id":"1"}]}}
{"id":{"namedSet":{"id":"1"}},"namedSetOfFiles":{"files":[{"uri":"file:///abs/bar.rust_analyzer_crate_spec.json"}]}}
{"id":{"targetCompleted":{"label":"//pkg:lib"}},"completed":{"outputGroup":[{"name":"rust_analyzer_crate_spec","fileSets":[{"id":"0"}]}]}}
{"id":{"namedSet":{"id":"2"}},"namedSetOfFiles":{"files":[{"uri":"file:///abs/unrelated.json"}]}}
"#,
        )
        .unwrap();
        let paths = parse_spec_paths(&bep_path, Utf8Path::new("/execroot")).unwrap();
        assert_eq!(
            paths,
            vec![
                Utf8PathBuf::from("/abs/bar.rust_analyzer_crate_spec.json"),
                Utf8PathBuf::from("/abs/foo.rust_analyzer_crate_spec.json"),
            ]
        );
    }

    #[test]
    fn parse_spec_paths_handles_relative_paths() {
        let dir = tempdir();
        let bep_path = dir.join("bep.json");
        std::fs::write(
            &bep_path,
            r#"{"id":{"namedSet":{"id":"0"}},"namedSetOfFiles":{"files":[{"uri":"bytestream://remote/blob","pathPrefix":["bazel-out","k8-fastbuild","bin"],"name":"pkg/lib.rust_analyzer_crate_spec.json"}]}}
{"id":{"targetCompleted":{"label":"//pkg:lib"}},"completed":{"outputGroup":[{"name":"rust_analyzer_crate_spec","fileSets":[{"id":"0"}]}]}}
"#,
        )
        .unwrap();
        let paths = parse_spec_paths(&bep_path, Utf8Path::new("/execroot")).unwrap();
        assert_eq!(
            paths,
            vec![Utf8PathBuf::from(
                "/execroot/bazel-out/k8-fastbuild/bin/pkg/lib.rust_analyzer_crate_spec.json",
            )]
        );
    }

    #[test]
    fn parse_output_group_paths_filters_by_group() {
        let dir = tempdir();
        let bep_path = dir.join("bep.json");
        std::fs::write(
            &bep_path,
            r#"{"id":{"namedSet":{"id":"0"}},"namedSetOfFiles":{"files":[{"uri":"file:///abs/lib.rustc-output"}]}}
{"id":{"namedSet":{"id":"1"}},"namedSetOfFiles":{"files":[{"uri":"file:///abs/lib.spec.json"}]}}
{"id":{"targetCompleted":{"label":"//pkg:lib"}},"completed":{"outputGroup":[{"name":"rustc_output","fileSets":[{"id":"0"}]},{"name":"rust_analyzer_crate_spec","fileSets":[{"id":"1"}]}]}}
"#,
        )
        .unwrap();
        let rustc =
            parse_output_group_paths(&bep_path, RUSTC_OUTPUT_GROUP, Utf8Path::new("/execroot"))
                .unwrap();
        assert_eq!(rustc, vec![Utf8PathBuf::from("/abs/lib.rustc-output")]);
        let specs = parse_output_group_paths(
            &bep_path,
            "rust_analyzer_crate_spec",
            Utf8Path::new("/execroot"),
        )
        .unwrap();
        assert_eq!(specs, vec![Utf8PathBuf::from("/abs/lib.spec.json")]);
    }

    fn tempdir() -> Utf8PathBuf {
        use std::convert::TryFrom;
        // Sanitize the thread name: libtest gives us names like
        // `bep::tests::foo`, and Windows rejects `:` in filenames.
        let raw_name = std::thread::current().name().unwrap_or("anon").to_owned();
        let safe_name: String = raw_name
            .chars()
            .map(|c| if c.is_ascii_alphanumeric() { c } else { '_' })
            .collect();
        let dir =
            std::env::temp_dir().join(format!("bep_test_{}_{}", std::process::id(), safe_name,));
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).unwrap();
        Utf8PathBuf::try_from(dir).unwrap()
    }
}
