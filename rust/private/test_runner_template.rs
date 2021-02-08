use std::vec::Vec;
use std::collections::BTreeMap;
use std::process::Command;

#[cfg(target_family = "unix")]
use std::os::unix::process::CommandExt;

/// The executable to launch from this test runner
const EXECUTABLE: &'static str = r#####"{executable}"#####;

/// This is a templated function for defining a map of environment
/// variables. The comment in this function is replaced by the
/// definition of this map.
fn environ() -> BTreeMap<&'static str, &'static str> {
// {environ}
}

/// Parse the command line arguments but skip the first element which
/// is the path to the test runner executable.
fn args() -> Vec<String> {
    std::env::args().skip(1).collect()
}

/// Simply replace the current process with our test
#[cfg(target_family = "unix")]
fn exec(environ: BTreeMap<&'static str, &'static str>) {
    Command::new(EXECUTABLE)
    .envs(environ.iter())
    .args(args())
    .exec();
}

/// On windows, there is no way to replace the current process
/// so instead we allow the command to run in a subprocess.
#[cfg(target_family = "windows")]
fn exec(environ: BTreeMap<&'static str, &'static str>) {
    let output = Command::new(EXECUTABLE)
    .envs(environ.iter())
    .args(args())
    .output()
    .expect("Failed to run process");

    std::process::exit(output.status.code().unwrap_or(1));
}

fn main() {
    // Gather environment variables
    let environ = environ();

    // Replace the current process with the test target
    exec(environ);

    panic!("Process did not exit");
}
