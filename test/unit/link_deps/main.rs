extern "C" {
    fn c_function() -> i32;
}

fn main() {
    unsafe {
        assert_eq!(c_function(), 42);
    }
}
