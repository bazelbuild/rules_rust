use std::collections::{btree_set, BTreeMap, BTreeSet};
use std::fmt::Debug;
use std::iter::once;

use serde::de::DeserializeOwned;
use serde::ser::{SerializeMap, SerializeTupleStruct, Serializer};
use serde::{Deserialize, Serialize};
use serde_starlark::{FunctionCall, MULTILINE};

use crate::select::Select as Select2;
use crate::utils::starlark::serialize::MultilineArray;
use crate::utils::starlark::{
    looks_like_bazel_configuration_label, NoMatchingPlatformTriples, Select, SelectMap,
    WithOriginalConfigurations,
};

#[derive(Debug, PartialEq, Eq, PartialOrd, Ord, Deserialize, Serialize, Clone)]
pub struct SelectSet<T: Ord> {
    // Invariant: any T in `common` is not anywhere in `selects`.
    common: BTreeSet<T>,
    // Invariant: none of the sets are empty.
    selects: BTreeMap<String, BTreeSet<T>>,
    // Elements that used to be in `selects` before the most recent
    // `remap_configurations` operation, but whose old configuration did not get
    // mapped to any new configuration. They could be ignored, but are preserved
    // here to generate comments that help the user understand what happened.
    #[serde(skip_serializing_if = "BTreeSet::is_empty", default = "BTreeSet::new")]
    unmapped: BTreeSet<T>,
}

impl<T: Ord> Default for SelectSet<T> {
    fn default() -> Self {
        Self {
            common: BTreeSet::new(),
            selects: BTreeMap::new(),
            unmapped: BTreeSet::new(),
        }
    }
}

impl<T: Ord> SelectSet<T> {
    // TODO: This should probably be added to the [Select] trait
    pub fn insert(&mut self, value: T, configuration: Option<String>) {
        match configuration {
            None => {
                self.selects.retain(|_, set| {
                    set.remove(&value);
                    !set.is_empty()
                });
                self.common.insert(value);
            }
            Some(cfg) => {
                if !self.common.contains(&value) {
                    self.selects.entry(cfg).or_default().insert(value);
                }
            }
        }
    }

    pub fn extend_select_set(&mut self, other: Self) {
        for value in other.common {
            self.insert(value, None);
        }
        for (cfg, values) in other.selects {
            for value in values {
                self.insert(value, Some(cfg.clone()));
            }
        }
    }

    // TODO: This should probably be added to the [Select] trait
    pub fn get_iter(&self, config: Option<&String>) -> Option<btree_set::Iter<T>> {
        match config {
            Some(conf) => self.selects.get(conf).map(|set| set.iter()),
            None => Some(self.common.iter()),
        }
    }

    /// Determine whether or not the select should be serialized
    pub fn is_empty(&self) -> bool {
        self.common.is_empty() && self.selects.is_empty() && self.unmapped.is_empty()
    }

    /// Maps configuration names by `f`. This function must be injective
    /// (that is `a != b --> f(a) != f(b)`).
    pub fn map_configuration_names<F>(self, mut f: F) -> Self
    where
        F: FnMut(String) -> String,
    {
        Self {
            common: self.common,
            selects: self.selects.into_iter().map(|(k, v)| (f(k), v)).collect(),
            unmapped: self.unmapped,
        }
    }
}

impl<T> SelectSet<T>
where
    T: Debug + Clone + PartialEq + Eq + PartialOrd + Ord + Serialize + DeserializeOwned,
{
    pub fn new(
        select: Select2<BTreeSet<T>>,
        platforms: &BTreeMap<String, BTreeSet<String>>,
    ) -> SelectSet<WithOriginalConfigurations<T>> {
        dbg!(platforms);

        let (common, selects) = select.into_parts();
        Self {
            common: common,
            selects: selects,
            unmapped: Default::default(),
        }
        .remap_configurations(platforms)
    }
}

impl<T: Ord> From<BTreeSet<T>> for SelectSet<T> {
    fn from(common: BTreeSet<T>) -> Self {
        Self {
            common: common,
            selects: BTreeMap::new(),
            unmapped: BTreeSet::new(),
        }
    }
}

impl<T: Ord> From<(BTreeSet<T>, BTreeMap<String, BTreeSet<T>>)> for SelectSet<T> {
    fn from((common, selects): (BTreeSet<T>, BTreeMap<String, BTreeSet<T>>)) -> Self {
        Self {
            common: common,
            selects: selects,
            unmapped: BTreeSet::new(),
        }
    }
}

