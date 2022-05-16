fn get_forty_two() -> i32 {
    42
}

fn main() {
    println!("{}", get_forty_two());
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn test_forty_two() {
        assert_eq!(42, get_forty_two());
    }
}
