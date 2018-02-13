fn main() {
    println!(
        "The secret number was {}",
        include!(concat!(env!("OUT_DIR"), "/body.rs"))
    );
}
