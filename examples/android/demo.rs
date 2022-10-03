#[no_mangle]
pub extern "C" fn android_link_hack() {}

#[no_mangle]
pub extern fn print_something_from_rust() {
    println!("Ferris says hello!");
}

#[no_mangle]
pub extern fn get_a_value_from_rust() -> i32 {
    42
}

#[no_mangle]
pub extern "system" fn Java_com_example_androidapp_JniShim_getValue() -> i32 {
    get_a_value_from_rust()
}
