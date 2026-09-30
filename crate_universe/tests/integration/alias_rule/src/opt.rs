#[test]
fn out_dir() {
    assert!(test_data_passing_crate::get_out_dir().contains("-opt"));
}

#[test]
fn opt_level() {
    assert_eq!(test_data_passing_crate::get_opt_level(), "3");
}
