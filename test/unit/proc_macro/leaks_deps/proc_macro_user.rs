use proc_macro_definition::make_forty_two;

#[test]
fn test_answer_macro() {
    assert_eq!(make_forty_two!(), 42);
}
