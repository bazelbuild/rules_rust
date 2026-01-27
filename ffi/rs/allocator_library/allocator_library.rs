// Workaround for Rust issue https://github.com/rust-lang/rust/issues/73632
// We provide the allocator functions that rustc leaves in rlibs. These are
// normally provided by rustc during the linking phase (since the allocator in
// use can vary), but if rustc doesn't do the final link we have to provide
// these manually. Hopefully we can make progress on the above bug and
// eventually not need this kludge.
//
// Recently rustc started mangling these symbols, so we rewrote them in
// rust.
// https://github.com/rust-lang/rust/pull/127173
//
// This code uses unstable internal rustc features that are only available when
// using a nightly toolchain. Also, it is only compatible with versions
// of rustc that include the symbol mangling, such as nightly/2025-04-08 or
// later.
//
// This has been translated from our c++ version
// rules_rust/ffi/cc/allocator_library/allocator_library.cc.
#![no_std]
#![allow(warnings)]
#![allow(internal_features)]
#![feature(rustc_attrs)]
#![feature(linkage)]

unsafe extern "C" {
    #[rustc_std_internal_symbol]
    fn __rdl_alloc(size: usize, align: usize) -> *mut u8;

    #[rustc_std_internal_symbol]
    fn __rdl_dealloc(ptr: *mut u8, size: usize, align: usize);

    #[rustc_std_internal_symbol]
    fn __rdl_realloc(ptr: *mut u8, old_size: usize, align: usize, new_size: usize) -> *mut u8;

    #[rustc_std_internal_symbol]
    fn __rdl_alloc_zeroed(size: usize, align: usize) -> *mut u8;
}

#[linkage = "weak"]
#[rustc_std_internal_symbol]
fn __rust_alloc(size: usize, align: usize) -> *mut u8 {
    unsafe {
        return __rdl_alloc(size, align);
    }
}

#[linkage = "weak"]
#[rustc_std_internal_symbol]
fn __rust_dealloc(ptr: *mut u8, size: usize, align: usize) {
    unsafe {
        return __rdl_dealloc(ptr, size, align);
    }
}

#[linkage = "weak"]
#[rustc_std_internal_symbol]
fn __rust_realloc(ptr: *mut u8, old_size: usize, align: usize, new_size: usize) -> *mut u8 {
    unsafe {
        return __rdl_realloc(ptr, old_size, align, new_size);
    }
}

#[linkage = "weak"]
#[rustc_std_internal_symbol]
fn __rust_alloc_zeroed(size: usize, align: usize) -> *mut u8 {
    unsafe {
        return __rdl_alloc_zeroed(size, align);
    }
}

#[linkage = "weak"]
#[rustc_std_internal_symbol]
fn __rust_alloc_error_handler(size: usize, align: usize) {
    panic!();
}

// New feature as of https://github.com/rust-lang/rust/pull/88098.
// This symbol is normally emitted by rustc. 0 means OOMs should abort, 1 means OOMs should panic.
#[linkage = "weak"]
#[rustc_std_internal_symbol]
static mut __rust_alloc_error_handler_should_panic: u8 = 1;

// See  https://github.com/rust-lang/rust/pull/143387.
#[linkage = "weak"]
#[rustc_std_internal_symbol]
fn __rust_alloc_error_handler_should_panic_v2() -> u8 {
    return 1;
}

// See https://github.com/rust-lang/rust/issues/73632#issuecomment-1563462239
#[linkage = "weak"]
#[rustc_std_internal_symbol]
static mut __rust_no_alloc_shim_is_unstable: u8 = 0;

// See https://github.com/rust-lang/rust/pull/141061.
#[linkage = "weak"]
#[rustc_std_internal_symbol]
fn __rust_no_alloc_shim_is_unstable_v2() {}
