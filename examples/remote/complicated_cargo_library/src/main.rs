extern crate libloading;
extern crate regex;
extern crate specs;

#[allow(unused_imports)]
use regex::Match;

fn main() {
  println!("hello world");

  // Make sure libloading is not optimized out
  unsafe {
    let _lib = libloading::Library::new("/path/to/liblibrary.so");
  }
}
