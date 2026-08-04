// Dummy Rust crate used to carry DepInfo from `producer_build_rs`.
// `cargo_build_script` cannot depend directly on another build script target,
// so the consumer build script uses this library in `link_deps` instead.
pub fn marker() -> u8 {
    1
}
