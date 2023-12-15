use std::collections::{BTreeMap, BTreeSet};
use std::fmt::Debug;

use serde::ser::{SerializeMap, Serializer};
use serde::Serialize;
use serde_starlark::{FunctionCall, MULTILINE};

use crate::select::Select;
use crate::utils::starlark::{
    looks_like_bazel_configuration_label, NoMatchingPlatformTriples, WithOriginalConfigurations,
};

#[derive(Debug, PartialEq, Eq, Serialize)]
pub struct SelectDict<T: Ord> {
    // Invariant: keys in this map are not in any of the inner maps of `selects`.
    common: BTreeMap<String, WithOriginalConfigurations<T>>,
    // Invariant: none of the inner maps are empty.
    selects: BTreeMap<String, BTreeMap<String, WithOriginalConfigurations<T>>>,
    // Elements that used to be in `selects` before the most recent
    // `remap_configurations` operation, but whose old configuration did not get
    // mapped to any new configuration. They could be ignored, but are preserved
    // here to generate comments that help the user understand what happened.
    #[serde(skip_serializing_if = "BTreeMap::is_empty", default = "BTreeMap::new")]
    unmapped: BTreeMap<String, WithOriginalConfigurations<T>>,
}

impl<T> SelectDict<T>
where
    T: Debug + Clone + PartialEq + Eq + PartialOrd + Ord + Serialize,
{
    /// Re-keys the provided Select by the given configuration mapping.
    /// This mapping maps from configurations in the input Select to sets
    /// of configurations in the output SelectDict.
    pub fn new(
        select: Select<BTreeMap<String, T>>,
        platforms: &BTreeMap<String, BTreeSet<String>>,
    ) -> Self {
        let (common, selects) = select.into_parts();

        // Map new configuration -> entry -> old configurations.
        let mut remapped: BTreeMap<String, BTreeMap<(String, T), BTreeSet<String>>> =
            BTreeMap::new();
        // Map entry -> old configurations.
        let mut unmapped: BTreeMap<(String, T), BTreeSet<String>> = BTreeMap::new();

        for (original_configuration, entries) in selects {
            match platforms.get(&original_configuration) {
                Some(configurations) => {
                    for configuration in configurations {
                        for (key, value) in &entries {
                            remapped
                                .entry(configuration.clone())
                                .or_default()
                                .entry((key.clone(), value.clone()))
                                .or_default()
                                .insert(original_configuration.clone());
                        }
                    }
                }
                None => {
                    for (key, value) in entries {
                        let destination =
                            if looks_like_bazel_configuration_label(&original_configuration) {
                                remapped.entry(original_configuration.clone()).or_default()
                            } else {
                                &mut unmapped
                            };
                        destination
                            .entry((key, value))
                            .or_default()
                            .insert(original_configuration.clone());
                    }
                }
            }
        }

        Self {
            common: common
                .into_iter()
                .map(|(key, value)| {
                    (
                        key,
                        WithOriginalConfigurations {
                            value,
                            original_configurations: None,
                        },
                    )
                })
                .collect(),
            selects: remapped
                .into_iter()
                .map(|(new_configuration, entry_to_original_configuration)| {
                    (
                        new_configuration,
                        entry_to_original_configuration
                            .into_iter()
                            .map(|((key, value), original_configurations)| {
                                (
                                    key,
                                    WithOriginalConfigurations {
                                        value,
                                        original_configurations: Some(original_configurations),
                                    },
                                )
                            })
                            .collect(),
                    )
                })
                .collect(),
            unmapped: unmapped
                .into_iter()
                .map(|((key, value), original_configurations)| {
                    (
                        key,
                        WithOriginalConfigurations {
                            value,
                            original_configurations: Some(original_configurations),
                        },
                    )
                })
                .collect(),
        }
    }

    pub fn is_empty(&self) -> bool {
        self.common.is_empty() && self.selects.is_empty() && self.unmapped.is_empty()
    }
}

// TODO: after removing the remaining tera template usages of SelectDict, this
// inherent method should become the Serialize impl.
impl<T: Ord + Serialize> SelectDict<T> {
    pub fn serialize_starlark<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        // If there are no platform-specific entries, we output just an ordinary
        // dict.
        //
        // If there are platform-specific ones, we use the following. Ideally it
        // could be done as `dicts.add({...}, select({...}))` but bazel_skylib's
        // dicts.add does not support selects.
        //
        //     select({
        //         "configuration": {
        //             "common-key": "common-value",
        //             "plat-key": "plat-value",  # cfg(whatever)
        //         },
        //         "//conditions:default": {},
        //     })
        //
        // If there are unmapped entries, we include them like this:
        //
        //     selects.with_unmapped({
        //         "configuration": {
        //             "common-key": "common-value",
        //             "plat-key": "plat-value",  # cfg(whatever)
        //         },
        //         "//conditions:default": {},
        //         selects.NO_MATCHING_PLATFORM_TRIPLES: {
        //             "unmapped-key": "unmapped-value",  # cfg(obscure)
        //         },
        //     })

