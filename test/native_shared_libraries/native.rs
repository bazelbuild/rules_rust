extern "C" {
    fn native_value() -> i32;
    fn odd_value() -> i32;
    fn unversioned_value() -> i32;
    fn versioned_value() -> i32;
}

pub fn linked_value() -> i32 {
    unsafe { native_value() + odd_value() + unversioned_value() + versioned_value() }
}
