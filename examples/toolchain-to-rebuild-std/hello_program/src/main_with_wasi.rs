// Copied from https://doc.rust-lang.org/std/os/wasi/index.html#examples

use std::fs::File;
use std::os::wasi::prelude::*;

fn main() -> std::io::Result<()> {
    let f = File::create("foo.txt")?;
    let fd = f.as_raw_fd();

    // use fd with native WASI bindings

    Ok(())
}