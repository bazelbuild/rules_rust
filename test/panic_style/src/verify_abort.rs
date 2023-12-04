use std::path::PathBuf;
use std::process::Command;

use libc::SIGABRT;

use runfiles::Runfiles;

#[test]
fn test() {
    let r = Runfiles::create().unwrap();
    let try_catch_panic = r.rlocation(
        [
            "rules_rust",
            "test",
            "panic_style",
            if cfg!(unix) {
                "try_catch_panic"
            } else {
                "try_catch_panic.exe"
            },
        ]
        .iter()
        .collect::<PathBuf>(),
    );
    let status = Command::new(try_catch_panic)
        .status()
        .expect("Failed to spawn test process");
    assert!(!status.success(), "Test process should have failed");
    if cfg!(unix) {
        use std::os::unix::process::ExitStatusExt;
        if status.signal() != Some(SIGABRT) {
            panic!("Test process failed in an unexpected way: {:?}", status);
        }
    } else {
        // The Windows API doesn't let us validate anything else.
    }
}
