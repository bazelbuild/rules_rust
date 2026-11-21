//! The check runs in the build script; this test only consumes its output.

const PROBE_OBJECT: &[u8] = include_bytes!(concat!(env!("OUT_DIR"), "/probe.o"));

#[test]
fn probe_object_was_built() {
    assert_ne!(PROBE_OBJECT.len(), 0);
}
