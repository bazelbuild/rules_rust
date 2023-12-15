use std::collections::{BTreeMap, BTreeSet};
use std::fmt::Debug;

use serde::ser::{SerializeMap, Serializer};
use serde::{Deserialize, Serialize};
use serde_starlark::{FunctionCall, MULTILINE};

use crate::utils::starlark::serialize::MultilineArray;
use crate::utils::starlark::{
    looks_like_bazel_configuration_label, NoMatchingPlatformTriples, Select,
    WithOriginalConfigurations,
};

#[derive(Debug, Default, PartialEq, Eq, PartialOrd, Ord, Deserialize, Serialize, Clone)]
pub enum SelectValue<T: Ord> {
    #[default]
    Empty,
    Value(T),
    Select {
        // Invariant: `selects` is not empty.
        selects: BTreeMap<String, T>,
        // Element that used to be in `selects` before the most recent
        // `remap_configurations` operation, but whose old configuration did not get
        // mapped to any new configuration. This could be ignored, but are preserved
        // here to generate comments that help the user understand what happened.
        #[serde(skip_serializing_if = "BTreeSet::is_empty", default = "BTreeSet::new")]
        unmapped: BTreeSet<T>,
    },
}

impl<T: Ord> SelectValue<T> {
    pub fn set(&mut self, value: T, configuration: Option<String>) {
        match configuration {
            None => {
                *self = SelectValue::Value(value);
            }
            Some(cfg) => match self {
                SelectValue::Empty | SelectValue::Value(_) => {
                    *self = SelectValue::Select {
                        selects: BTreeMap::from([(cfg, value)]),
                        unmapped: BTreeSet::new(),
                    };
                }
                SelectValue::Select { selects, .. } => {
                    selects.insert(cfg, value);
                }
            },
        }
    }

    pub fn extend_select_value(&mut self, other: Self) {
        match other {
            SelectValue::Empty => (), // Do nothing.
            SelectValue::Value(value) => self.set(value, None),
            SelectValue::Select { selects, .. } => {
                for (cfg, value) in selects {
                    self.set(value, Some(cfg));
                }
            }
        }
    }

    pub fn get(&self, config: Option<&String>) -> Option<&T> {
        match config {
            Some(conf) => match self {
                SelectValue::Empty | SelectValue::Value(_) => None,
                SelectValue::Select { selects, .. } => selects.get(conf),
            },
            None => match self {
                SelectValue::Empty | SelectValue::Select { .. } => None,
                SelectValue::Value(value) => Some(value),
            },
        }
    }

    /// Determine whether or not the select should be serialized
    pub fn is_empty(&self) -> bool {
        matches!(self, SelectValue::Empty)
    }

    /// Maps configuration names by `f`. This function must be injective
    /// (that is `a != b --> f(a) != f(b)`).
    pub fn map_configuration_names<F>(self, mut f: F) -> Self
    where
        F: FnMut(String) -> String,
    {
        match self {
            SelectValue::Empty => SelectValue::Empty,
            SelectValue::Value(value) => SelectValue::Value(value),
            SelectValue::Select { selects, unmapped } => SelectValue::Select {
                selects: selects.into_iter().map(|(k, v)| (f(k), v)).collect(),
                unmapped: unmapped,
            },
        }
    }
}

impl SelectValue<String> {
    pub fn extend_select(&mut self, other: &crate::config::select::Select<String>) {
        self.set(other.common.clone(), None);
        for (cfg, value) in other.selects.iter() {
            self.set(value.clone(), Some(cfg.clone()));
        }
    }
}

impl<T: Ord> From<T> for SelectValue<T> {
    fn from(value: T) -> Self {
        SelectValue::Value(value)
    }
}

impl<T: Ord> From<BTreeMap<String, T>> for SelectValue<T> {
    fn from(selects: BTreeMap<String, T>) -> Self {
        SelectValue::Select {
            selects: selects,
            unmapped: BTreeSet::new(),
        }
    }
}

