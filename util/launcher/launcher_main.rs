use std::collections::BTreeMap;
use std::fs::File;
use std::io::{BufReader, BufRead};
use std::path::PathBuf;
use std::process::Command;
use std::vec::Vec;

#[cfg(target_family = "unix")]
use std::os::unix::process::CommandExt;

/// This string must match the one found in `_create_test_launcher`
const LAUNCHFILES_ENV_PATH: &'static str = ".launchfiles/env";

/// Load environment variables from a uniquly formatted 
fn environ() -> BTreeMap<String, String> {
    let mut environ = BTreeMap::new();

    let mut key: Option<String> = None;

    // Load the environment file into a map
    let env_path = std::env::args().nth(0).expect("arg 0 was not set") + LAUNCHFILES_ENV_PATH;
    let file = File::open(env_path).expect("Failed to load the environment file");

    // Find all environment variables by reading pairs of lines as key/value pairs
    for line in BufReader::new(file).lines() {
        if key.is_none() {
            key = Some(line.expect("Failed to read line"));
            continue;
        }

        environ.insert(
            key.expect("Key is not set"), 
            line.expect("Failed to read line"),
        );

        key = None;
    }
    
    environ
}

/// Locate the executable based on the name of the launcher executable
fn executable() -> PathBuf {
    let mut exec_path = std::env::args().nth(0).expect("arg 0 was not set");
    let stem_index = exec_path.rfind(".launcher").expect("This executable should always contain `.launcher`");

    // Remove the substring from the exec path
    for _char in ".launcher".chars() {
        exec_path.remove(stem_index);
    }
    
    PathBuf::from(exec_path)
}

/// Parse the command line arguments but skip the first element which
/// is the path to the test runner executable.
fn args() -> Vec<String> {
    std::env::args().skip(1).collect()
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
    let output = Command::new(executable)
    .envs(environ.iter())
    .args(args)
    .output()
    .expect("Failed to run process");

    std::process::exit(output.status.code().unwrap_or(1));
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


#[cfg(test)]
mod test {

    #[test]
    fn test_environ() {

    }

    #[test]
    fn test_executable() {

    }

    #[test]
    fn test_args() {

    }
}