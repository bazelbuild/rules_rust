use runfiles::Runfiles;

fn main() {
    let r = Runfiles::create().unwrap();
    let rust_project_path = r.rlocation("rules_rust/test/rust_analyzer/rust-project.json");

    let content = std::fs::read_to_string(&rust_project_path)
        .expect(&format!("couldn't open {:?}", &rust_project_path));

    for dep in &[
        "lib_dep",
        "extra_test_dep",
        "proc_macro_dep",
        "extra_proc_macro_dep",
    ] {
        if !content.contains(dep) {
            panic!("expected rust-project.json to contain {}.", dep);
        }
    }
}
