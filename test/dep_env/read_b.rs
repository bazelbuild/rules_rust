use std::env::var;

fn main() {
    assert_eq!(var("DEP_Y_B").unwrap(), "b_value");
}
