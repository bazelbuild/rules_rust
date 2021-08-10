use std::collections::BTreeMap;
use std::fs::File;
use std::io::{BufRead, BufReader};
use std::path::PathBuf;
use std::process::Command;
use std::vec::Vec;

#[cfg(target_family = "unix")]
use std::os::unix::process::CommandExt;

/// This string must match the one found in `_create_test_launcher`
const LAUNCHFILES_ENV_PATH: &str = ".launchfiles/env";

/// This string must match the one found in `_create_test_launcher`
const LAUNCHFILES_ARGS_PATH: &str = ".launchfiles/args";

/// Load environment variables from a uniquly formatted
fn environ() -> BTreeMap<String, String> {
    let mut environ = BTreeMap::new();

    let mut key: Option<String> = None;

    // Consume the first argument (argv[0])
    let exe_path = std::env::args().next().expect("arg 0 was not set");

    // Load the environment file into a map
    let env_path = exe_path + LAUNCHFILES_ENV_PATH;
    let file = File::open(env_path).expect("Failed to load the environment file");

    // Variables will have the `${pwd}` variable replaced which is rendered by
    // `@rules_rust//rust/private:util.bzl::expand_dict_value_locations`
    let pwd = std::env::current_dir().expect("Failed to get current working directory");
    let pwd_str = pwd.to_string_lossy();

    // Find all environment variables by reading pairs of lines as key/value pairs
    for line in BufReader::new(file).lines() {
        if key.is_none() {
            key = Some(line.expect("Failed to read line"));
            continue;
        }

        environ.insert(
            key.expect("Key is not set"),
            line.expect("Failed to read line")
                .replace("${pwd}", &pwd_str),
        );

        key = None;
    }

    environ
}

/// Locate the underlying executable intended to be started under the launcher
fn executable() -> PathBuf {
    // When no executable is provided explicitly via the launcher file, fallback
    // to searching for the executable based on the name of the launcher itself.
    let mut exec_path = std::env::args().next().expect("arg 0 was not set");
    let stem_index = exec_path
        .rfind(".launcher")
        .expect("This executable should always contain `.launcher`");

    // Remove the substring from the exec path
    for _char in ".launcher".chars() {
        exec_path.remove(stem_index);
    }

    PathBuf::from(exec_path)
}

/// Parse the command line arguments but skip the first element which
/// is the path to the test runner executable.
fn args() -> Vec<String> {
    // Load the environment file into a map
    let args_path = std::env::args().next().expect("arg 0 was not set") + LAUNCHFILES_ARGS_PATH;
    let file = File::open(args_path).expect("Failed to load the environment file");

    // Variables will have the `${pwd}` variable replaced which is rendered by
    // `@rules_rust//rust/private:util.bzl::expand_dict_value_locations`
    let pwd = std::env::current_dir().expect("Failed to get current working directory");
    let pwd_str = pwd.to_string_lossy();

    // Note that arguments from the args file always go first
    BufReader::new(file)
        .lines()
        .map(|line| {
            line.expect("Failed to read file")
                .replace("${pwd}", &pwd_str)
        })
        .chain(std::env::args().skip(1))
        .collect()
}

/// Simply replace the current process with our test
#[cfg(target_family = "unix")]
fn exec(environ: BTreeMap<String, String>, executable: PathBuf, args: Vec<String>) {
    let error = Command::new(&executable)
        .envs(environ.iter())
        .args(args)
        .exec();

    panic!("Process failed to start: {:?} with {:?}", executable, error)
}

/// On windows, there is no way to replace the current process
/// so instead we allow the command to run in a subprocess.
#[cfg(target_family = "windows")]
fn exec(environ: BTreeMap<String, String>, executable: PathBuf, args: Vec<String>) {
    let result = Command::new(executable)
        .envs(environ.iter())
        .args(args)
        .status()
        .expect("Failed to run process");

    std::process::exit(result.code().unwrap_or(1));
}

/// Main entrypoint
fn main() {
    // Gather environment variables
    let environ = environ();

    // Gather arguments
    let args = args();

    // Find executable
    let executable = executable();

    // Replace the current process with the test target
    exec(environ, executable, args);

    // The call to exec should have exited the application.
    // This code should be unreachable.
    panic!("Process did not exit");
}
