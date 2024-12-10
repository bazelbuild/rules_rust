//! A utility script for the "complicated dependencies" example.

use std::path::PathBuf;
use std::{env, fs};

fn main() {
    let ssl = PathBuf::from(env::var("ARG_SSL").unwrap());
    let crypto = PathBuf::from(env::var("ARG_CRYPTO").unwrap());
    let output = PathBuf::from(env::var("ARG_OUTPUT").unwrap());

    let build_dir = output.join("build");

    fs::create_dir_all(&build_dir).unwrap();

    fs::copy(&ssl, build_dir.join(ssl.file_name().unwrap())).unwrap();
    fs::copy(&crypto, build_dir.join(crypto.file_name().unwrap())).unwrap();
}
