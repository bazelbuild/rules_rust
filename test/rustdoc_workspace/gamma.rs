//! The `gamma` binary, the top of the test dependency graph.

fn main() {
    println!("{}", beta::loud_greeting("world").text);
}
