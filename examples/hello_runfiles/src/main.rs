extern crate runfiles;

use std::io::prelude::*;
use std::fs::File;


fn main() {
    let runfiles = runfiles::get_runfiles_dir().unwrap();

    let mut f = File::open(runfiles.join("examples/hello_runfiles/data/sample.txt")).unwrap();
    let mut buffer = String::new();

    f.read_to_string(&mut buffer).unwrap();

    println!("{}", buffer);
}