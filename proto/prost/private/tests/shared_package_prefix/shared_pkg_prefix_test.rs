use shared_pkg_prefix_proto::pkg::foo::AMessage;
use shared_pkg_prefix_proto::pkg::foo::BMessage;
use shared_pkg_prefix_proto::pkg::CMessage;

#[test]
fn test_packages() {
    let pkg_b = BMessage {
        name: "pkg_b".to_string(),
    };
    let pkg_c = CMessage {
        name: "pkg_c".to_string(),
    };
    let pkg_a = AMessage {
        name: "pkg_a".to_string(),
        c: Some(pkg_c.clone()),
    };

    assert_eq!(pkg_a.name, "pkg_a");
    assert_eq!(pkg_a.c.unwrap().name, "pkg_c");
    assert_eq!(pkg_b.name, "pkg_b");
    assert_eq!(pkg_c.name, "pkg_c");
}
