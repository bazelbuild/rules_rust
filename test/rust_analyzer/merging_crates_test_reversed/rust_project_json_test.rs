#[cfg(test)]
mod tests {
    use runfiles::Runfiles;

    #[test]
    fn test_deps_of_crate_and_its_test_are_merged() {
        let r = Runfiles::create().unwrap();
        let rust_project_path = r.rlocation(
            "rules_rust/test/rust_analyzer/merging_crates_test_reversed/rust-project.json",
        );

        let content = std::fs::read_to_string(&rust_project_path)
            .expect(&format!("couldn't open {:?}", &rust_project_path));

        assert!(
            content.contains(r#""root_module":"test/rust_analyzer/merging_crates_test_reversed/mylib.rs","deps":[{"crate":0,"name":"lib_dep"},{"crate":1,"name":"extra_test_dep"}]"#),
            "expected rust-project.json to contain both lib_dep and extra_test_dep in deps of mylib.rs.");
    }
}
