#[test]
fn reads_from_patched_getrandom() {
    let mut bytes = [0; 1];
    getrandom::getrandom(&mut bytes).unwrap();
}
