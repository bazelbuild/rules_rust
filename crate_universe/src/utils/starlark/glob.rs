use serde::{Deserialize, Serialize};

#[derive(Debug, Default, PartialEq, Eq, PartialOrd, Ord, Deserialize, Serialize, Clone)]
pub struct Glob {
    pub include: Vec<String>,
    pub exclude: Vec<String>,
}

impl Glob {
    pub fn new_rust_srcs() -> Self {
        Self {
            include: vec!["**/*.rs".to_owned()],
            ..Default::default()
        }
    }
}
