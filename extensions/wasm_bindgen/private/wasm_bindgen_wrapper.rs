//! A process wrapper for `wasm-bindgen` that ensures the `snippets` tree
//! artifact directory is never empty after the tool runs.
//!
//! Bazel does not track empty directories in remote execution, so an empty
//! `snippets` directory can cause action cache misses or "output not created"
//! errors. See <https://github.com/bazelbuild/bazel/issues/28286>.

use std::env;
use std::fs;
use std::path::Path;
use std::process::{self, Command};

fn main() {
    let mut args = env::args().skip(1);

    let bindgen = args
        .next()
        .expect("expected wasm-bindgen binary path as first argument");
    let snippets_dir = args
        .next()
        .expect("expected snippets dir as second argument");

    let remaining: Vec<String> = args.skip_while(|a| a == "--").collect();

    let status = Command::new(&bindgen)
        .args(&remaining)
        .status()
        .unwrap_or_else(|e| panic!("failed to spawn {}: {}", bindgen, e));

    if !status.success() {
        process::exit(status.code().unwrap_or(1));
    }

    let is_empty = fs::read_dir(&snippets_dir)
        .map(|mut entries| entries.next().is_none())
        .unwrap_or(true);

    if is_empty {
        let sentinel = Path::new(&snippets_dir).join(".empty");
        fs::File::create(&sentinel)
            .unwrap_or_else(|e| panic!("failed to create {}: {}", sentinel.display(), e));
    }
}
