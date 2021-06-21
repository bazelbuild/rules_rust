use runfiles::Runfiles;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_deps_of_crate_and_its_test_are_merged() {
        let r = Runfiles::create().unwrap();
        let rust_project_path = r.rlocation("rules_rust/test/rust_analyzer/merging_crates_test/rust-project.json");

        let content = std::fs::read_to_string(&rust_project_path)
            .expect(&format!("couldn't open {:?}", &rust_project_path));

        for dep in &["lib_dep","", "extra_test_dep"] {
            if !content.contains(dep) {
                panic!("expected rust-project.json to contain {}.", dep);
            }
        }
    }
}
