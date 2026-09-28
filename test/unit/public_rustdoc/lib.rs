/// Returns the dependency's value.
///
/// ```
/// assert_eq!(documented::value(), 2);
/// ```
#[identity::identity]
pub fn value() -> u8 {
    dependency::value()
}
