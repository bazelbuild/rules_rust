use compile_data::COMPILE_DATA;

#[test]
fn test_compile_data_contents() {
    // This would confirm that the constant that's compiled into the `compile_data`
    // crate matches the data loaded at compile time here. Where `compile_data.txt`
    // would have only been provided by the `compile_data` crate itself.
    assert_eq!(COMPILE_DATA, include_str!("compile_data.txt"));
}
