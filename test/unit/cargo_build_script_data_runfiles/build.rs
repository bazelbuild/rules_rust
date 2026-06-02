use std::env;
use std::path::Path;

fn main() {
    let r = runfiles::Runfiles::create().unwrap();
    // The rlocation path is relative to the workspace name
    let rlocation_path = "rules_rust/test/unit/cargo_build_script_data_runfiles/data.txt";
    let path = runfiles::rlocation!(r, rlocation_path);

    match path {
        Some(p) => {
            if p.exists() {
                println!("cargo:warning=Found data.txt at {}", p.display());
            } else {
                panic!("data.txt path returned but does not exist: {}", p.display());
            }
        }
        None => {
            panic!("Failed to resolve runfile path: {}", rlocation_path);
        }
    }
}
