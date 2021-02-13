# non_cratesio_remote


## Manual steps run (that you would use to replicate this)

1. Run `cargo install cargo-raze`
2. Generate a Cargo.toml with desired dependencies into cargo/Cargo.toml
3. Add a [package.metadata.raze] section with your desired options (see cargo-raze `settings::CargoToml` for
   the exact details)
4. Run `cargo vendor --versioned-dirs` from `cargo/`
5. Run `cargo raze` from `cargo/`

At this point you will have a dependency specification that Bazel can understand. You will also have starter BUILD files that referene the specified dependencies and generate rust_library rules.

To expose those dependencies, `alias` entries are created for the explicit Cargo dependencies. It is important to only expose explicit dependencies for the sake of hygiene.
