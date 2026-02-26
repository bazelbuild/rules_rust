use nondeterministic_macro::NondeterministicHash;

/// A struct whose derivation runs the non-deterministic proc macro.
/// The macro generates a public constant whose value depends on HashMap
/// iteration order, so this crate's SVH varies between separate rustc
/// invocations.
#[derive(NondeterministicHash)]
pub struct Widget;
