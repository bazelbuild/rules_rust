// `app` only needs tokio's sync primitives, which compile fine on
// wasm32-unknown-unknown.
pub fn make_mutex() -> tokio::sync::Mutex<()> {
    tokio::sync::Mutex::new(())
}
