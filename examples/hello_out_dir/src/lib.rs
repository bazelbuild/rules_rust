#[allow(dead_code)]
struct Demo {
    secret_number: i64,
}

impl Demo {
    #[allow(dead_code)]
    pub fn new() -> Demo {
        Demo {
            secret_number: include!(concat!(env!("OUT_DIR"), "/body.rs")),
        }
    }
}

#[cfg(test)]
mod test {
    #[test]
    fn test_out_dir_contents() {
        let secret_number = include!(concat!(env!("OUT_DIR"), "/body.rs"));
        assert_eq!(secret_number, 8888);
    }
}
