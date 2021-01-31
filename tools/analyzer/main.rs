use std::env;
use std::ffi::OsString;
use std::fs;
use std::io::ErrorKind;
use std::path::PathBuf;
use std::process::Command;

// TODO(david): This shells out to an expected rule in the workspace root //:rust_analyzer that the user must define.
// It would be more convenient if it could automatically discover all the rust code in the workspace if this target does not exist.
fn main() {
    let repo_root = workspace_dir().expect(
        "Could not determine workspace, are you running inside a directory with WORKSPACE?",
    );
    env::set_current_dir(&repo_root).expect(
        format!(
            "could not access workspace directory: {}",
            repo_root.to_string_lossy()
        )
        .as_str(),
    );

    let bazel_command = env::var_os("BAZEL_COMMAND").unwrap_or_else(|| "bazel".into());
    let exec_root = find_exec_root(&bazel_command);
    
    build_rust_project_target(&bazel_command);
    let generated_rust_project = repo_root.join("bazel-bin").join("rust-project.json");
    let workspace_rust_project = repo_root.join("rust-project.json");

    // The generated_rust_project has a template string we must replace with the workspace name.
    let generated_json = fs::read_to_string(&generated_rust_project)
        .expect("failed to read generated rust-project.json");

    // It's OK if the file doesn't exist.
    match fs::remove_file(&workspace_rust_project) {
        Ok(_) => {}
        Err(err) if err.kind() == ErrorKind::NotFound => {},
        Err(err) => panic!("Unexpected error removing old rust-project.json: {}", err),
    }
    fs::write(
        workspace_rust_project,
        generated_json.replace("__EXEC_ROOT__", &exec_root.to_string_lossy()),
    )
    .expect("failed to write workspace rust-project.json");
}

fn workspace_dir() -> Option<PathBuf> {
    if let Some(ws_dir) = env::var_os("BUILD_WORKSPACE_DIRECTORY") {
        Some(PathBuf::from(ws_dir))
    } else {
        let mut maybe_cwd = env::current_dir().ok();
        while let Some(cwd) = maybe_cwd {
            for workspace_filename in &["WORKSPACE", "WORKSPACE.bazel"] {
                let mut workspace_path = cwd.clone();
                workspace_path.push(workspace_filename);
                if workspace_path.is_file() {
                    return Some(PathBuf::from(cwd));
                }
            }
            maybe_cwd = cwd.parent().map(PathBuf::from);
        }
        None
    }
}

fn build_rust_project_target(bazel_command: &OsString) {
    let analyzer_target =
        env::var_os("BAZEL_ANALYZER_TARGET").unwrap_or_else(|| "//:rust_analyzer".into());

    let output = Command::new(bazel_command)
        .arg("build")
        .arg(&analyzer_target)
        .output()
        .expect("failed to execute bazel process");
    if !output.status.success() {
        panic!(
            "bazel build failed:({}) of {:?}:\n{}",
            output.status,
            analyzer_target,
            String::from_utf8_lossy(&output.stderr)
        );
    }
}

fn find_exec_root(bazel_command: &OsString) -> PathBuf {
    let output = Command::new(bazel_command)
        .arg("info")
        .arg("execution_root")
        .output()
        .expect("failed to execute bazel process");
    if !output.status.success() {
        panic!(
            "Failed to find execution_root:({}):\n{}",
            output.status,
            String::from_utf8_lossy(&output.stderr)
        );
    }

    // TODO: This only works with UTF8 filenames. Esoteric directory name handling
    // would would require platform specific code.
    PathBuf::from(String::from_utf8_lossy(output.stdout.as_slice()).into_owned())
}