
use hello_cargo_manifest_dir::get_included_str;

#[test]
fn test_lib_with_include() {
    assert_eq!(get_included_str(), "I love veggies!\n")
}
