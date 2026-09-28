fn main() {
    let path = std::env::args_os().nth(1).expect("runtime file argument");
    print!(
        "{}",
        std::fs::read_to_string(path).expect("read declared runtime file")
    );
}
