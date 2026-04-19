use std::process::Command;
use std::str;

use runfiles::Runfiles;

/// Runs fake_rustc under process_wrapper with the specified wrapper arguments.
pub(crate) fn fake_rustc(
    process_wrapper_args: &[&'static str],
    fake_rustc_args: &[&'static str],
    should_succeed: bool,
) -> String {
    let r = Runfiles::create().unwrap();
    let fake_rustc = runfiles::rlocation!(r, env!("FAKE_RUSTC_RLOCATIONPATH")).unwrap();
    let process_wrapper = runfiles::rlocation!(r, env!("PROCESS_WRAPPER_RLOCATIONPATH")).unwrap();

    let output = Command::new(process_wrapper)
        .args(process_wrapper_args)
        .arg("--")
        .arg(fake_rustc)
        .args(fake_rustc_args)
        .output()
        .unwrap();

    if should_succeed {
        assert!(
            output.status.success(),
            "unable to run process_wrapper: {} {}",
            str::from_utf8(&output.stdout).unwrap(),
            str::from_utf8(&output.stderr).unwrap(),
        );
    }

    String::from_utf8(output.stderr).unwrap()
}
