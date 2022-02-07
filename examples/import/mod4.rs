import::import! {
        "//import/my_third_party_dir:third_party_lib";
}

pub fn greet() -> String {
        format!("Hello {} from third-party!", third_party_lib::world())
}

#[cfg(test)]
mod test {
    #[test]
    fn test_greet() {
        assert_eq!(super::greet(), "Hello world from third-party!");
    }
}
