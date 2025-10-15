#[cfg(test)]
mod tests {
    use std::env;
    use std::fs;
    use std::path::PathBuf;

    #[test]
    fn test_binaries_and_tests() {
        let launch_json_path = PathBuf::from(env::var("LAUNCH_JSON").unwrap());
        let content = fs::read_to_string(&launch_json_path)
            .unwrap_or_else(|_| panic!("couldn't open {:?}", &launch_json_path));

        // Verify basic JSON structure
        assert!(content.contains(r#""version": "0.2.0""#));
        assert!(content.contains(r#""configurations":"#));

        // Check binary configuration
        assert!(
            content.contains(r#""name": "Debug //binaries_and_tests_test:main_binary""#),
            "Should have configuration for //binaries_and_tests_test:main_binary"
        );

        // Check test configurations
        assert!(
            content.contains(r#""name": "Debug //binaries_and_tests_test:mylib_test""#),
            "Should have configuration for //binaries_and_tests_test:mylib_test"
        );
        assert!(
            content.contains(r#""name": "Debug //binaries_and_tests_test:test""#),
            "Should have configuration for //binaries_and_tests_test:test"
        );

        // All configurations should be lldb type
        let lldb_count = content.matches(r#""type": "lldb""#).count();
        assert_eq!(
            lldb_count, 3,
            "Should have 3 lldb configurations (1 binary + 2 tests)"
        );

        // Verify test environment variables are present for tests
        let bazel_test_count = content.matches("BAZEL_TEST").count();
        assert_eq!(
            bazel_test_count, 2,
            "Should have BAZEL_TEST env var in 2 test configurations (not in binary)"
        );

        // Count configurations to ensure we have the right split
        // We can count by looking for unique target names
        assert!(
            content.contains("//binaries_and_tests_test:main_binary"),
            "Should have binary target"
        );
        assert!(
            content.contains("//binaries_and_tests_test:mylib_test"),
            "Should have first test target"
        );
        assert!(
            content.contains("//binaries_and_tests_test:test"),
            "Should have second test target"
        );
    }
}
