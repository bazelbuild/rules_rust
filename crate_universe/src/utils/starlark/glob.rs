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
}

impl Serialize for Glob {
    #[allow(unknown_lints, renamed_and_removed_lints)]
    #[allow(clippy::overly_complex_bool_expr)] // clippy 1.65+
    #[allow(clippy::logic_bug)] // clippy 1.64 and older
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        if false && self.exclude.is_empty() {
            // Serialize as glob([...]).
            // FIXME(dtolnay): this is disabled for now because the tera
            // template glob.j2 counts on the serialization to have separate
            // "include" and "exclude" fields. This can be enabled when the tera
            // use of globs is replaced with serde_starlark.
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