        if self.selects.is_empty() && self.unmapped.is_empty() {
            return self.common.serialize(serializer);
        }

        struct SelectInner<'a, T: Ord>(&'a SelectDict<T>);

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
                    let mut combined = BTreeMap::new();
                    combined.extend(&self.0.common);
                    combined.extend(value);
                    map.serialize_entry(cfg, &combined)?;
                }
                map.serialize_entry("//conditions:default", &self.0.common)?;
                if !self.0.unmapped.is_empty() {
                    map.serialize_entry(&NoMatchingPlatformTriples, &self.0.unmapped)?;
                }
                map.end()
            }
        }

        let function = if self.unmapped.is_empty() {
            "select"
        } else {
            "selects.with_unmapped"
        };

        FunctionCall::new(function, [SelectInner(self)]).serialize(serializer)
    }
}

#[cfg(test)]
mod test {
    use super::*;

    use indoc::indoc;

    #[test]
    fn empty_select_dict() {
        let select_dict: SelectDict<String> =
            SelectDict::new(Default::default(), &Default::default());

        let expected_starlark = indoc! {r#"
            {}
        "#};

        assert_eq!(
            select_dict
                .serialize_starlark(serde_starlark::Serializer)
                .unwrap(),
            expected_starlark,
        );
    }

    #[test]
    fn no_platform_specific_select_dict() {
        let mut select: Select<BTreeMap<String, String>> = Select::default();
        select.insert("Greeting".to_owned(), "Hello".to_owned(), None);

        let select_dict = SelectDict::new(select, &Default::default());

        let expected_starlark = indoc! {r#"
            {
                "Greeting": "Hello",
            }
        "#};

        assert_eq!(
            select_dict
                .serialize_starlark(serde_starlark::Serializer)
                .unwrap(),
            expected_starlark,
        );
    }

    #[test]
    fn only_platform_specific_select_dict() {
        let mut select: Select<BTreeMap<String, String>> = Select::default();
        select.insert(
            "Greeting".to_owned(),
            "Hello".to_owned(),
            Some("platform".to_owned()),
        );

        let platforms = BTreeMap::from([(
            "platform".to_owned(),
            BTreeSet::from(["platform".to_owned()]),
        )]);

        let select_dict = SelectDict::new(select, &platforms);

        let expected_starlark = indoc! {r#"
            select({
                "platform": {
                    "Greeting": "Hello",  # platform
                },
                "//conditions:default": {},
            })
        "#};

        assert_eq!(
            select_dict
                .serialize_starlark(serde_starlark::Serializer)
                .unwrap(),
            expected_starlark,
        );
    }

    #[test]
    fn mixed_select_dict() {
        let mut select: Select<BTreeMap<String, String>> = Select::default();
        select.insert(
            "Greeting".to_owned(),
            "Hello".to_owned(),
            Some("platform".to_owned()),
        );
        select.insert("Message".to_owned(), "Goodbye".to_owned(), None);

        let platforms = BTreeMap::from([(
            "platform".to_owned(),
            BTreeSet::from(["platform".to_owned()]),
        )]);

        let select_dict = SelectDict::new(select, &platforms);

        let expected_starlark = indoc! {r#"
            select({
                "platform": {
                    "Greeting": "Hello",  # platform
                    "Message": "Goodbye",
                },
                "//conditions:default": {
                    "Message": "Goodbye",
                },
            })
        "#};

        assert_eq!(
            select_dict
                .serialize_starlark(serde_starlark::Serializer)
                .unwrap(),
            expected_starlark,
        );
    }

    #[test]
    fn remap_select_dict_configurations() {
        let mut select: Select<BTreeMap<String, String>> = Select::default();
        select.insert(
            "dep-a".to_owned(),
            "a".to_owned(),
            Some("cfg(macos)".to_owned()),
        );
        select.insert(
            "dep-b".to_owned(),
            "b".to_owned(),
            Some("cfg(macos)".to_owned()),
        );
        select.insert(
            "dep-d".to_owned(),
            "d".to_owned(),
            Some("cfg(macos)".to_owned()),
        );
        select.insert(
            "dep-a".to_owned(),
            "a".to_owned(),
            Some("cfg(x86_64)".to_owned()),
        );
        select.insert(
            "dep-c".to_owned(),
            "c".to_owned(),
            Some("cfg(x86_64)".to_owned()),
        );
        select.insert(
            "dep-e".to_owned(),
            "e".to_owned(),
            Some("cfg(pdp11)".to_owned()),
        );
        select.insert("dep-d".to_owned(), "d".to_owned(), None);
        select.insert(
            "dep-f".to_owned(),
            "f".to_owned(),
            Some("@platforms//os:magic".to_owned()),
        );
        select.insert(
            "dep-g".to_owned(),
            "g".to_owned(),
            Some("//another:platform".to_owned()),
        );

        let platforms = BTreeMap::from([
            (
                "cfg(macos)".to_owned(),
                BTreeSet::from(["x86_64-macos".to_owned(), "aarch64-macos".to_owned()]),
            ),
            (
                "cfg(x86_64)".to_owned(),
                BTreeSet::from(["x86_64-linux".to_owned(), "x86_64-macos".to_owned()]),
            ),
        ]);

        let select_dict = SelectDict::new(select, &platforms);

        let expected = SelectDict {
            common: BTreeMap::from([(
                "dep-d".to_string(),
                WithOriginalConfigurations {
                    value: "d".to_owned(),
                    original_configurations: None,
                },
            )]),
            selects: BTreeMap::from([
                (
                    "x86_64-macos".to_owned(),
                    BTreeMap::from([
                        (
                            "dep-a".to_string(),
                            WithOriginalConfigurations {
                                value: "a".to_owned(),
                                original_configurations: Some(BTreeSet::from([
                                    "cfg(macos)".to_owned(),
                                    "cfg(x86_64)".to_owned(),
                                ])),
                            },
                        ),
                        (
                            "dep-b".to_string(),
                            WithOriginalConfigurations {
                                value: "b".to_owned(),
                                original_configurations: Some(BTreeSet::from([
                                    "cfg(macos)".to_owned()
                                ])),
                            },
                        ),
                        (
                            "dep-c".to_string(),
                            WithOriginalConfigurations {
                                value: "c".to_owned(),
                                original_configurations: Some(BTreeSet::from([
                                    "cfg(x86_64)".to_owned()
                                ])),
                            },
                        ),
                    ]),
                ),
                (
                    "aarch64-macos".to_owned(),
                    BTreeMap::from([
                        (
                            "dep-a".to_string(),
                            WithOriginalConfigurations {
                                value: "a".to_owned(),
                                original_configurations: Some(BTreeSet::from([
                                    "cfg(macos)".to_owned()
                                ])),
                            },
                        ),
                        (
                            "dep-b".to_string(),
                            WithOriginalConfigurations {
                                value: "b".to_owned(),
                                original_configurations: Some(BTreeSet::from([
                                    "cfg(macos)".to_owned()
                                ])),
                            },
                        ),
                    ]),
                ),
                (
                    "x86_64-linux".to_owned(),
                    BTreeMap::from([
                        (
                            "dep-a".to_string(),
                            WithOriginalConfigurations {
                                value: "a".to_owned(),
                                original_configurations: Some(BTreeSet::from([
                                    "cfg(x86_64)".to_owned()
                                ])),
                            },
                        ),
                        (
                            "dep-c".to_string(),
                            WithOriginalConfigurations {
                                value: "c".to_owned(),
                                original_configurations: Some(BTreeSet::from([
                                    "cfg(x86_64)".to_owned()
                                ])),
                            },
                        ),
                    ]),
                ),
                (
                    "@platforms//os:magic".to_owned(),
                    BTreeMap::from([(
                        "dep-f".to_string(),
                        WithOriginalConfigurations {
                            value: "f".to_owned(),
                            original_configurations: Some(BTreeSet::from([
                                "@platforms//os:magic".to_owned()
                            ])),
                        },
                    )]),
                ),
                (
                    "//another:platform".to_owned(),
                    BTreeMap::from([(
                        "dep-g".to_string(),
                        WithOriginalConfigurations {
                            value: "g".to_owned(),
                            original_configurations: Some(BTreeSet::from([
                                "//another:platform".to_owned()
                            ])),
                        },
                    )]),
                ),
            ]),
            unmapped: BTreeMap::from([(
                "dep-e".to_string(),
                WithOriginalConfigurations {
                    value: "e".to_owned(),
                    original_configurations: Some(BTreeSet::from(["cfg(pdp11)".to_owned()])),
                },
            )]),
        };

        assert_eq!(select_dict, expected);

        let expected_starlark = indoc! {r#"
            selects.with_unmapped({
                "//another:platform": {
                    "dep-d": "d",
                    "dep-g": "g",  # //another:platform
                },
                "@platforms//os:magic": {
                    "dep-d": "d",
                    "dep-f": "f",  # @platforms//os:magic
                },
                "aarch64-macos": {
                    "dep-a": "a",  # cfg(macos)
                    "dep-b": "b",  # cfg(macos)
                    "dep-d": "d",
                },
                "x86_64-linux": {
                    "dep-a": "a",  # cfg(x86_64)
                    "dep-c": "c",  # cfg(x86_64)
                    "dep-d": "d",
                },
                "x86_64-macos": {
                    "dep-a": "a",  # cfg(macos), cfg(x86_64)
                    "dep-b": "b",  # cfg(macos)
                    "dep-c": "c",  # cfg(x86_64)
                    "dep-d": "d",
                },
                "//conditions:default": {
                    "dep-d": "d",
                },
                selects.NO_MATCHING_PLATFORM_TRIPLES: {
                    "dep-e": "e",  # cfg(pdp11)
                },
            })
        "#};

        assert_eq!(
            select_dict
                .serialize_starlark(serde_starlark::Serializer)
                .unwrap(),
            expected_starlark,
        );
    }
}
