#[cfg(test)]
mod tests {
    use serde::Deserialize;
    use std::env;
    use std::path::{Path, PathBuf};

    #[derive(Deserialize)]
    struct Project {
        crates: Vec<Crate>,
    }

    #[derive(Deserialize)]
    struct Crate {
        display_name: String,
        root_module: String,
        build: Option<Build>,
    }

    #[derive(Deserialize)]
    struct Build {
        build_file: String,
    }

    #[test]
    fn test_static_and_shared_lib() {
        let rust_project_path = PathBuf::from(env::var("RUST_PROJECT_JSON").unwrap());
        let content = std::fs::read_to_string(&rust_project_path)
            .unwrap_or_else(|_| panic!("couldn't open {:?}", rust_project_path));
        println!("{}", content);
        let project: Project =
            serde_json::from_str(&content).expect("Failed to deserialize project JSON");

        let cdylib = project
            .crates
            .iter()
            .find(|c| &c.display_name == "greeter_cdylib")
            .unwrap();
        assert!(cdylib.root_module.ends_with("/shared_lib.rs"));
        assert_eq!(
            Path::new(&cdylib.build.as_ref().unwrap().build_file),
            Path::new(&cdylib.root_module)
                .parent()
                .unwrap()
                .join("BUILD.bazel"),
        );

        let staticlib = project
            .crates
            .iter()
            .find(|c| &c.display_name == "greeter_staticlib")
            .unwrap();
        assert!(staticlib.root_module.ends_with("/static_lib.rs"));
    }
}
