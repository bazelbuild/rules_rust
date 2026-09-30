//! A native coverage smoke test for the collector's execution transition.

#![warn(rust_2018_idioms)]

#[test]
fn addition_is_instrumented() {
    assert_eq!(std::hint::black_box(1) + 1, 2);
}
