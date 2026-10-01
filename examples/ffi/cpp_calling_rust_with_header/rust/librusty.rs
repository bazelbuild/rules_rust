//! A simple hello world example that can be called from C

#[no_mangle]
pub fn print_c_hello_rust() {
    println!("Hello Rust!");
}
