use std::collections::BTreeSet;
use std::iter::FromIterator;

use serde::ser::Serializer;
use serde::Serialize;
use serde_starlark::LineComment;

pub trait SelectMap<T, U> {
    // A selectable should also implement a `map` function allowing one type of selectable
    // to be mutated into another. However, the approach I'm looking for requires GAT
    // (Generic Associated Types) which are not yet stable.
    // https://github.com/rust-lang/rust/issues/44265
    type Mapped;
    fn map<F: Copy + Fn(T) -> U>(self, func: F) -> Self::Mapped;
}

pub trait Select<T> {
    /// Gather a list of all conditions currently set on the selectable. A conditional
    /// would be the key of the select statement.
    fn configurations(&self) -> BTreeSet<Option<&String>>;
}

#[derive(Debug, PartialEq, Eq, PartialOrd, Ord, Clone)]
pub struct WithOriginalConfigurations<T> {
    pub value: T,
    pub original_configurations: Option<BTreeSet<String>>,
}

#[derive(Serialize)]
#[serde(rename = "selects.NO_MATCHING_PLATFORM_TRIPLES")]
pub struct NoMatchingPlatformTriples;

impl<T> Serialize for WithOriginalConfigurations<T>
where
    T: Serialize,
{
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        if let Some(original_configurations) = &self.original_configurations {
            let comment =
                Vec::from_iter(original_configurations.iter().map(String::as_str)).join(", ");
            LineComment::new(&self.value, &comment).serialize(serializer)
        } else {
            self.value.serialize(serializer)
        }
    }
}

// We allow users to specify labels as keys to selects, but we need to identify when this is happening
// because we also allow things like "x86_64-unknown-linux-gnu" as keys, and these technically parse as labels
// (that parses as "//x86_64-unknown-linux-gnu:x86_64-unknown-linux-gnu").
//
// We don't expect any cfg-expressions or target triples to contain //,
// and all labels _can_ be written in a way that they contain //,
// so we use the presence of // as an indication something is a label.
pub fn looks_like_bazel_configuration_label(configuration: &str) -> bool {
    configuration.contains("//")
}
