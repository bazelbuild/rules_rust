use anyhow::Result;

use rust_library::rust_double_value;

extern "C" {
    fn cc_double_value(value: i32) -> i32;
}

// `tokio` currently blocked on needing the `wasm32-wasi` version of `tokio`
// to `select()` over different features.

// `wasm32-wasi` has limited support for `tokio` presently, so we can use the
// example but only with the single threaded executor.
// #[tokio::main(flavor = "current_thread")]
// async fn main() -> Result<()> {
fn main() -> Result<()> {
    println!("Hello World!");
    println!("CC: {}", unsafe { cc_double_value(5) });
    println!("Rust: {}", rust_double_value(5));

    Ok(())
}
