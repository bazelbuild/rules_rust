use std::fs::File;
use std::io::prelude::*;

use runfiles::Runfiles;

fn main() {
    let r = Runfiles::create().unwrap();

    let mut f = File::open(r.rlocation("examples/hello_runfiles/hello_runfiles.rs")).unwrap();

    let mut buffer = String::new();
    f.read_to_string(&mut buffer).unwrap();

    println!("This program's source is {} characters long.", buffer.len());
}
