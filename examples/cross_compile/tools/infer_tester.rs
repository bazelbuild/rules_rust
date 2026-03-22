//! A test runner for `infer_test` which asserts on file types for a given file.

use runfiles::{rlocation, Runfiles};
use std::env;
use std::fs;
use std::process;

fn main() {
    // Locate the file via runfiles
    let r = Runfiles::create().unwrap();
    let file_path = rlocation!(
        r,
        env::var("INFER_TEST_FILE")
            .expect("Unable to access `INFER_TEST_FILE` environment variable.")
    )
    .expect("Failed to locate runfile");

    // Get the expected type from env
    let expected_type = env::var("INFER_TEST_EXPECTED_TYPE")
        .expect("Unable to access `INFER_TEST_EXPECTED_TYPE` environment variable.");

    // Read the file
    let file_data = fs::read(&file_path)
        .unwrap_or_else(|e| panic!("Failed to read file {:?}: {}", file_path, e));

    // Infer the file type from the file
    let inferred_type = infer::get(&file_data);

    // Assert on the results
    match inferred_type {
        Some(kind) => {
            let mime_type = kind.mime_type();
            if mime_type == expected_type {
                println!("✓ File type matches: {}", mime_type);
            } else {
                eprintln!("✗ File type mismatch!");
                eprintln!("  Expected: {}", expected_type);
                eprintln!("  Got:      {}", mime_type);
                process::exit(1);
            }
        }
        None => {
            eprintln!("✗ Could not infer file type");
            eprintln!("  Expected: {}", expected_type);
            process::exit(1);
        }
    }
}
