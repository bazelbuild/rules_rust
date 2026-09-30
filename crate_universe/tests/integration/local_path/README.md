# crate_universe_local_path

This example does some slightly weird things. It tests that we can patch upstream crates.

The local crate in this dir depends on lazy_static, and assumes it can access a symbol named VENDORED_BY.

VENDORED_BY does not exist in the real lazy_static crate.

We have checked in a copy of lazy_static. On CI, we make a copy of our checked in copy of lazy_static adding the VENDORED_BY symbol, and update our Cargo.toml file to enable the `[patch]`.

We then run a test which tries to use the VENDORED_BY symbol. If we weren't successfully patching lazy_static, our test would fail to compile. If we successfully use the patch, the test compiles and everything's fine.
