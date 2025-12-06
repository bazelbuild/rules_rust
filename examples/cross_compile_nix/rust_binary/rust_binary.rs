use anyhow::Result;

use rust_library::rust_double_value;

extern "C" { fn cc_double_value(value: i32) -> i32; }

#[tokio::main]
async fn main() -> Result<()> {
    println!("Hello World!");
    println!("CC: {}", unsafe{ cc_double_value(5) });
    println!("Rust: {}", rust_double_value(5));

    Ok(())
}
