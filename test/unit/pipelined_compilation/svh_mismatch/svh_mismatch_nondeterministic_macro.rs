extern crate proc_macro;
use proc_macro::TokenStream;
use std::collections::HashMap;

/// A derive macro that produces non-deterministic output due to HashMap's
/// random iteration order. Each separate process invocation initializes
/// `HashMap` with a different OS-seeded `RandomState`, so iteration order
/// varies between invocations. This makes the generated constant—and thus
/// the crate's SVH—differ when the macro is run twice (e.g., once for a
/// hollow `.rmeta` and once for a full `.rlib` in pipelined compilation).
#[proc_macro_derive(NondeterministicHash)]
pub fn nondeterministic_hash_derive(_input: TokenStream) -> TokenStream {
    // HashMap::new() uses RandomState, which seeds from OS entropy.
    // Each separate process invocation gets a different seed, so iteration
    // order over the map is non-deterministic across invocations.
    let mut map = HashMap::new();
    map.insert("alpha",   1u64);
    map.insert("beta",    2u64);
    map.insert("gamma",   4u64);
    map.insert("delta",   8u64);
    map.insert("epsilon", 16u64);

    // Position-weighted sum: not commutative, so different iteration orders
    // produce different values. With 5 entries (5! = 120 orderings), the
    // probability of identical output in two separate invocations is ~0.8%.
    let fingerprint: u64 = map
        .iter()
        .enumerate()
        .map(|(pos, (_, &val))| val.wrapping_mul(pos as u64 + 1))
        .fold(0u64, u64::wrapping_add);

    // Exposing this as a public constant makes it part of the crate's
    // exported API, which is included in the SVH computation.
    format!("pub const NONDETERMINISTIC_HASH_FINGERPRINT: u64 = {};", fingerprint)
        .parse()
        .unwrap()
}
