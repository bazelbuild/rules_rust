use std::{env, fs};

fn main() {
    // our source file should be readable
    let path = env::var("SOURCE_FILE").unwrap();
    let generated_data = fs::read_to_string(&path).unwrap();
    assert_eq!(generated_data, "source\n");

    // our generated data file should be readable
    let path = env::var("GENERATED_DATA").unwrap();
    let generated_data = fs::read_to_string(&path).unwrap();
    assert_eq!(generated_data, "hello\n");

    // and we should be able to read (and thus execute) our tool
    let path = env::var("SOME_TOOL").unwrap();
    assert!(!fs::read(&path).unwrap().is_empty());
}
