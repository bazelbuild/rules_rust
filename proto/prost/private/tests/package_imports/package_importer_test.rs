//! Tests package importing with the same package name.

use package_import_proto::package::import::A;
use package_importer_proto::package::import::B;

#[test]
fn test_package_importer() {
    let b = B {
        a: Some(A {
            name: "a".to_string(),
        }),
    };

    assert_eq!(b.a.as_ref().unwrap().name, "a");
}
