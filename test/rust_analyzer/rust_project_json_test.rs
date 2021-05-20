use std::env;

fn main() {
    let args: Vec<String> = env::args().collect();
    let rust_project_path = args.get(1).expect("expected rust-project.json path as first argument.");
    let content = std::fs::read_to_string(rust_project_path).expect(&format!("couldn't open {}", rust_project_path));

    for dep in &["lib_dep", "extra_test_dep", "proc_macro_dep", "extra_proc_macro_dep"] {
        if !content.contains(dep) {
            panic!("expected rust-project.json to contain {}.", dep);
        }
    }
}
