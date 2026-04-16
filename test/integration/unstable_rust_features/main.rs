#![feature(core_intrinsics)]
#![allow(internal_features)]
use std::intrinsics;

fn main() {
    intrinsics::abort();
}
