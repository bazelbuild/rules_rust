#[cfg(test)]
mod tests {
    use std::env;
    use std::path::PathBuf;

    #[allow(clippy::uninlined_format_args)]
    #[test]
    fn test_aspect_traverses_all_the_right_corners_of_target_graph() {
        let rust_project_path = PathBuf::from(env::var("RUST_PROJECT_JSON").unwrap());

        let content = std::fs::read_to_string(&rust_project_path)
            .unwrap_or_else(|_| panic!("couldn't open {:?}", &rust_project_path));

        for dep in &[
            "lib_dep",
            "actual_dep",
            "dep_of_aliased_dep",
            "custom_actual_dep",
            "dep_of_custom_aliased_dep",
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
