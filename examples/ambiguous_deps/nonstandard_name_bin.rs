use std::os::raw::c_int;

extern "C" {
    pub fn func() -> c_int;
}

fn main() {
    println!("hi {}", unsafe { func() });
}
