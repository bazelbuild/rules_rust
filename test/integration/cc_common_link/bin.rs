use std::os::raw::c_int;

extern "C" {
    pub fn cclinkstampdep() -> c_int;
}

fn main() {
    println!("bin rdep: {}", rdep::rdep());
    println!("bin deep_dep: {}", deep_dep::deep_dep());
    println!("bin nesting_dep: {}", nesting_dep::nesting_dep());
    println!("cclinkstampdep: {}", unsafe { cclinkstampdep() });
}
