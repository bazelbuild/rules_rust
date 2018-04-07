extern crate fibonacci;

pub fn rusty_greeting() {
    println!("The 10th fibonacci number is {}.", fibonacci::fibonacci(10));
    unsafe { greeter_greet(); }
}

extern "C" {
    fn greeter_greet();
}
