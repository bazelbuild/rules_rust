#[no_mangle]
pub extern fn print_something_from_rust() {
    println!("Ferris says hello!");
}

#[no_mangle]
pub extern fn get_a_value_from_rust() -> i32 {
    42
}
