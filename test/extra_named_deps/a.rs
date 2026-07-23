pub fn hello_from_a() {
    b::hello_from_b();
    renamed_c::hello_from_c();
    println!("Hello from A!");
}
