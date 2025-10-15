#[cfg(test)]
mod tests {
    use std::env;
    use std::fs;
    use std::path::PathBuf;

    #[test]
    fn test_only_binaries() {
        let launch_json_path = PathBuf::from(env::var("LAUNCH_JSON").unwrap());
        let content = fs::read_to_string(&launch_json_path)
            .unwrap_or_else(|_| panic!("couldn't open {:?}", &launch_json_path));

        // Verify basic JSON structure
        assert!(content.contains(r#""version": "0.2.0""#));
        assert!(content.contains(r#""configurations":"#));

        // Check that we have configurations for both binaries
        assert!(
            content.contains(r#""name": "Debug //only_binaries_test:binary1""#),
            "Should have configuration for //only_binaries_test:binary1"
        );
        assert!(
            content.contains(r#""name": "Debug //only_binaries_test:binary2""#),
            "Should have configuration for //only_binaries_test:binary2"
        );

        // All configurations should be lldb type
        let lldb_count = content.matches(r#""type": "lldb""#).count();
        assert_eq!(lldb_count, 2, "Should have 2 lldb configurations");

        // Verify no test-related configurations exist
        // (test configurations would have BAZEL_TEST env var)
        assert!(
            !content.contains("BAZEL_TEST"),
            "Should not have test environment variables for binaries"
        );
    }
}