impl<T: Ord + Clone> SelectSet<T> {
    /// Generates a new SelectSet re-keyed by the given configuration mapping.
    /// This mapping maps from configurations in the current SelectSet to sets of
    /// configurations in the new SelectSet.
    pub fn remap_configurations(
        self,
        mapping: &BTreeMap<String, BTreeSet<String>>,
    ) -> SelectSet<WithOriginalConfigurations<T>> {
        // Map new configuration -> value -> old configurations.
        let mut remapped: BTreeMap<String, BTreeMap<T, BTreeSet<String>>> = BTreeMap::new();
        // Map value -> old configurations.
        let mut unmapped: BTreeMap<T, BTreeSet<String>> = BTreeMap::new();

        for (original_configuration, values) in self.selects {
            match mapping.get(&original_configuration) {
                Some(configurations) => {
                    for configuration in configurations {
                        for value in &values {
                            remapped
                                .entry(configuration.clone())
                                .or_default()
                                .entry(value.clone())
                                .or_default()
                                .insert(original_configuration.clone());
                        }
                    }
                }
                None => {
                    let destination =
                        if looks_like_bazel_configuration_label(&original_configuration) {
                            remapped.entry(original_configuration.clone()).or_default()
                        } else {
                            &mut unmapped
                        };
                    for value in values {
                        destination
                            .entry(value)
                            .or_default()
                            .insert(original_configuration.clone());
                    }
                }
            }
        }

        SelectSet {
            common: self
                .common
                .into_iter()
                .map(|value| WithOriginalConfigurations {
                    value,
                    original_configurations: None,
                })
                .collect(),
            selects: remapped
                .into_iter()
                .map(|(new_configuration, value_to_original_configuration)| {
                    (
                        new_configuration,
                        value_to_original_configuration
                            .into_iter()
                            .map(
                                |(value, original_configurations)| WithOriginalConfigurations {
                                    value,
                                    original_configurations: Some(original_configurations),
                                },
                            )
                            .collect(),
                    )
                })
                .collect(),
            unmapped: unmapped
                .into_iter()
                .map(
                    |(value, original_configurations)| WithOriginalConfigurations {
                        value,
                        original_configurations: Some(original_configurations),
                    },
                )
                .collect(),
        }
    }
}

// TODO: after removing the remaining tera template usages of SelectSet, this
// inherent method should become the Serialize impl.
impl<T: Ord> SelectSet<T> {
    pub fn serialize_starlark<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        T: Serialize,
        S: Serializer,
    {
        // Output looks like:
        //
        //     [
        //         "common...",
        //     ] + select({
        //         "configuration": [
        //             "value...",  # cfg(whatever)
        //         ],
        //         "//conditions:default": [],
        //     })
        //
        // The common part and select are each omitted if they are empty (except
        // if the entire thing is empty, in which case we serialize the common
        // part to get an empty array).
        //
        // If there are unmapped entries, we include them like this:
        //
        //     [
        //         "common...",
        //     ] + selects.with_unmapped({
        //         "configuration": [
        //             "value...",  # cfg(whatever)
        //         ],
        //         "//conditions:default": [],
        //         selects.NO_MATCHING_PLATFORM_TRIPLES: [
        //             "value...",  # cfg(obscure)
        //         ],
        //     })

        let mut plus = serializer.serialize_tuple_struct("+", MULTILINE)?;

        if !self.common.is_empty() || self.selects.is_empty() && self.unmapped.is_empty() {
            plus.serialize_field(&MultilineArray(&self.common))?;
        }

        if !self.selects.is_empty() || !self.unmapped.is_empty() {
            struct SelectInner<'a, T: Ord>(&'a SelectSet<T>);

            impl<'a, T> Serialize for SelectInner<'a, T>
            where
                T: Ord + Serialize,
            {
                fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
                where
                    S: Serializer,
                {
                    let mut map = serializer.serialize_map(Some(MULTILINE))?;
                    for (cfg, value) in &self.0.selects {
                        map.serialize_entry(cfg, &MultilineArray(value))?;
                    }
                    map.serialize_entry("//conditions:default", &[] as &[T])?;
                    if !self.0.unmapped.is_empty() {
                        map.serialize_entry(
                            &NoMatchingPlatformTriples,
                            &MultilineArray(&self.0.unmapped),
                        )?;
                    }
                    map.end()
                }
            }

            let function = if self.unmapped.is_empty() {
                "select"
            } else {
                "selects.with_unmapped"
            };

            plus.serialize_field(&FunctionCall::new(function, [SelectInner(self)]))?;
        }

