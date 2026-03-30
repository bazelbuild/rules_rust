extern "C" {
    fn native_add(a: i32, b: i32) -> i32;
}

#[test]
fn cc_lib_links_successfully() {
    assert_eq!(unsafe { native_add(2, 3) }, 5);
}

#[test]
fn cc_lib_handles_negative_values() {
    assert_eq!(unsafe { native_add(-10, 7) }, -3);
}
