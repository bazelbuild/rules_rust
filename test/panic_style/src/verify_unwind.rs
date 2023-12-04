use std::path::PathBuf;
use std::process::Command;

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
    assert!(
        status.success(),
        "Test process should have exited with success"
    );
}
