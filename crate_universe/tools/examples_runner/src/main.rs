//! A binary for building and testing examples using distribution artifacts

use std::collections::HashMap;
use std::env;
use std::fs::File;
use std::io::{BufRead, BufReader};
use std::path::{Path, PathBuf};
use std::process;

use flate2::read::GzDecoder;
use hex::ToHex;
use sha2::{Digest, Sha256};
use tar::Archive;
use url::Url;

fn untar_into(tarbal: &Path, dir: &Path) {
    let tar_gz = File::open(tarbal).unwrap();
    let tar = GzDecoder::new(tar_gz);
    let mut archive = Archive::new(tar);
    archive.unpack(dir).unwrap();
}

fn calculate_sha256(file_path: &Path) -> String {
    let file = File::open(file_path).unwrap();
    let mut reader = BufReader::new(file);
    let mut hasher = Sha256::new();

    loop {
        let consummed = {
            let buffer = reader.fill_buf().unwrap();
            if buffer.is_empty() {
                break;
            }
            hasher.update(buffer);
            buffer.len()
        };
        reader.consume(consummed);
    }

    let digest = hasher.finalize();
    digest.encode_hex::<String>()
}

fn parse_startup_args() -> Vec<String> {
    let var = match env::var("BAZEL_STARTUP_FLAGS") {
        Ok(var) => var,
        Err(_) => return Vec::new(),
    };

    var.split(' ').map(String::from).collect()
}

fn execute_bazel(
    startup_args: &[String],
    command: &[&str],
    workspace_root: &Path,
    envs: &HashMap<String, String>,
) {
    println!("Env: {:#?}", envs);
    println!("Executing Bazel: {:?}", command);

    let status = process::Command::new("bazel")
        .current_dir(workspace_root)
        .envs(envs)
        .args(startup_args)
        .args(command)
        .status()
        .unwrap();

    if !status.success() {
        process::exit(status.code().unwrap_or(1));
    }
}

fn vendor_dependencies(
    workspace_root: &Path,
    startup_args: &[String],
    args: &[&str],
    envs: &HashMap<String, String>,
) {
    // Query for a list of vendor targets
    println!("Determining vendor targets");
    let output = process::Command::new("bazel")
        .current_dir(workspace_root)
        .envs(envs)
        .args(startup_args)
        .arg("query")
        .arg("kind(crates_vendor, //...)")
        .args(args)
        .output()
        .unwrap();

    if !output.status.success() {
        eprintln!("{}", String::from_utf8_lossy(&output.stderr));
        process::exit(output.status.code().unwrap_or(1));
    }

    // Run all the vendor targets
    String::from_utf8_lossy(&output.stdout)
        .split_whitespace()
        .for_each(|target| {
            if target.is_empty() {
                return;
            }
            println!("Vendoring {}", target);
            let status = process::Command::new("bazel")
                .current_dir(workspace_root)
                .envs(envs)
                .args(startup_args)
                .arg("run")
                .arg(target)
                .args(args)
                .status()
                .unwrap();

            if !status.success() {
                process::exit(status.code().unwrap_or(1));
            }
        })
}

fn main() {
    let current_dir = env::current_dir().unwrap();

    // Locate cargo-bazel binary
    let cargo_bazel_path = current_dir.join(env!("CARGO_BAZEL_BIN"));
    let cargo_bazel_sha256 = calculate_sha256(&cargo_bazel_path);

    // Locate distrobution tar
    let distro_tar_path = current_dir.join(env!("DISTRO_ARCHIVE"));

    // Locate the examples directory
    let examples_dir = PathBuf::from(env::var("BUILD_WORKSPACE_DIRECTORY").unwrap())
        .join(env!("EXAMPLES_PACKAGE"));

    // Create temp directory
    let tempdir = tempfile::tempdir().unwrap();

    // Untar the distro package
    untar_into(&distro_tar_path, tempdir.as_ref());
    let override_repo = format!(
        "--override_repository=cargo_bazel={}",
        tempdir.as_ref().display()
    );

    let mut envs = HashMap::new();
    envs.insert("RUST_BACKTRACE".to_owned(), "full".to_owned());
    envs.insert(
        "CARGO_BAZEL_GENERATOR_URL".to_owned(),
        Url::from_file_path(&cargo_bazel_path).unwrap().to_string(),
    );
    envs.insert(
        "CARGO_BAZEL_GENERATOR_SHA256".to_owned(),
        cargo_bazel_sha256,
    );
    envs.insert("CARGO_BAZEL_ISOLATED".to_owned(), "true".to_owned());

    let startup_args = parse_startup_args();

    // Vendor all targets
    vendor_dependencies(
        &examples_dir,
        &startup_args,
        &[override_repo.as_str()],
        &envs,
    );

    // Build and test all targets
    execute_bazel(
        &startup_args,
        &["test", "//...", override_repo.as_str()],
        &examples_dir,
        &envs,
    );

    // Update the environment
    envs.insert("CARGO_BAZEL_REPIN".to_owned(), "true".to_owned());
    envs.remove("CARGO_BAZEL_ISOLATED");

    // Build and test all targets while repinning
    execute_bazel(
        &startup_args,
        &["test", "//...", override_repo.as_str()],
        &examples_dir,
        &envs,
    );
}
