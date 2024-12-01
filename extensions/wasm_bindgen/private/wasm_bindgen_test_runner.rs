//! wasm-bindgen test runner

use std::collections::BTreeMap;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::{exit, Command};

use runfiles::{rlocation, Runfiles};

#[cfg(target_os = "windows")]
const PATH_SEPARATOR: &str = ";";

#[cfg(not(target_os = "windows"))]
const PATH_SEPARATOR: &str = ":";

fn new_browser_path() -> PathBuf {
    let test_tmpdir =
        PathBuf::from(env::var("TEST_TMPDIR").expect("Tests should always set `TEST_TMPDIR`"));
    test_tmpdir.join("browser")
}

#[cfg(target_os = "windows")]
fn find_browser_path(entrypoint: &Path, browser_type: &str) -> PathBuf {
    if let Some(file_name) = entrypoint.file_name() {
        let file_name = file_name.to_string_lossy();
        if file_name == format!("{}.exe", browser_type)
            || file_name == format!("{}.bat", browser_type)
        {
            return entrypoint
                .parent()
                .expect("The browser file should be a file in a directory")
                .to_path_buf();
        }
    }

    let output_dir = new_browser_path();

    let new_entrypoint = output_dir.join(format!("{}.bat", browser_type));
    if let Some(parent) = &new_entrypoint.parent() {
        fs::create_dir_all(parent)
            .unwrap_or_else(|_| panic!("Failed to create parent directory: {}", parent.display()));
    }

    fs::write(
        &new_entrypoint,
        format!(
            r#"@ECHO OFF

{} %*
"#,
            entrypoint.to_string_lossy()
        ),
    )
    .unwrap_or_else(|_| panic!("Failed to create file: {}", new_entrypoint.display()));

    output_dir
}

#[cfg(not(target_os = "windows"))]
fn find_browser_path(entrypoint: &Path, browser_type: &str) -> PathBuf {
    if let Some(file_name) = entrypoint.file_name() {
        let file_name = file_name.to_string_lossy();
        if file_name == browser_type || file_name == format!("{}.sh", browser_type) {
            return entrypoint
                .parent()
                .expect("The browser file should be a file in a directory")
                .to_path_buf();
        }
    }

    let output_dir = new_browser_path();

    let new_entrypoint = output_dir.join(format!("{}.bat", browser_type));
    if let Some(parent) = &new_entrypoint.parent() {
        fs::create_dir_all(parent)
            .unwrap_or_else(|_| panic!("Failed to create parent directory: {}", parent.display()));
    }

    std::os::unix::fs::symlink(entrypoint, &new_entrypoint).unwrap_or_else(|_| {
        panic!(
            "Failed to symlinks {} -> {}",
            entrypoint.display(),
            new_entrypoint.display()
        )
    });

    output_dir
}

fn main() {
    let runfiles = Runfiles::create().expect("Failed to locate runfiles");

    let test_runner = rlocation!(
        runfiles,
        env::var("WASM_BINDGEN_TEST_RUNNER").expect("Failed to find TEST_WASM_BINARY env var")
    )
    .expect("Failed to locate test binary");
    let test_bin = rlocation!(
        runfiles,
        env::var("TEST_WASM_BINARY").expect("Failed to find TEST_WASM_BINARY env var")
    )
    .expect("Failed to locate test binary");

    let browser_type = env::var("BROWSER_TYPE").expect("Failed to find `BROWSER_TYPE` env var");

    // Ensure the browser is located in `PATH`
    let browser_path = find_browser_path(
        &rlocation!(
            runfiles,
            env::var("BROWSER").expect("Failed to find BROWSER env var.")
        )
        .expect("Failed to locate browser"),
        &browser_type,
    );

    let browser_path = browser_path.to_string_lossy().to_string();

    // Update any existing environment variables.
    let mut env = env::vars().collect::<BTreeMap<_, _>>();
    env.entry("PATH".to_owned())
        .and_modify(|v| *v = format!("{}{}{}", browser_path, PATH_SEPARATOR, v))
        .or_insert(browser_path);

    env.insert("TMP".to_string(), env["TEST_TMPDIR"].clone());
    env.insert("TEMP".to_string(), env["TEST_TMPDIR"].clone());
    env.insert("TMPDIR".to_string(), env["TEST_TMPDIR"].clone());

    let webdriver = rlocation!(
        runfiles,
        env::var("WEBDRIVER").expect("Failed to find WEBDRIVER env var.")
    )
    .expect("Failed to locate webdriver");

    let webdriver_args =
        env::var("WEBDRIVER_ARGS").expect("Failed to find WEBDRIVER_ARGS env var.");

    match browser_type.as_str() {
        "chrome" => {
            env.insert(
                "CHROMEDRIVER".to_string(),
                webdriver.to_string_lossy().to_string(),
            );
            env.insert("CHROMEDRIVER_ARGS".to_string(), webdriver_args);
        }
        "firefox" => {
            env.insert(
                "GECKODRIVER".to_string(),
                webdriver.to_string_lossy().to_string(),
            );
            env.insert("GECKODRIVER_ARGS".to_string(), webdriver_args);
        }
        _ => {
            panic!("Unexpected browser type: {}", browser_type)
        }
    }

    if let Ok(var) = env::var("WEBDRIVER_JSON") {
        let webdriver_json = rlocation!(runfiles, var).expect("Failed to locate webdriver.json");

        env.insert(
            "WEBDRIVER_JSON".to_string(),
            webdriver_json.to_string_lossy().to_string(),
        );
    }

    // Run the test
    let mut command = Command::new(test_runner);
    command.envs(env).arg(test_bin).args(env::args().skip(1));
    let result = command
        .status()
        .unwrap_or_else(|_| panic!("Failed to spawn command: {:#?}", command));

    if !result.success() {
        exit(
            result
                .code()
                .expect("Completed processes will always have exit codes."),
        )
    }
}
