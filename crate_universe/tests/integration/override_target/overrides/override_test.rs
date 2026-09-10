//! A dropped `override_target_*` annotation leaves the upstream target in
//! place rather than failing, so this needs a positive signal: `overridden!`
//! does not exist in the real `paste`.

#[test]
fn proc_macro_is_overridden() {
    assert!(paste::overridden!());
}
