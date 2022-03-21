use proc_macro_definition::make_double_forty_two;
use proc_macro_dep::forty_two;

make_double_forty_two!();

#[test]
fn test_answer_macro() {
    assert_eq!(double_forty_two(), forty_two() + forty_two());
}

