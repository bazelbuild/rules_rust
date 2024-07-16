fn main() {
    hello_rs::hello();
    unsafe { hello_c::hello() };
}
