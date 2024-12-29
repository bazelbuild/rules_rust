#[no_mangle]
pub extern "C" fn my_favorite_number() -> i32 {
    4
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_my_favorite_number() {
        assert_eq!(4, my_favorite_number());
    }
}
