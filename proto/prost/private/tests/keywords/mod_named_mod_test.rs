//! Tests module names that are keywords.

use mod_named_mod_proto::r#mod::A;

#[test]
fn test_nested_messages() {
    let a = A {
        name: "a".to_string(),
    };

    assert_eq!(a.name, "a");
}
