fn main() {
    println!("Version: {}", env!("CARGO_PKG_VERSION"));
    println!("Major: {}", env!("CARGO_PKG_VERSION_MAJOR"));
    println!("Minor: {}", env!("CARGO_PKG_VERSION_MINOR"));
    println!("Patch: {}", env!("CARGO_PKG_VERSION_PATCH"));
    println!("Pre: {}", env!("CARGO_PKG_VERSION_PRE"));
}
