use std::collections::BTreeSet;
use std::fmt;

use serde::de::value::{MapAccessDeserializer, SeqAccessDeserializer};
use serde::de::{Deserialize, Deserializer, MapAccess, SeqAccess, Visitor};
use serde::ser::{Serialize, SerializeStruct, Serializer};

#[derive(Debug, Default, PartialEq, Eq, PartialOrd, Ord, Clone)]
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
            serializer.serialize_newtype_struct("glob", &self.include)
        } else {
            // Serialize as glob(include = [...], exclude = [...]).
            let mut call = serializer.serialize_struct("glob", 2)?;
            call.serialize_field("include", &self.include)?;
            call.serialize_field("exclude", &self.exclude)?;
            call.end()
        }
    }
}

struct GlobVisitor;

impl<'de> Deserialize<'de> for Glob {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: Deserializer<'de>,
    {
        deserializer.deserialize_any(GlobVisitor)
    }
}

impl<'de> Visitor<'de> for GlobVisitor {
    type Value = Glob;

    fn expecting(&self, formatter: &mut fmt::Formatter) -> fmt::Result {
        formatter.write_str("glob")
    }

    // Deserialize ["included","globs","only"]
    fn visit_seq<A>(self, seq: A) -> Result<Self::Value, A::Error>
    where
        A: SeqAccess<'de>,
    {
        Ok(Glob {
            include: BTreeSet::deserialize(SeqAccessDeserializer::new(seq))?,
            exclude: BTreeSet::new(),
        })
    }

    // Deserialize {"include":["included","globs"],"exclude":["excluded","globs"]}
    fn visit_map<A>(self, map: A) -> Result<Self::Value, A::Error>
    where
        A: MapAccess<'de>,
    {
        #[derive(serde::Deserialize)]
        struct GlobMap {
            include: BTreeSet<String>,
            exclude: BTreeSet<String>,
        }

        let glob_map = GlobMap::deserialize(MapAccessDeserializer::new(map))?;
        Ok(Glob {
            include: glob_map.include,
            exclude: glob_map.exclude,
        })
    }
}
