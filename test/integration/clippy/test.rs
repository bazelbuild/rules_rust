use integration::{bazel, workspace_path};

#[test]
fn test_ok_targets() -> Result<(), std::io::Error> {
    for target in &["ok_binary_clippy", "ok_library_clippy", "ok_test_clippy"] {
        assert!(
            bazel("build").arg(target).status()?.success(),
            "failed building target {}",
            target
        );
    }
    Ok(())
}

#[test]
fn test_bad_targets() -> Result<(), std::io::Error> {
    for target in &["bad_binary_clippy", "bad_library_clippy", "bad_test_clippy"] {
        assert!(
            !bazel("build").arg(target).status()?.success(),
            "succeeded building target {}",
            target
        );
    }
    Ok(())
}

#[test]
fn test_capturing_output() -> Result<(), std::io::Error> {
    for target in &["bad_binary_clippy", "bad_library_clippy", "bad_test_clippy"] {
        // When capturing output, clippy errors are treated as warnings and the build
        // should succeed.
        assert!(
            bazel("build")
                .args([
                    "--@rules_rust//:capture_clippy_output=True",
                    "--@rules_rust//:error_format=json",
                ])
                .arg(target)
                .status()?
                .success(),
            "failed building target {}",
            target
        );

        let output = bazel("cquery")
            .args([
                "--@rules_rust//:capture_clippy_output=True",
                "--@rules_rust//:error_format=json",
                "--output=files",
            ])
            .arg(target)
            .output()?;
        assert!(output.status.success());

        let files = std::str::from_utf8(&output.stdout)
            .unwrap()
            .trim_end()
            .split('\n')
            .collect::<Vec<_>>();
        assert_eq!(files.len(), 1);
        assert!(files[0].ends_with(".clippy.out"));

        // Make sure that content was written to the output file.
        let path = workspace_path().join(files[0]);
        assert!(
            path.metadata().is_ok(),
            "output wasn't written to {} building target {}",
            path.display(),
            target
        );
    }
    Ok(())
}

#[test]
fn test_config_file() -> Result<(), std::io::Error> {
    // Test that we can make the ok_library_clippy fail when using an extra config file.
    // Proves that the config file is used and overrides default settings.
    assert!(
        !bazel("build")
            .args(["--@rules_rust//:clippy.toml=//too_many_args:clippy.toml"])
            .arg("ok_library_clippy")
            .status()?
            .success(),
        "succeeded building target ok_library_clippy with too many args",
    );
    Ok(())
}
