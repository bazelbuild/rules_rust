//! Integration test asserting the shape of the merged `rust_workspace_doc` output.

use std::fs;
use std::path::{Path, PathBuf};

fn docs_dir() -> PathBuf {
    PathBuf::from(std::env::var("WORKSPACE_DOCS_DIR").expect("WORKSPACE_DOCS_DIR is not set"))
}

/// Recursively collect all file paths under `dir`.
fn collect_files(dir: &Path, files: &mut Vec<PathBuf>) {
    for entry in
        fs::read_dir(dir).unwrap_or_else(|e| panic!("failed to read {}: {}", dir.display(), e))
    {
        let path = entry.expect("failed to read directory entry").path();
        if path.is_dir() {
            collect_files(&path, files);
        } else {
            files.push(path);
        }
    }
}

#[test]
fn contains_docs_for_every_workspace_crate() {
    for crate_name in ["alpha", "beta", "gamma"] {
        let index = docs_dir().join(crate_name).join("index.html");
        assert!(
            index.is_file(),
            "expected documentation for crate `{}` at {}",
            crate_name,
            index.display()
        );
    }
}

#[test]
fn contains_merged_search_index() {
    let mut files = Vec::new();
    collect_files(&docs_dir(), &mut files);

    // The merged search index is a `search-index*.js` file (or a
    // `search.index/` directory in newer rustdoc versions) that mentions
    // every crate.
    let search_files: Vec<&PathBuf> = files
        .iter()
        .filter(|path| {
            let name = path.file_name().unwrap().to_string_lossy();
            let in_search_dir = path
                .parent()
                .map(|parent| {
                    parent.components().any(|component| {
                        component
                            .as_os_str()
                            .to_string_lossy()
                            .starts_with("search")
                    })
                })
                .unwrap_or(false);
            name.starts_with("search-index") || in_search_dir
        })
        .collect();
    assert!(
        !search_files.is_empty(),
        "expected a merged search index in the documentation tree"
    );

    let search_content = search_files
        .iter()
        .map(|path| fs::read_to_string(path).unwrap_or_default())
        .collect::<String>();
    for crate_name in ["alpha", "beta", "gamma"] {
        assert!(
            search_content.contains(crate_name),
            "expected the merged search index to mention crate `{}`",
            crate_name
        );
    }
}

#[test]
fn contains_root_index_page() {
    let index = docs_dir().join("index.html");
    assert!(
        index.is_file(),
        "expected a root index.html listing all crates"
    );

    let content = fs::read_to_string(&index).expect("failed to read root index.html");
    for crate_name in ["alpha", "beta", "gamma"] {
        assert!(
            content.contains(&format!("{}/index.html", crate_name)),
            "expected the root index.html to link to crate `{}`",
            crate_name
        );
    }
}

#[test]
fn cross_crate_links_resolve() {
    let beta_fn = docs_dir().join("beta").join("fn.loud_greeting.html");
    let content = fs::read_to_string(&beta_fn)
        .unwrap_or_else(|e| panic!("failed to read {}: {}", beta_fn.display(), e));
    assert!(
        content.contains("alpha/struct.Greeting.html"),
        "expected `beta::loud_greeting` docs to link to `alpha::Greeting`"
    );
}
