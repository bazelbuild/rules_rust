//! rust_bindgen_library example consumer with stdlib headers

fn get_random_value() -> i64 {
    unsafe { std_headers_bindgen::get_random_value() }
}

fn main() {
    println!("The value is {}!", get_random_value(),);
}

#[cfg(test)]
mod test {
    #[test]
    fn do_the_test() {
        assert_eq!(42, super::get_random_value());
    }
}
