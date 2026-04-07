#[used]
static ARTIFACT_SENTINEL: [u8; 17] = *b"ARTIFACT_SENTINEL";

#[test]
fn artifact_test_binary_contains_sentinel() {
    assert_eq!(ARTIFACT_SENTINEL[0], b'A');
}
