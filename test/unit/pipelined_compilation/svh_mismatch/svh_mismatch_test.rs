/// Demonstrates SVH (Strict Version Hash) mismatch with pipelined compilation.
///
/// Without pipelining this test always builds and passes: each library is
/// compiled exactly once, so the SVH embedded in every `.rmeta` and `.rlib`
/// is identical.
///
/// With `//rust/settings:pipelined_compilation=true` rules_rust compiles
/// `svh_lib` **twice** in separate rustc processes — once to emit the hollow
/// `.rmeta` (metadata only), once to emit the full `.rlib`. Because
/// `nondeterministic_macro` uses `HashMap` with OS-seeded randomness, the two
/// rustc invocations typically produce different token streams and therefore
/// different SVH values. `svh_consumer` is compiled against the hollow `.rmeta`
/// and records SVH_1 in its own metadata; when rustc later tries to link the
/// test binary against the full `.rlib` (which carries SVH_2), it detects the
/// mismatch and fails with E0460. The test therefore **fails to build** most of
/// the time (~99.2% probability) when pipelining is enabled.
///
/// The `flaky = True` attribute on this target acknowledges that the mismatch
/// is non-deterministic: on rare occasions (~0.8%) both rustc invocations
/// happen to produce the same HashMap iteration order, the SVHs agree, and the
/// build succeeds.
use svh_consumer::Widget;

#[test]
fn svh_consistent() {
    // If we reach here the SVH was consistent (no pipelining, or a lucky run).
    let _: Widget = Widget;
}
