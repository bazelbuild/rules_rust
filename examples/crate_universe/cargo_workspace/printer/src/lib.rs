use std::io::BufWriter;

/// Have ferris say a number
pub fn say_number(num: i32) -> String {
    let number = format!("{num}");
    let buf = Vec::new();
    let mut writer = BufWriter::new(buf);
    ferris_says::say(number.as_bytes(), number.len(), &mut writer).unwrap();
    String::from_utf8(writer.into_inner().unwrap()).unwrap()
}

/// Have ferris say a random number
pub fn say_random_number() -> String {
    say_number(rng::random_number())
}

#[cfg(test)]
mod test {
    use super::*;

    #[test]
    fn test_say_number() {
        let said = say_number(3);
        assert!(said.contains(r"    _~^~^~_"));
        assert!(said.contains(r"\) /  o o  \ (/"));
        assert!(said.contains(r"  '_   -   _'"));
        assert!(said.contains(r"  / '-----' \"));
    }

    #[test]
    fn test_say_random_number() {
        let said = say_random_number();
        assert!(said.contains(r"    _~^~^~_"));
        assert!(said.contains(r"\) /  o o  \ (/"));
        assert!(said.contains(r"  '_   -   _'"));
        assert!(said.contains(r"  / '-----' \"));
    }
}
