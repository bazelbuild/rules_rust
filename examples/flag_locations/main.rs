#[test]
fn test() {
    // we should able to read rustc args from a generated file
    if cfg!(test_flag) {
        return;
    }

    unreachable!();
}
