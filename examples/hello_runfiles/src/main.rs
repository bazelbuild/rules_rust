extern crate runfiles;

use std::io::prelude::*;
use std::fs::File;

use runfiles::Runfiles;

fn main() {
    let r = Runfiles::create().unwrap();

    let mut f = File::open(r.rlocation("examples/hello_runfiles/data/sample.txt")).unwrap();

    let mut buffer = String::new();
    f.read_to_string(&mut buffer).unwrap();

    println!("{}", buffer);
}
