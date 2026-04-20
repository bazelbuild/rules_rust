#[path = "rustc_test_util.rs"]
mod rustc_test_util;

#[cfg(test)]
mod test {
    use super::rustc_test_util::fake_rustc;

    #[test]
    fn test_rustc_output_format_rendered() {
        let out_content = fake_rustc(&["--rustc-output-format", "rendered"], &[], true);
        assert!(
            out_content.contains("should be\nin output"),
            "output should contain the first rendered message",
        );
        assert!(
            out_content.contains("should not be in output"),
            "output should contain the second rendered message",
        );
        assert!(
            !out_content.contains(r#""rendered""#),
            "rendered mode should not print raw json",
        );
    }

    #[test]
    fn test_rustc_output_format_json() {
        let json_content = fake_rustc(&["--rustc-output-format", "json"], &[], true);
        assert_eq!(
            json_content,
            concat!(
                r#"{"rendered": "should be\nin output"}"#,
                "\n",
                r#"{"rendered": "should not be in output"}"#,
                "\n"
            )
        );
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
