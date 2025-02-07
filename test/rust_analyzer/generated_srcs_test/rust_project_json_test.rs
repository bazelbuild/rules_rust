#[cfg(test)]
mod tests {
    use serde::Deserialize;
    use std::env;
    use std::path::PathBuf;

    #[derive(Deserialize)]
    struct Project {
        crates: Vec<Crate>,
    }

    #[derive(Deserialize)]
    struct Crate {
        display_name: String,
        root_module: String,
    }

    #[test]
    fn test_generated_srcs() {
        let rust_project_path = PathBuf::from(env::var("RUST_PROJECT_JSON").unwrap());
        let content = std::fs::read_to_string(&rust_project_path)
            .unwrap_or_else(|_| panic!("couldn't open {:?}", &rust_project_path));
        println!("{}", content);
        let project: Project =
            serde_json::from_str(&content).expect("Failed to deserialize project JSON");

        let gen = project
            .crates
            .iter()
            .find(|c| &c.display_name == "generated_srcs")
            .unwrap();

        // This target has mixed generated+plain sources, so rules_rust provides a
        // directory where the root module is a symlink.
        // However in the crate spec, we want the root_module to be a workspace path
        // when possible.
        let workspace_path = PathBuf::from(env::var("WORKSPACE").unwrap());
        assert_eq!(
            gen.root_module,
            workspace_path.join("lib.rs").to_string_lossy()
        );
    }
}