        plus.end()
    }
}

impl<T: Ord> Select<T> for SelectSet<T> {
    fn configurations(&self) -> BTreeSet<Option<&String>> {
        let configs = self.selects.keys().map(Some);
        match self.common.is_empty() {
            true => configs.collect(),
            false => configs.chain(once(None)).collect(),
        }
    }
}

impl<T: Ord, U: Ord> SelectMap<T, U> for SelectSet<T> {
    type Mapped = SelectSet<U>;

    fn map<F: Copy + Fn(T) -> U>(self, func: F) -> Self::Mapped {
        let common: BTreeSet<U> = self.common.into_iter().map(func).collect();
        let selects: BTreeMap<String, BTreeSet<U>> = self
            .selects
            .into_iter()
            .filter_map(|(key, set)| {
                let set: BTreeSet<U> = set
                    .into_iter()
                    .map(func)
                    .filter(|value| !common.contains(value))
                    .collect();
                if set.is_empty() {
                    None
                } else {
                    Some((key, set))
                }
            })
            .collect();
        SelectSet {
            common,
            selects,
            unmapped: self.unmapped.into_iter().map(func).collect(),
        }
    }
}

#[cfg(test)]
mod test {
    use super::*;

    use indoc::indoc;

    #[test]
    fn empty_select_set() {
        let select_set: SelectSet<String> = SelectSet::default();

        let expected_starlark = indoc! {r#"
            []
        "#};

        assert_eq!(
            select_set
                .serialize_starlark(serde_starlark::Serializer)
                .unwrap(),
            expected_starlark,
        );
    }

    #[test]
    fn no_platform_specific_select_set() {
        let mut select_set = SelectSet::default();
        select_set.insert("Hello".to_owned(), None);

        let expected_starlark = indoc! {r#"
            [
                "Hello",
            ]
        "#};

        assert_eq!(
            select_set
                .serialize_starlark(serde_starlark::Serializer)
                .unwrap(),
            expected_starlark,
        );
    }

    #[test]
    fn only_platform_specific_select_set() {
        let mut select_set = SelectSet::default();
        select_set.insert("Hello".to_owned(), Some("platform".to_owned()));

        let expected_starlark = indoc! {r#"
            select({
                "platform": [
                    "Hello",
                ],
                "//conditions:default": [],
            })
        "#};

        assert_eq!(
            select_set
                .serialize_starlark(serde_starlark::Serializer)
                .unwrap(),
            expected_starlark,
        );
    }

    #[test]
    fn mixed_select_set() {
        let mut select_set = SelectSet::default();
        select_set.insert("Hello".to_owned(), Some("platform".to_owned()));
        select_set.insert("Goodbye".to_owned(), None);

        let expected_starlark = indoc! {r#"
            [
                "Goodbye",
            ] + select({
                "platform": [
                    "Hello",
                ],
                "//conditions:default": [],
            })
        "#};

        assert_eq!(
            select_set
                .serialize_starlark(serde_starlark::Serializer)
                .unwrap(),
            expected_starlark,
        );
    }

    #[test]
    fn remap_select_set_configurations() {
        let mut select_set = SelectSet::default();
        select_set.insert("dep-a".to_owned(), Some("cfg(macos)".to_owned()));
        select_set.insert("dep-b".to_owned(), Some("cfg(macos)".to_owned()));
        select_set.insert("dep-d".to_owned(), Some("cfg(macos)".to_owned()));
        select_set.insert("dep-a".to_owned(), Some("cfg(x86_64)".to_owned()));
        select_set.insert("dep-c".to_owned(), Some("cfg(x86_64)".to_owned()));
        select_set.insert("dep-e".to_owned(), Some("cfg(pdp11)".to_owned()));
        select_set.insert("dep-d".to_owned(), None);
        select_set.insert("dep-f".to_owned(), Some("@platforms//os:magic".to_owned()));
        select_set.insert("dep-g".to_owned(), Some("//another:platform".to_owned()));

        let mapping = BTreeMap::from([
            (
                "cfg(macos)".to_owned(),
                BTreeSet::from(["x86_64-macos".to_owned(), "aarch64-macos".to_owned()]),
            ),
            (
                "cfg(x86_64)".to_owned(),
                BTreeSet::from(["x86_64-linux".to_owned(), "x86_64-macos".to_owned()]),
            ),
        ]);

        let mut expected = SelectSet::default();
        expected.insert(
            WithOriginalConfigurations {
                value: "dep-a".to_owned(),
                original_configurations: Some(BTreeSet::from([
                    "cfg(macos)".to_owned(),
                    "cfg(x86_64)".to_owned(),
                ])),
            },
            Some("x86_64-macos".to_owned()),
        );
        expected.insert(
            WithOriginalConfigurations {
                value: "dep-b".to_owned(),
                original_configurations: Some(BTreeSet::from(["cfg(macos)".to_owned()])),
            },
            Some("x86_64-macos".to_owned()),
        );
        expected.insert(
            WithOriginalConfigurations {
                value: "dep-c".to_owned(),
                original_configurations: Some(BTreeSet::from(["cfg(x86_64)".to_owned()])),
            },
            Some("x86_64-macos".to_owned()),
        );
        expected.insert(
            WithOriginalConfigurations {
                value: "dep-a".to_owned(),
                original_configurations: Some(BTreeSet::from(["cfg(macos)".to_owned()])),
            },
            Some("aarch64-macos".to_owned()),
        );
        expected.insert(
            WithOriginalConfigurations {
                value: "dep-b".to_owned(),
                original_configurations: Some(BTreeSet::from(["cfg(macos)".to_owned()])),
            },
            Some("aarch64-macos".to_owned()),
        );
        expected.insert(
            WithOriginalConfigurations {
                value: "dep-a".to_owned(),
                original_configurations: Some(BTreeSet::from(["cfg(x86_64)".to_owned()])),
            },
            Some("x86_64-linux".to_owned()),
        );
        expected.insert(
            WithOriginalConfigurations {
                value: "dep-c".to_owned(),
                original_configurations: Some(BTreeSet::from(["cfg(x86_64)".to_owned()])),
            },
            Some("x86_64-linux".to_owned()),
        );
        expected.insert(
            WithOriginalConfigurations {
                value: "dep-d".to_owned(),
                original_configurations: None,
            },
            None,
        );
        expected.unmapped.insert(WithOriginalConfigurations {
            value: "dep-e".to_owned(),
            original_configurations: Some(BTreeSet::from(["cfg(pdp11)".to_owned()])),
        });
        expected.insert(
            WithOriginalConfigurations {
                value: "dep-f".to_owned(),
                original_configurations: Some(BTreeSet::from(["@platforms//os:magic".to_owned()])),
            },
            Some("@platforms//os:magic".to_owned()),
        );
        expected.insert(
            WithOriginalConfigurations {
                value: "dep-g".to_owned(),
                original_configurations: Some(BTreeSet::from(["//another:platform".to_owned()])),
            },
            Some("//another:platform".to_owned()),
        );

        let select_set = select_set.remap_configurations(&mapping);
        assert_eq!(select_set, expected);

        let expected_starlark = indoc! {r#"
            [
                "dep-d",
            ] + selects.with_unmapped({
                "//another:platform": [
                    "dep-g",  # //another:platform
                ],
                "@platforms//os:magic": [
                    "dep-f",  # @platforms//os:magic
                ],
                "aarch64-macos": [
                    "dep-a",  # cfg(macos)
                    "dep-b",  # cfg(macos)
                ],
                "x86_64-linux": [
                    "dep-a",  # cfg(x86_64)
                    "dep-c",  # cfg(x86_64)
                ],
                "x86_64-macos": [
                    "dep-a",  # cfg(macos), cfg(x86_64)
                    "dep-b",  # cfg(macos)
                    "dep-c",  # cfg(x86_64)
                ],
                "//conditions:default": [],
                selects.NO_MATCHING_PLATFORM_TRIPLES: [
                    "dep-e",  # cfg(pdp11)
                ],
            })
        "#};

        assert_eq!(
            select_set
                .serialize_starlark(serde_starlark::Serializer)
                .unwrap(),
            expected_starlark,
        );
    }
}
