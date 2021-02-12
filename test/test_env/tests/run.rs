#[test]
fn run() {
    let path = env!("CARGO_BIN_EXE_hello-world");
    let output = std::process::Command::new(path).output().expect("Failed to run process");
    assert_eq!(&b"Hello world\n"[..], output.stdout.as_slice());

    // Test the `env` attribute of `rust_test` at run time
    assert_eq!(std::env::var("FERRIS_SAYS").unwrap(), "Hello fellow Rustaceans!");
    assert_eq!(std::env::var("HELLO_WORLD_BIN").unwrap(), "test/test_env/hello-world");
}
