#[cfg(test)]
mod tests {
    use serde::Deserialize;
    use std::env;
    use std::path::PathBuf;

    #[derive(Deserialize)]
    struct Project {
        sysroot_src: String,
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

    /// `{output_base}/external/.../library` → `{output_base}`
    fn output_base(p: &Project) -> &str {
        p.sysroot_src
            .rsplitn(2, "/external/")
            .last()
            .expect("sysroot_src should contain /external/")
    }

    #[test]
    fn test_generated_srcs() {
        let rust_project_path = PathBuf::from(env::var("RUST_PROJECT_JSON").unwrap());
        let content = std::fs::read_to_string(&rust_project_path).unwrap();
        let project: Project =
            serde_json::from_str(&content).expect("project JSON should deserialize correctly");

        // /tmp/_bazel/12345678/external/tools/rustlib/library => /tmp/_bazel/12345678
        let output_base = output_base(&project);
        println!("output_base: {output_base}");

        let with_gen = project
            .crates
            .iter()
            .find(|c| &c.display_name == "generated_srcs")
            .unwrap();
        assert!(with_gen.root_module.starts_with("/"));
        assert!(with_gen.root_module.ends_with("/lib.rs"));

        let include_dirs = &with_gen.source.as_ref().unwrap().include_dirs;
        assert_eq!(include_dirs.len(), 2);

        // The first entry is the workspace directory.
        assert!(!include_dirs[0].starts_with(output_base));

        // The second entry is the output base, where the generated files are located.
        assert!(include_dirs[1].starts_with(output_base));
    }

    #[test]
    fn test_external_root_paths() {
        let rust_project_path = PathBuf::from(env::var("RUST_PROJECT_JSON").unwrap());
        let content = std::fs::read_to_string(&rust_project_path).unwrap();
        let project: Project =
            serde_json::from_str(&content).expect("project JSON should deserialize correctly");
        let output_base = output_base(&project);
        let mut external_roots = project
            .crates
            .iter()
            .map(|c| &c.root_module)
            .filter(|p| p.contains("/external/"))
            .peekable();

        assert!(external_roots.peek().is_some());

        let output_base_external = format!("{output_base}/external/");

        for root in external_roots {
            assert!(root.starts_with(&output_base_external));
            assert!(!root.contains("execroot"));
        }
    }
}
