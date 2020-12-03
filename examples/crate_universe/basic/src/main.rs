use lazy_static::lazy_static;
use std::collections::HashMap;

lazy_static! {
    static ref HASHMAP: HashMap<&'static str, &'static str> = {
        let mut m = HashMap::new();
        m.insert("Gibson", "Fahnestock");
        m.insert("Romain", "Chossart");
        m.insert("Daniel", "Wagner-Hall");
        m
    };
}

fn main() {
    assert_eq!(HASHMAP["Daniel"], "Wagner-Hall");
    println!("It worked!");
}
