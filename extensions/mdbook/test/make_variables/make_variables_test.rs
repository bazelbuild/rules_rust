//! Runs the `mdbook` named by the `MDBOOK_RLOCATIONPATH` Make variable.

use runfiles::{rlocation, Runfiles};
use std::process::Command;

#[test]
fn mdbook_rlocationpath() {
    let r = Runfiles::create().unwrap();
    let mdbook = rlocation!(r, env!("MDBOOK_RLOCATIONPATH")).unwrap();
    assert!(
        mdbook.exists(),
        "mdbook is not in the runfiles: {}",
        mdbook.display()
    );

    // The two variables name the same file.
    assert_eq!(
        mdbook.file_name().unwrap().to_str().unwrap(),
        std::path::Path::new(env!("MDBOOK"))
            .file_name()
            .unwrap()
            .to_str()
            .unwrap(),
    );

    let output = Command::new(&mdbook).arg("--version").output().unwrap();
    assert!(
        output.status.success(),
        "mdbook --version failed: {}",
        String::from_utf8_lossy(&output.stderr)
    );
}
