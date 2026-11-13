//! A binary whose coverage is reached only by a test that spawns it.

fn greeting(name: &str) -> String {
    format!("hello, {name}")
}

fn main() {
    let name = std::env::args()
        .nth(1)
        .unwrap_or_else(|| "world".to_owned());
    println!("{}", greeting(&name));
}
