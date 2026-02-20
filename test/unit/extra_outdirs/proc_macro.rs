// Similar to
// https://github.com/napi-rs/napi-rs/blob/main/crates/macro/src/expand/typedef/type_def.rs#L11-L12
// this proc macro has a side-effect of writing extra metadata directories.
use proc_macro::TokenStream;
use std::env;
use std::fs;
use std::path::PathBuf;

#[proc_macro]
pub fn write_to_outdirs(_item: TokenStream) -> TokenStream {
    // Read the output directory paths from Bazel
    // Format: EXTRA_OUTDIRS_PATHS=dir1:path1,dir2:path2
    let outdirs_paths = env::var("EXTRA_OUTDIRS_PATHS")
        .expect("EXTRA_OUTDIRS_PATHS environment variable must be set");

    // Write to the output directories declared by Bazel
    for entry in outdirs_paths.split(',') {
        if let Some((_dir, path)) = entry.split_once(':') {
            let dir_path = PathBuf::from(path.trim());

            // Create the directory if it doesn't exist
            if let Err(e) = fs::create_dir_all(&dir_path) {
                panic!("Failed to create directory {}: {:?}", dir_path.display(), e);
            }
            // Write a marker file to ensure the directory is created
            let marker_file = dir_path.join("marker.txt");
            if let Err(e) = fs::write(&marker_file, "created by proc-macro") {
                panic!(
                    "Failed to write marker file to {}: {:?}",
                    marker_file.display(),
                    e
                );
            }
        }
    }
    TokenStream::new()
}
