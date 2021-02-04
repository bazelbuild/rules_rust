#[test]
fn run() {
    let path = env!("CARGO_BIN_EXE_hello-world");
    let output = std::process::Command::new(path).output().expect("Failed to run process");
    assert_eq!(&b"Hello world\n"[..], output.stdout.as_slice());

    // Test the `env` attribute of `rust_test`
    assert_eq!(env!("FERRIS_SAYS"), "Hello fellow Rustaceans!");
    assert_eq!(env!("HELLO_WORLD_BIN"), "test/test_env/hello-world");
}
