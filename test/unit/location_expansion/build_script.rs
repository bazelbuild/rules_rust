fn main() {
    let path = std::env::var("MY_DATA").expect("MY_DATA env var must be set");
    assert!(
        std::path::Path::new(&path).exists(),
        "MY_DATA path does not exist: {}",
        path
    );
}
