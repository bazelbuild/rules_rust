use std::collections::HashMap;
use lazy_static::lazy_static;

// This macro is a usage of the base features of the forked crate - it would work whether we were using upstream or the local fork.
lazy_static! {
    static ref HASHMAP: HashMap<&'static str, &'static str> = {
        let mut m = HashMap::new();
        m.insert("raw", "abc123");
        // This const is only available in our modified local fork, and does not appear upstream.
        m.insert("vendored_by", lazy_static::VENDORED_BY);
        m
    };
}

#[test]
fn get_value() {
    assert_eq!("abc123", *HASHMAP.get("raw").unwrap());
    assert_eq!("rules_rust", *HASHMAP.get("vendored_by").unwrap());
}