impl<T: Clone + Ord> SelectValue<T> {
    /// Generates a new SelectValue re-keyed by the given configuration mapping.
    /// This mapping maps from configurations in the current SelectValue to sets of
    /// configurations in the new SelectValue.
    pub fn remap_configurations(
        self,
        mapping: &BTreeMap<String, BTreeSet<String>>,
    ) -> SelectValue<WithOriginalConfigurations<T>> {
        match self {
            SelectValue::Empty => SelectValue::Empty,
            SelectValue::Value(value) => SelectValue::Value(WithOriginalConfigurations {
                value,
                original_configurations: None,
            }),
            SelectValue::Select { selects, .. } => {
                // Map new configuration -> value -> old configurations.
                let mut remapped: BTreeMap<String, (T, BTreeSet<String>)> = BTreeMap::new();
                // Map value -> old configurations.
                let mut unmapped: BTreeMap<T, BTreeSet<String>> = BTreeMap::new();

                for (original_configuration, value) in selects {
                    match mapping.get(&original_configuration) {
                        Some(configurations) => {
                            for configuration in configurations {
                                remapped
                                    .entry(configuration.clone())
                                    .or_insert_with(|| (value.clone(), BTreeSet::new()))
                                    .1
                                    .insert(original_configuration.clone());
                            }
                        }
                        None => {
                            let destination =
                                if looks_like_bazel_configuration_label(&original_configuration) {
                                    &mut remapped
                                        .entry(original_configuration.clone())
                                        .or_insert_with(|| (value.clone(), BTreeSet::new()))
                                        .1
                                } else {
                                    unmapped.entry(value.clone()).or_default()
                                };
                            destination.insert(original_configuration.clone());
                        }
                    }
                }

                SelectValue::Select {
                    selects: remapped
                        .into_iter()
                        .map(|(new_configuration, (value, original_configurations))| {
                            (
                                new_configuration,
                                WithOriginalConfigurations {
                                    value,
                                    original_configurations: Some(original_configurations),
                                },
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
    }
}

// TODO: after removing the remaining tera template usages of SelectList, this
// inherent method should become the Serialize impl.
impl<T: Ord> SelectValue<T> {
    pub fn serialize_starlark<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        T: Serialize,
        S: Serializer,
    {
        // If there are no platform-specific entries, we output just an ordinary
        // value.
        //
        // If there are platform-specific ones, we use the following.
        //
        //     select({
        //         "configuration": "plat-value",  # cfg(whatever),
        //     })
        //
        // If there are unmapped entries, we include them like this:
        //
        //     selects.with_unmapped({
        //         "configuration": "plat-value",  # cfg(whatever),
        //         selects.NO_MATCHING_PLATFORM_TRIPLES: [
        //             "unmapped-value",  # cfg(obscure)
        //         ],
        //     })

        match self {
            SelectValue::Empty => unreachable!(), // Serialize is skipped when empty.
            SelectValue::Value(value) => value.serialize(serializer),
            SelectValue::Select { selects, unmapped } => {
                struct SelectInner<'a, T> {
                    selects: &'a BTreeMap<String, T>,
                    unmapped: &'a BTreeSet<T>,
                }

                impl<'a, T> Serialize for SelectInner<'a, T>
                where
                    T: Ord + Serialize,
                {
                    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
                    where
                        S: Serializer,
                    {
                        let mut map = serializer.serialize_map(Some(MULTILINE))?;
                        for (cfg, value) in self.selects {
                            map.serialize_entry(cfg, &value)?;
                        }
                        if !self.unmapped.is_empty() {
                            map.serialize_entry(
                                &NoMatchingPlatformTriples,
                                &MultilineArray(self.unmapped),
                            )?;
                        }
                        map.end()
                    }
                }

                let function = if unmapped.is_empty() {
                    "select"
                } else {
                    "selects.with_unmapped"
                };

                FunctionCall::new(function, [SelectInner { selects, unmapped }])
                    .serialize(serializer)
            }
        }
    }
}

impl<T: Ord> Select<T> for SelectValue<T> {
    fn configurations(&self) -> BTreeSet<Option<&String>> {
        match self {
            SelectValue::Empty => BTreeSet::new(),
            SelectValue::Value(_) => BTreeSet::from([None]),
            SelectValue::Select { selects, .. } => selects.keys().map(Some).collect(),
        }
    }
}

#[cfg(test)]
mod test {
    use super::*;

    use indoc::indoc;

    // #[test]
    // fn empty_select_value() {
    //     let select_value: SelectValue<String> = SelectValue::default();

    //     let expected_starlark = indoc! {r#"
    //         {}
    //     "#};

    //     assert_eq!(
    //         select_dict
    //             .serialize_starlark(serde_starlark::Serializer)
    //             .unwrap(),
    //         expected_starlark,
    //     );
    // }

    #[test]
    fn no_platform_specific_select_value() {
        let mut select_value = SelectValue::default();
        select_value.set("Hello".to_owned(), None);

        let expected_starlark = indoc! {r#"
            "Hello"
        "#};

        assert_eq!(
            select_value
                .serialize_starlark(serde_starlark::Serializer)
                .unwrap(),
            expected_starlark,
        );
    }

    #[test]
    fn only_platform_specific_select_value() {
        let mut select_value = SelectValue::default();
        select_value.set("Hello".to_owned(), Some("platform".to_owned()));

        let expected_starlark = indoc! {r#"
            select({
                "platform": "Hello",
            })
        "#};

        assert_eq!(
            select_value
                .serialize_starlark(serde_starlark::Serializer)
                .unwrap(),
            expected_starlark,
        );
    }

    // #[test]
    // fn mixed_select_value() {
    //     let mut select_dict = SelectDict::default();
    //     select_dict.insert(
    //         "Greeting".to_owned(),
    //         "Hello".to_owned(),
    //         Some("platform".to_owned()),
    //     );
    //     select_dict.insert("Message".to_owned(), "Goodbye".to_owned(), None);

    //     let expected_starlark = indoc! {r#"
    //         select({
    //             "platform": {
    //                 "Greeting": "Hello",
    //                 "Message": "Goodbye",
    //             },
    //             "//conditions:default": {
    //                 "Message": "Goodbye",
    //             },
    //         })
    //     "#};

    //     assert_eq!(
    //         select_dict
    //             .serialize_starlark(serde_starlark::Serializer)
    //             .unwrap(),
    //         expected_starlark,
    //     );
    // }

    #[test]
    fn remap_select_value_configurations() {
        let mut select_value = SelectValue::default();
        select_value.set("a".to_owned(), Some("cfg(macos)".to_owned()));
        select_value.set("a".to_owned(), Some("cfg(x86_64)".to_owned()));
        select_value.set("e".to_owned(), Some("cfg(pdp11)".to_owned()));
        select_value.set("f".to_owned(), Some("@platforms//os:magic".to_owned()));
        select_value.set("g".to_owned(), Some("//another:platform".to_owned()));

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

        let mut expected = SelectValue::default();
        expected.set(
            WithOriginalConfigurations {
                value: "a".to_owned(),
                original_configurations: Some(BTreeSet::from([
                    "cfg(macos)".to_owned(),
                    "cfg(x86_64)".to_owned(),
                ])),
            },
            Some("x86_64-macos".to_owned()),
        );
        expected.set(
            WithOriginalConfigurations {
                value: "a".to_owned(),
                original_configurations: Some(BTreeSet::from(["cfg(macos)".to_owned()])),
            },
            Some("aarch64-macos".to_owned()),
        );
        expected.set(
            WithOriginalConfigurations {
                value: "a".to_owned(),
                original_configurations: Some(BTreeSet::from(["cfg(x86_64)".to_owned()])),
            },
            Some("x86_64-linux".to_owned()),
        );
        match &mut expected {
            SelectValue::Select { unmapped, .. } => {
                unmapped.insert(WithOriginalConfigurations {
                    value: "e".to_owned(),
                    original_configurations: Some(BTreeSet::from(["cfg(pdp11)".to_owned()])),
                });
            }
            _ => unreachable!(),
        }
        expected.set(
            WithOriginalConfigurations {
                value: "f".to_owned(),
                original_configurations: Some(BTreeSet::from(["@platforms//os:magic".to_owned()])),
            },
            Some("@platforms//os:magic".to_owned()),
        );
        expected.set(
            WithOriginalConfigurations {
                value: "g".to_owned(),
                original_configurations: Some(BTreeSet::from(["//another:platform".to_owned()])),
            },
            Some("//another:platform".to_owned()),
        );

        let select_value = select_value.remap_configurations(&mapping);
        assert_eq!(select_value, expected);

        let expected_starlark = indoc! {r#"
            selects.with_unmapped({
                "//another:platform": "g",  # //another:platform
                "@platforms//os:magic": "f",  # @platforms//os:magic
                "aarch64-macos": "a",  # cfg(macos)
                "x86_64-linux": "a",  # cfg(x86_64)
                "x86_64-macos": "a",  # cfg(macos), cfg(x86_64)
                selects.NO_MATCHING_PLATFORM_TRIPLES: [
                    "e",  # cfg(pdp11)
                ],
            })
        "#};

        assert_eq!(
            select_value
                .serialize_starlark(serde_starlark::Serializer)
                .unwrap(),
            expected_starlark,
        );
    }
}
