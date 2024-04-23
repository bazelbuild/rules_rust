#[cfg(test)]
mod test {
    use std::path::PathBuf;
    use std::process::Command;
    use std::str;

    use runfiles::Runfiles;

    /// fake_rustc runs the fake_rustc binary under process_wrapper with the specified
    /// process wrapper arguments. No arguments are passed to fake_rustc itself.
    ///
    fn fake_rustc(
        process_wrapper_args: &[&'static str],
        fake_rustc_args: &[&'static str],
        should_succeed: bool,
    ) -> String {
        let r = Runfiles::create().unwrap();
        let fake_rustc = runfiles::rlocation!(
            r,
            [
                "rules_rust",
                "test",
                "process_wrapper",
                if cfg!(unix) {
                    "fake_rustc"
                } else {
                    "fake_rustc.exe"
                },
            ]
            .iter()
            .collect::<PathBuf>()
        );

        let process_wrapper = runfiles::rlocation!(
            r,
            [
                "rules_rust",
                "util",
                "process_wrapper",
                if cfg!(unix) {
                    "process_wrapper"
                } else {
                    "process_wrapper.exe"
                },
            ]
            .iter()
            .collect::<PathBuf>()
        );

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

    #[test]
    fn test_rustc_quit_on_rmeta_quits() {
        let out_content = fake_rustc(
            &[
                "--rustc-quit-on-rmeta",
                "true",
                "--rustc-output-format",
                "rendered",
            ],
            &[],
            true,
        );
        assert!(
            !out_content.contains("should not be in output"),
            "output should not contain 'should not be in output' but did",
        );
    }

    #[test]
    fn test_rustc_quit_on_rmeta_output_json() {
        let json_content = fake_rustc(
            &[
                "--rustc-quit-on-rmeta",
                "true",
                "--rustc-output-format",
                "json",
            ],
            &[],
            true,
        );
        assert_eq!(
            json_content,
            concat!(r#"{"rendered": "should be\nin output"}"#, "\n")
        );
    }

    #[test]
    fn test_rustc_quit_on_rmeta_output_rendered() {
        let rendered_content = fake_rustc(
            &[
                "--rustc-quit-on-rmeta",
                "true",
                "--rustc-output-format",
                "rendered",
            ],
            &[],
            true,
        );
        assert_eq!(rendered_content, "should be\nin output");
    }

    #[test]
    fn test_rustc_panic() {
        let rendered_content = fake_rustc(&["--rustc-output-format", "json"], &["error"], false);
        assert_eq!(
            rendered_content,
            r#"{"rendered": "should be\nin output"}
ERROR!
this should all
appear in output.
Error: ProcessWrapperError("failed to process stderr: error parsing rustc output as json")
"#
        );
    }
}
