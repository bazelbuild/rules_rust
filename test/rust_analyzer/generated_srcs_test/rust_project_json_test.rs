#[cfg(test)]
mod tests {
    use std::env;
    use std::path::PathBuf;

    #[test]
    fn test_deps_of_crate_and_its_test_are_merged() {
        let rust_project_path = PathBuf::from(env::var("RUST_PROJECT_JSON").unwrap());

        let content = std::fs::read_to_string(&rust_project_path)
            .unwrap_or_else(|_| panic!("couldn't open {:?}", &rust_project_path));

        let output_base = content
            .lines()
            .find(|text| text.trim_start().starts_with("\"sysroot_src\":"))
            .map(|text| {
                let mut split = text.splitn(2, "\"sysroot_src\": ");
                let mut with_hash = split.nth(1).unwrap().trim().splitn(2, "/external/");
                let mut output = with_hash.next().unwrap().rsplitn(2, '/');
                output.nth(1).unwrap()
            })
            .expect("Failed to find sysroot entry.");

        let expected = r#"{
      "display_name": "generated_srcs",
      "root_module": "lib.rs",
      "edition": "2021",
      "deps": [],
      "is_workspace_member": true,
      "source": {
        "include_dirs": [
          "#
        .to_owned()
            + output_base;

        println!("{}", content);
        assert!(
            content.contains(&expected),
            "expected rust-project.json to contain the following block:\n{}",
            expected
        );
    }
}
