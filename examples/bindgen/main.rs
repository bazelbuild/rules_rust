fn main() {
    println!("The value is {}!", simple_bindgen::SIMPLE_VALUE);
}

#[cfg(test)]
mod test {
    #[test]
    fn do_the_test() {
        assert_eq!(42, simple_bindgen::SIMPLE_VALUE);
    }
}
