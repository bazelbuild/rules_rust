#[cfg(test)]
mod test {
    use std::path::PathBuf;
    use std::process::Command;
    use std::str;

    use runfiles::Runfiles;

    /// fake_rustc runs the fake_rustc binary under process_wrapper with the specified
    /// process wrapper arguments. No arguments are passed to fake_rustc itself.
    ///
    fn fake_rustc(process_wrapper_args: &[&'static str]) -> String {
        let r = Runfiles::create().unwrap();
        let fake_rustc = r.rlocation(
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
            .collect::<PathBuf>(),
        );

        let process_wrapper = r.rlocation(
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
            .collect::<PathBuf>(),
        );

        let output = Command::new(process_wrapper)
            .args(process_wrapper_args)
            .arg("--")
            .arg(fake_rustc)
            .output()
            .unwrap();

        assert!(
            output.status.success(),
            "unable to run process_wrapper: {} {}",
            str::from_utf8(&output.stdout).unwrap(),
            str::from_utf8(&output.stderr).unwrap(),
        );

        String::from_utf8(output.stderr).unwrap()
    }

    #[test]
    fn test_rustc_quit_on_rmeta_quits() {
        let out_content = fake_rustc(&[
            "--rustc-quit-on-rmeta",
            "true",
            "--rustc-output-format",
            "rendered",
        ]);
        assert!(
            !out_content.contains("should not be in output"),
            "output should not contain 'should not be in output' but did",
        );
    }

    #[test]
    fn test_rustc_quit_on_rmeta_output_json() {
        let json_content = fake_rustc(&[
            "--rustc-quit-on-rmeta",
            "true",
            "--rustc-output-format",
            "json",
        ]);
        assert_eq!(
            json_content,
            concat!(r#"{"rendered": "should be\nin output"}"#, "\n")
        );
    }

    #[test]
    fn test_rustc_quit_on_rmeta_output_rendered() {
        let rendered_content = fake_rustc(&[
            "--rustc-quit-on-rmeta",
            "true",
            "--rustc-output-format",
            "rendered",
        ]);
        assert_eq!(rendered_content, "should be\nin output");
    }
}
