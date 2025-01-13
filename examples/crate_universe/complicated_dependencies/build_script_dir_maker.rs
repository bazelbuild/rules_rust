//! A utility script for the "complicated dependencies" example.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};
use std::{env, fs};

fn clean_filename(path: &Path) -> String {
    let name = path.file_name().unwrap().to_string_lossy().to_string();
    name.replace("_internal", "").to_string()
}

fn main() {
    let ssl = PathBuf::from(env::var("ARG_SSL").unwrap());
    let crypto = PathBuf::from(env::var("ARG_CRYPTO").unwrap());
    let output = PathBuf::from(env::var("ARG_OUTPUT").unwrap());
    let headers = env::var("ARG_HEADERS")
        .unwrap()
        .split(" ")
        .filter(|h| h.contains("/include/"))
        .map(|h| {
            let (_, dest) = h.split_once("/include/").unwrap();
            (PathBuf::from(h), dest.to_string())
        })
        .collect::<BTreeMap<PathBuf, String>>();

    let build_dir = output.join("build");
    fs::create_dir_all(&build_dir).unwrap();

    fs::copy(&ssl, build_dir.join(clean_filename(&ssl))).unwrap();
    fs::copy(&crypto, build_dir.join(clean_filename(&crypto))).unwrap();

    let include_dir = output.join("include");
    fs::create_dir_all(&include_dir).unwrap();
    for (header, dest) in headers {
        let abs_dest = include_dir.join(dest);
        if let Some(parent) = abs_dest.parent() {
            fs::create_dir_all(parent).unwrap();
        }
        fs::copy(&header, abs_dest).unwrap();
    }
}
