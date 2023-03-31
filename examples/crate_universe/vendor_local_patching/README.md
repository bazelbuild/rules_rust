# Local vendoring with patches

This demonstrates patching out crates when using the "local" vendor mode. The
example crate just depends on `rand`, and we patch out two of the transitive deps:

- `getrandom` is "forked". In `forked_getrandom/BUILD.bazel` the neccesary
filegroups are exposed so that the generated BUILD file at
`vendor/getrandom-0.2.8/BUILD.bazel` can use them.
- `wasi` is "empty-patched" because it's not actually used in our build. When
using local vendoring, `crate_universe` runs `cargo vendor` which isn't aware
of which targets you're using. The `wasi` crate is only conditionally depended
on by `rand` when you're actually targeting `wasi` (which we're not), so we
patch it out with a stub crate to avoid downloading and vendoring the source
of the that crate. This can be helpful to avoid vendoring large codebases or
libraries with conflicting licenses that aren't used in your build graph.

The result of our `getrandom` patching is that our binary is always given the
same value for seeding its rng. Therefore we can test that `rand::random`
returns the same value to check that the patching behavior is working correctly.
