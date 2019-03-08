#[allow(dead_code)]
fn multiply(val: u32) -> u32 {
    val * 100
}

#[cfg(test)]
mod extra;

#[cfg(test)]
mod tests {
    use super::{multiply, extra};
    use dep::example_test_dep_fn;

    #[test]
    fn test() {
        assert_eq!(extra::extra_test_fn(), multiply(example_test_dep_fn()));
    }
}
