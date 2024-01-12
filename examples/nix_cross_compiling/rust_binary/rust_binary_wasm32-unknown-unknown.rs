use anyhow::Result;

use rust_library::rust_double_value;

extern "C" {
    fn cc_double_value(value: i32) -> i32;
}

// `wasm32-unknown-unknown` is very barebones, so we don't have access to
// printing or `tokio`, so we can't output anything or use `async main`,
// but we can still call the functions.
fn main() -> Result<()> {
    unsafe { cc_double_value(5) };
    rust_double_value(5);

    Ok(())
}
