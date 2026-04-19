#[path = "rustc_test_util.rs"]
mod rustc_test_util;

#[cfg(test)]
mod test {
    use super::rustc_test_util::fake_rustc;

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
}
