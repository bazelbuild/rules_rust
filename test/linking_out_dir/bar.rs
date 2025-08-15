extern "C" {
    fn foo() -> i32;
}

pub fn bar() -> i32 {
    unsafe { foo() }
}
