//! Content-addressed cache for the assembled `rust-project.json`.
//!
//! Discovery has to read every per-crate spec file regardless, but the
//! consolidate + assemble + serialize step is short-circuited on a cache
//! hit. The key hashes every input — spec contents, toolchain info,
//! bazel/workspace/exec-root paths — so an entry is only served when
//! every input matches byte-for-byte.

use std::{
    collections::hash_map::DefaultHasher,
    fs,
    hash::{Hash, Hasher},
};

use anyhow::{Context, Result};
use camino::{Utf8Path, Utf8PathBuf};

/// Cache subdir name, relative to the launcher dir. `setup --clean`
/// deletes `<launcher_dir>/CACHE_SUBDIR/` — importing the constant
/// keeps that path in sync if we ever rename.
pub const CACHE_SUBDIR: &str = "cache";

/// Where cache entries live, relative to the workspace root, when
/// discover falls back (no `$RULES_RUST_RA_CACHE_DIR` set — see
/// [`cache_dir`]).
///
/// Editor-agnostic by design: the discover binary that produces these
/// entries is invoked the same way regardless of which editor's launcher
/// kicked it off (`.vscode/`, `.helix/`, `.rules_rust_analyzer/` — all
/// dispatch to the same `bazel-bin/.../discover_bazel_rust_project`), so
/// they share one cache.
///
/// Living inside the workspace (not under Bazel's `output_base`) keeps
/// the cache visible to `ls`, easy to clear with `rm -rf`, and immune to
/// `bazel clean`. Making Bazel manage it would require turning it into
/// an action output, which has its own correctness headaches.
const CACHE_DIR_REL_PREFIX: &str = ".rules_rust_analyzer";

/// Schema version mixed into every cache key. Bump on any change to
/// the assembled `rust-project.json` shape — old cache entries become
/// ignored rather than served as stale. The cache key is content-keyed
/// on inputs (not on rules_rust source), so without this bump an
/// unchanged workspace would keep serving JSON assembled by an older
/// version of the assembler. See the explanatory comment on
/// `compute_key` for the incident that motivated this.
const CACHE_SCHEMA_VERSION: u32 = 1;

/// Compute the cache key for an assembled rust-project.json from the raw
/// spec contents plus every auxiliary input the assembler bakes into its
/// output. Anything that changes the bytes of the JSON must factor into the
/// key, otherwise a stale entry could be served after the user moves to a
/// different bazel binary, workspace, or execution root.
///
/// `spec_contents` should already be sorted by spec path so the key is
/// independent of file-system enumeration order.
pub fn compute_key(
    spec_contents: &[(Utf8PathBuf, String)],
    toolchain_info: &str,
    bazel: &Utf8Path,
    workspace: &Utf8Path,
    execution_root: &Utf8Path,
    launcher_dir: &str,
) -> String {
    let mut hasher = DefaultHasher::new();
    CACHE_SCHEMA_VERSION.hash(&mut hasher);
    bazel.as_str().hash(&mut hasher);
    workspace.as_str().hash(&mut hasher);
    execution_root.as_str().hash(&mut hasher);
    toolchain_info.hash(&mut hasher);
    // Hashed because `flycheck_launcher_path` in `rust_project.rs` reads
    // `$RULES_RUST_RA_LAUNCHER_DIR` to bake an absolute path into the
    // assembled JSON. If we left this out, switching editors
    // (vscode→neovim→helix) on the same workspace would silently serve
    // the previously-cached editor's launcher path.
    launcher_dir.hash(&mut hasher);
    for (path, content) in spec_contents {
        path.as_str().hash(&mut hasher);
        content.hash(&mut hasher);
    }
    format!("{:016x}", hasher.finish())
}

/// Env var carrying the editor-specific install dir. Published by
/// `discover_rust_project::self_locate_config` from `current_exe()`'s
/// dirname; consumed by both `compute_key` (cache shard) and
/// `rust_project::flycheck_launcher_path` (path embedded in the
/// assembled JSON). Reading it once at the call site keeps both
/// readers consistent.
pub const LAUNCHER_DIR_ENV_VAR: &str = "RULES_RUST_RA_LAUNCHER_DIR";

/// Env var that overrides the cache directory location. Published by
/// `discover_rust_project::self_locate_config`; can also be set
/// manually for one-off runs.
const CACHE_DIR_ENV_VAR: &str = "RULES_RUST_RA_CACHE_DIR";

/// Resolve the cache directory. `$RULES_RUST_RA_CACHE_DIR` wins if set;
/// otherwise we fall back to `<workspace>/.rules_rust_analyzer/cache`.
///
/// `discover_rust_project::self_locate_config` publishes the env var
/// from `current_exe()`'s dirname (the install dir setup copied us
/// into). This fallback only fires when discover is invoked from
/// somewhere other than an install dir — direct exec for debugging,
/// or the legacy `gen_rust_project` binary which doesn't self-locate.
pub fn cache_dir(workspace: &Utf8Path) -> Utf8PathBuf {
    if let Ok(s) = std::env::var(CACHE_DIR_ENV_VAR) {
        if !s.is_empty() {
            return Utf8PathBuf::from(s);
        }
    }
    workspace.join(CACHE_DIR_REL_PREFIX).join(CACHE_SUBDIR)
}

