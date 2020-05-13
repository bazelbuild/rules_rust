#[allow(dead_code)]
struct Demo {
    secret: String,
}

impl Demo {
    #[allow(dead_code)]
    pub fn new() -> Demo {
        Demo {
            secret: env!("SECRET1").to_string(),
        }
    }
}

#[cfg(test)]
mod test {
    #[test]
    fn test_env_contents() {
        assert_eq!(env!("SECRET1"), "VALUE1");
        assert_eq!(env!("SECRET2"), "VALUE2");
    }
    #[test]
    fn test_cfg_contents() {
        assert!(cfg!(foo));
        assert!(cfg!(bar));
    }
}
