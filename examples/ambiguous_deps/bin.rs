use std::os::raw::c_int;

extern "C" {
    pub fn cx() -> c_int;
    pub fn cy() -> c_int;
}

fn main() {
    println!("hi {} {}", unsafe { cx() }, unsafe { cy() });
}
