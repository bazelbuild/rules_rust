#[cfg(test)]
mod tests {
    use runfiles::Runfiles;

    #[test]
    fn test_aspect_traverses_all_the_right_corners_of_target_graph() {
        let r = Runfiles::create().unwrap();
        let rust_project_path =
            r.rlocation("rules_rust/test/rust_analyzer/aspect_traversal_test/rust-project.json");

        let content = std::fs::read_to_string(&rust_project_path)
            .expect(&format!("couldn't open {:?}", &rust_project_path));

        for dep in &[
            "lib_dep",
            "extra_test_dep",
            "proc_macro_dep",
            "extra_proc_macro_dep",
        ] {
            assert!(
                content.contains(dep),
                "expected rust-project.json to contain {}.",
                dep
            );
        }
    }
}
