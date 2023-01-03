use std::collections::BTreeSet;

use serde::ser::{SerializeStruct, SerializeTupleStruct, Serializer};
use serde::{Deserialize, Serialize};

#[derive(Debug, Default, PartialEq, Eq, PartialOrd, Ord, Deserialize, Clone)]
pub struct Glob {
    pub include: BTreeSet<String>,
    pub exclude: BTreeSet<String>,
}

impl Glob {
    pub fn new_rust_srcs() -> Self {
        Self {
            include: BTreeSet::from(["**/*.rs".to_owned()]),
            exclude: BTreeSet::new(),
        }
    }

    pub fn is_empty(&self) -> bool {
        self.include.is_empty()
        // Note: self.exclude intentionally not considered. A glob is empty if
        // there are no included globs. A glob cannot have only excludes.
    }
}

impl Serialize for Glob {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        if self.exclude.is_empty() {
            // Serialize as glob([...]).
            let mut call = serializer.serialize_tuple_struct("glob", 1)?;
            call.serialize_field(&self.include)?;
            call.end()
        } else {
            // Serialize as glob(include = [...], exclude = [...]).
            let mut call = serializer.serialize_struct("glob", 2)?;
            call.serialize_field("include", &self.include)?;
            call.serialize_field("exclude", &self.exclude)?;
            call.end()
        }
    }
}
