#[cfg(test)]
mod tests {
    use std::env;
    use std::path::PathBuf;

    #[test]
    fn test_deps_of_crate_and_its_test_are_merged() {
        let rust_project_path = PathBuf::from(env::var("RUST_PROJECT_JSON").unwrap());

        let content = std::fs::read_to_string(&rust_project_path)
            .unwrap_or_else(|_| panic!("couldn't open {:?}", &rust_project_path));

        assert!(
            content.contains(r#""root_module":"mylib.rs","edition":"2018","deps":[{"crate":0,"name":"extra_test_dep"},{"crate":1,"name":"lib_dep"}]"#),
            "expected rust-project.json to contain both lib_dep and extra_test_dep in deps of mylib.rs.");
    }
}
