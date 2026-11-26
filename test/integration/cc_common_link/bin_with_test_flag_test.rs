#[test]
fn bin_with_test_flag_runs() {
    let status = std::process::Command::new(env!("CARGO_BIN_EXE_bin_with_test_flag"))
        .status()
        .expect("failed to execute bin_with_test_flag");
    assert!(status.success(), "bin_with_test_flag exited with {status}");
}
