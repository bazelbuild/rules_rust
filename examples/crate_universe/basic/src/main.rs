use lazy_static::lazy_static;
use std::collections::HashMap;
use value_bag::ValueBag;

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

    let bag = ValueBag::capture_display(&42);
    let num = bag.to_u64().unwrap();
    println!("hello {}", num);
}
