#[cfg(test)]
mod tests {
    use serde::Deserialize;
    use std::env;
    use std::fs;
    use std::path::Path;
    use std::path::PathBuf;

    #[derive(Deserialize)]
    struct Project {
        crates: Vec<Crate>,
    }

    #[derive(Deserialize)]
    struct Crate {
        display_name: String,
        root_module: String,
        source: Option<Source>,
    }

    #[derive(Deserialize)]
    struct Source {
        include_dirs: Vec<String>,
    }

    #[test]
    fn test_generated_srcs() {
        let rust_project_path = PathBuf::from(env::var("RUST_PROJECT_JSON").unwrap());
        let rust_project_path = fs::canonicalize(&rust_project_path).unwrap();
        let content = std::fs::read_to_string(&rust_project_path)
            .unwrap_or_else(|_| panic!("couldn't open {:?}", &rust_project_path));
        let project: Project =
            serde_json::from_str(&content).expect("Failed to deserialize project JSON");

        let with_gen = project
            .crates
            .iter()
            .find(|c| &c.display_name == "generated_srcs")
            .unwrap();
        assert!(with_gen.root_module.starts_with("/"));
        assert!(with_gen.root_module.ends_with("/lib.rs"));

        let include_dirs = &with_gen.source.as_ref().unwrap().include_dirs;
        assert_eq!(include_dirs.len(), 2);

        let root_module_parent = Path::new(&with_gen.root_module).parent().unwrap();
        let workspace_dir = rust_project_path.parent().unwrap();

        assert!(
            include_dirs.iter().any(|p| Path::new(p) == root_module_parent),
            "expected include_dirs to contain root_module parent, got include_dirs={include_dirs:?}, root_module={}",
            with_gen.root_module,
        );
        assert!(
            include_dirs.iter().any(|p| Path::new(p) == workspace_dir),
            "expected include_dirs to contain workspace dir, got include_dirs={include_dirs:?}, workspace_dir={}",
            workspace_dir.display(),
        );
    }
}
