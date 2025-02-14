//! wasm-bindgen test runner

use std::collections::BTreeMap;
use std::env;
use std::process::{exit, Command};

use runfiles::{rlocation, Runfiles};

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
    let browser = rlocation!(
        runfiles,
        env::var("BROWSER").expect("Failed to find BROWSER env var.")
    )
    .expect("Failed to locate browser");

    // Update any existing environment variables.
    let mut env = env::vars().collect::<BTreeMap<_, _>>();

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
            env.insert(
                "CHROMEDRIVER_ARGS".to_string(),
                format!(
                    "--browser-location=\"{}\" {}",
                    browser.display(),
                    webdriver_args
                ),
            );
        }
        "firefox" => {
            env.insert(
                "GECKODRIVER".to_string(),
                webdriver.to_string_lossy().to_string(),
            );
            env.insert(
                "GECKODRIVER_ARGS".to_string(),
                format!("--binary=\"{}\" {}", browser.display(), webdriver_args),
            );
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
