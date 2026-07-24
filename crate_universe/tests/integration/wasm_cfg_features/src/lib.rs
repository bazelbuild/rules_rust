// Tiny driver that pulls in tokio so the top-level `build_for_wasm32` target
// forces tokio (and its transitive crate_universe-resolved deps) to be
// compiled for wasm32-unknown-unknown.
//
// Without the `tokio` annotation in //:MODULE.bazel, tokio's generated
// BUILD.bazel lists `mio` / `socket2` as unconditional deps (unioned in from
// the `server` member), and this build fails because neither compiles for
// wasm32-unknown-unknown.
pub fn make_mutex() -> tokio::sync::Mutex<()> {
    tokio::sync::Mutex::new(())
}
