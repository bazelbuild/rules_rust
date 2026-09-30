pub fn greet(name: &str) -> String {
    format!("hello {name}, {}", lib2::add(1, 2))
}
