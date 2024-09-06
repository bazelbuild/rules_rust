# Rules

- [defs](defs.md): standard rust rules for building and testing libraries and binaries.
- [rust_doc](rust_doc.md): rules for generating and testing rust documentation.
- [rust_clippy](rust_clippy.md): rules for running [clippy](https://github.com/rust-lang/rust-clippy#readme).
- [rust_fmt](rust_fmt.md): rules for running [rustfmt](https://github.com/rust-lang/rustfmt#readme).
- [rust_proto](rust_proto.md): rules for generating [protobuf](https://developers.google.com/protocol-buffers) and [gRPC](https://grpc.io) stubs.
- [rust_bindgen](rust_bindgen.md): rules for generating C++ bindings.
- [rust_wasm_bindgen](rust_wasm_bindgen.md): rules for generating [WebAssembly](https://www.rust-lang.org/what/wasm) bindings.
- [cargo](cargo.md): Rules dedicated to Cargo compatibility. ie: [`build.rs` scripts](https://doc.rust-lang.org/cargo/reference/build-scripts.html).
- [crate_universe (bzlmod)](crate_universe_bzlmod.md): Rules for generating Bazel targets for external crate dependencies when using bzlmod.
- [crate_universe (WORKSPACE)](crate_universe.md): Rules for generating Bazel targets for external crate dependencies when using WORKSPACE files.

You can also browse the [full API in one page](flatten.md).

## Experimental rules

- [rust_analyzer](rust_analyzer.md): rules for generating `rust-project.json` files for [rust-analyzer](https://rust-analyzer.github.io/)
