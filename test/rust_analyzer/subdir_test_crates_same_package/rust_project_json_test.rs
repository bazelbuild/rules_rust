#[cfg(test)]
mod tests {
    use serde::Deserialize;
    use std::collections::BTreeSet;
    use std::env;
    use std::path::PathBuf;

    #[derive(Deserialize)]
    struct Project {
        crates: Vec<Crate>,
    }

    #[derive(Deserialize)]
    struct Crate {
        root_module: String,
        is_workspace_member: Option<bool>,
        source: Option<Source>,
    }

    #[derive(Deserialize)]
    struct Source {
        include_dirs: Vec<String>,
    }

    fn normalize(path: &str) -> String {
        path.trim_end_matches('/').to_owned()
    }

    #[test]
    fn test_same_package_crates_share_include_dir() {
        let rust_project_path = PathBuf::from(env::var("RUST_PROJECT_JSON").unwrap());
        let content = std::fs::read_to_string(&rust_project_path)
            .unwrap_or_else(|_| panic!("couldn't open {:?}", &rust_project_path));
        let project: Project =
            serde_json::from_str(&content).expect("Failed to deserialize project JSON");

        let lib = project
            .crates
            .iter()
            .find(|c| c.is_workspace_member == Some(true) && c.root_module.ends_with("/lib.rs"))
            .expect("missing library crate");
        let test = project
            .crates
            .iter()
            .find(|c| {
                c.is_workspace_member == Some(true)
                    && c.root_module.ends_with("/subdir/subdir_test.rs")
            })
            .expect("missing subdir test crate");

        let lib_include_dirs: BTreeSet<_> = lib
            .source
            .as_ref()
            .expect("lib crate missing source field")
            .include_dirs
            .iter()
            .map(|p| normalize(p))
            .collect();
        let test_include_dirs: BTreeSet<_> = test
            .source
            .as_ref()
            .expect("test crate missing source field")
            .include_dirs
            .iter()
            .map(|p| normalize(p))
            .collect();

        let shared_dir = lib_include_dirs
            .intersection(&test_include_dirs)
            .next()
            .expect("expected crates in same package to share an include_dir");

        assert!(lib.root_module.starts_with(&format!("{}/", shared_dir)));
        assert!(test.root_module.starts_with(&format!("{}/", shared_dir)));
    }
}