fn cache_file(workspace: &Utf8Path, key: &str) -> Utf8PathBuf {
    cache_dir(workspace).join(format!("{key}.json"))
}

/// Returns the cached JSON bytes if the key is present. A miss returns
/// `Ok(None)`; only IO errors propagate.
pub fn get(workspace: &Utf8Path, key: &str) -> Result<Option<Vec<u8>>> {
    let path = cache_file(workspace, key);
    match fs::read(&path) {
        Ok(bytes) => {
            log::debug!("rust-analyzer merge cache hit: {path}");
            Ok(Some(bytes))
        }
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(None),
        Err(e) => Err(e).with_context(|| format!("reading cache file {path}")),
    }
}

/// Persist the assembled JSON bytes for the given key. Cache writes are
/// best-effort: a failure is logged but does not fail the caller, since the
/// JSON is also being returned to `rust-analyzer`.
pub fn put(workspace: &Utf8Path, key: &str, bytes: &[u8]) {
    let dir = cache_dir(workspace);
    if let Err(e) = fs::create_dir_all(&dir) {
        log::warn!("rust-analyzer merge cache: create_dir_all {dir} failed: {e}");
        return;
    }
    let path = cache_file(workspace, key);
    // Write to a temp file and rename so concurrent invocations don't observe
    // a half-written cache entry.
    let tmp = path.with_extension("json.tmp");
    if let Err(e) = fs::write(&tmp, bytes) {
        log::warn!("rust-analyzer merge cache: write {tmp} failed: {e}");
        return;
    }
    if let Err(e) = fs::rename(&tmp, &path) {
        log::warn!("rust-analyzer merge cache: rename {tmp} -> {path} failed: {e}");
        let _ = fs::remove_file(&tmp);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn compute_key_is_stable() {
        let bazel = Utf8Path::new("/usr/bin/bazel");
        let ws = Utf8Path::new("/ws");
        let er = Utf8Path::new("/er");
        let toolchain = "{\"sysroot\":\"a\"}";
        let specs = vec![
            (
                Utf8PathBuf::from("a/foo.json"),
                String::from("{\"id\":\"a\"}"),
            ),
            (
                Utf8PathBuf::from("b/bar.json"),
                String::from("{\"id\":\"b\"}"),
            ),
        ];
        let k1 = compute_key(&specs, toolchain, bazel, ws, er, "");
        let k2 = compute_key(&specs, toolchain, bazel, ws, er, "");
        assert_eq!(k1, k2);
    }

    #[test]
    fn compute_key_changes_with_content() {
        let bazel = Utf8Path::new("/usr/bin/bazel");
        let ws = Utf8Path::new("/ws");
        let er = Utf8Path::new("/er");
        let toolchain = "{}";
        let base = vec![(Utf8PathBuf::from("a.json"), "a".to_string())];
        let mutated = vec![(Utf8PathBuf::from("a.json"), "b".to_string())];
        assert_ne!(
            compute_key(&base, toolchain, bazel, ws, er, ""),
            compute_key(&mutated, toolchain, bazel, ws, er, "")
        );
    }

    #[test]
    fn compute_key_changes_with_toolchain() {
        let bazel = Utf8Path::new("/usr/bin/bazel");
        let ws = Utf8Path::new("/ws");
        let er = Utf8Path::new("/er");
        let specs = vec![(Utf8PathBuf::from("a.json"), "a".to_string())];
        assert_ne!(
            compute_key(&specs, "{\"sysroot\":\"a\"}", bazel, ws, er, ""),
            compute_key(&specs, "{\"sysroot\":\"b\"}", bazel, ws, er, ""),
        );
    }

    #[test]
    fn compute_key_changes_with_workspace() {
        let bazel = Utf8Path::new("/usr/bin/bazel");
        let er = Utf8Path::new("/er");
        let specs = vec![(Utf8PathBuf::from("a.json"), "a".to_string())];
        assert_ne!(
            compute_key(&specs, "{}", bazel, Utf8Path::new("/ws1"), er, ""),
            compute_key(&specs, "{}", bazel, Utf8Path::new("/ws2"), er, ""),
        );
    }

    #[test]
    fn compute_key_changes_with_launcher_dir() {
        // Editor switch on the same workspace must invalidate the
        // cache, otherwise the assembled rust-project.json would still
        // contain the previously-cached launcher path (see comment in
        // `compute_key`).
        let bazel = Utf8Path::new("/usr/bin/bazel");
        let ws = Utf8Path::new("/ws");
        let er = Utf8Path::new("/er");
        let specs = vec![(Utf8PathBuf::from("a.json"), "a".to_string())];
        assert_ne!(
            compute_key(
                &specs,
                "{}",
                bazel,
                ws,
                er,
                "/ws/.vscode/.rules_rust_analyzer",
            ),
            compute_key(
                &specs,
                "{}",
                bazel,
                ws,
                er,
                "/ws/.helix/.rules_rust_analyzer",
            ),
        );
    }
}
