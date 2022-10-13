use std::{env::var, fs, io::Result};

fn main() {
    let dep_dir = &var("DEP_DIR").expect("DEP_DIR should be set");
    let entries = fs::read_dir(dep_dir)
        .expect("Failed to open DEP_DIR directory")
        .collect::<Result<Vec<_>>>()
        .expect("Failed to read DEP_DIR directory entries");
    let entries = entries
        .iter()
        .map(|entry| {
            entry
                .path()
                .file_name()
                .unwrap()
                .to_string_lossy()
                .to_string()
        })
        .collect::<Vec<_>>();
    assert_eq!(entries, vec!["a_file".to_string()]);
}
