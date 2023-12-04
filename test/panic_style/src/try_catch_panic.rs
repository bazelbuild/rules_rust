//! This binary attempts to catch a panic. Depending on how it is built, this may fail. Exit codes
//! are:
//!   0 if successfully caught
//!   101 if catch_unwind returns Ok somehow
//!   Exited with SIGABRT if the panic is not caught

use std::panic::catch_unwind;

fn main() {
    assert!(catch_unwind(|| panic!("Test panic")).is_err());
}
