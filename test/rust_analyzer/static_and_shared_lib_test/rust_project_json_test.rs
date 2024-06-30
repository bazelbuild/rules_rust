#[cfg(test)]
mod tests {
    use std::env;
    use std::path::PathBuf;

    #[test]
    fn test_deps_of_crate_and_its_test_are_merged() {
        let rust_project_path = PathBuf::from(env::var("RUST_PROJECT_JSON").unwrap());

        let content = std::fs::read_to_string(&rust_project_path)
            .unwrap_or_else(|_| panic!("couldn't open {:?}", &rust_project_path));

        println!("{}", content);

        let expected_cdylib = r#"{
      "display_name": "greeter_cdylib",
      "root_module": "shared_lib.rs","#;
        assert!(
            content.contains(expected_cdylib),
            "expected rust-project.json to contain a rust_shared_library target."
        );

        let expected_staticlib = r#"{
      "display_name": "greeter_staticlib",
      "root_module": "static_lib.rs","#;
        assert!(
            content.contains(expected_staticlib),
            "expected rust-project.json to contain a rust_static_library target."
        );
    }
}
