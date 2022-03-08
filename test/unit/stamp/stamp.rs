//! A small test library for ensuring `--stamp` data is correctly set at compile time.

pub fn build_timestamp() -> &'static str {
    env!("BUILD_TIMESTAMP")
}

pub fn build_user() -> &'static str {
    env!("BUILD_USER")
}

#[cfg(test)]
mod test {
    use super::*;

    #[cfg(feature = "force_stamp")]
    #[test]
    fn stamp_resolved() {
        assert!(!build_timestamp().contains("BUILD_TIMESTAMP"));
        assert!(build_timestamp().chars().all(char::is_numeric));
    }

    #[cfg(feature = "skip_stamp")]
    #[test]
    fn stamp_not_resolved() {
        assert!(build_timestamp().contains("BUILD_TIMESTAMP"));
    }

    #[test]
    fn lib_volatile_stamp_matches() {
        assert_eq!(build_timestamp(), env!("BUILD_TIMESTAMP"));
    }

    #[test]
    fn lib_stable_stamp_not_stamped() {
        assert_eq!(build_user(), "{BUILD_USER}");
    }
}
