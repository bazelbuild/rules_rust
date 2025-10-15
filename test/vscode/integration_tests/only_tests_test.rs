#[cfg(test)]
mod tests {
    use std::env;
    use std::fs;
    use std::path::PathBuf;

    #[test]
    fn test_only_tests() {
        let launch_json_path = PathBuf::from(env::var("LAUNCH_JSON").unwrap());
        let content = fs::read_to_string(&launch_json_path)
            .unwrap_or_else(|_| panic!("couldn't open {:?}", &launch_json_path));

        // Verify basic JSON structure
        assert!(content.contains(r#""version": "0.2.0""#));
        assert!(content.contains(r#""configurations":"#));

        // Check that we have configurations for both tests
        assert!(
            content.contains(r#""name": "Debug //only_tests_test:mylib_test""#),
            "Should have configuration for //only_tests_test:mylib_test"
        );
        assert!(
            content.contains(r#""name": "Debug //only_tests_test:test""#),
            "Should have configuration for //only_tests_test:test"
        );

        // All configurations should be lldb type
        let lldb_count = content.matches(r#""type": "lldb""#).count();
        assert_eq!(lldb_count, 2, "Should have 2 lldb configurations");

        // Verify test environment variables are present
        // Test configurations should have BAZEL_TEST env var
        let bazel_test_count = content.matches("BAZEL_TEST").count();
        assert_eq!(
            bazel_test_count, 2,
            "Should have BAZEL_TEST env var in 2 test configurations"
        );

        // Should have TEST_TARGET env vars
        assert!(
            content.contains("TEST_TARGET"),
            "Test configurations should have TEST_TARGET env var"
        );
    }
}
