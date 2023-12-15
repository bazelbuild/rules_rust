use std::collections::{BTreeMap, BTreeSet};
use std::iter::once;

use crate::config::StringOrSelect;
use serde::ser::{SerializeMap, Serializer};
use serde::{Deserialize, Serialize};
use serde_starlark::{FunctionCall, MULTILINE};

use crate::utils::starlark::{
    looks_like_bazel_configuration_label, NoMatchingPlatformTriples, Select,
    WithOriginalConfigurations,
};

#[derive(Debug, PartialEq, Eq, PartialOrd, Ord, Deserialize, Serialize, Clone)]
pub struct SelectDict<T: Ord> {
    // Invariant: keys in this map are not in any of the inner maps of `selects`.
    common: BTreeMap<String, T>,
    // Invariant: none of the inner maps are empty.
    selects: BTreeMap<String, BTreeMap<String, T>>,
    // Elements that used to be in `selects` before the most recent
    // `remap_configurations` operation, but whose old configuration did not get
    // mapped to any new configuration. They could be ignored, but are preserved
    // here to generate comments that help the user understand what happened.
    #[serde(skip_serializing_if = "BTreeMap::is_empty", default = "BTreeMap::new")]
    unmapped: BTreeMap<String, T>,
}

impl<T: Ord> Default for SelectDict<T> {
    fn default() -> Self {
        Self {
            common: BTreeMap::new(),
            selects: BTreeMap::new(),
            unmapped: BTreeMap::new(),
        }
    }
}

impl<T: Ord> SelectDict<T> {
    pub fn insert(&mut self, key: String, value: T, configuration: Option<String>) {
        match configuration {
            None => {
                self.selects.retain(|_, map| {
                    map.remove(&key);
                    !map.is_empty()
                });
                self.common.insert(key, value);
            }
            Some(cfg) => {
                if !self.common.contains_key(&key) {
                    self.selects.entry(cfg).or_default().insert(key, value);
                }
            }
        }
    }

    pub fn extend_select_dict(&mut self, other: Self) {
        for (key, value) in other.common {
            self.insert(key, value, None);
        }
        for (cfg, entries) in other.selects {
            for (key, value) in entries {
                self.insert(key, value, Some(cfg.clone()));
            }
        }
    }

    pub fn extend(&mut self, entries: BTreeMap<String, T>, configuration: Option<String>) {
        for (key, value) in entries {
            self.insert(key, value, configuration.clone());
        }
    }

    pub fn is_empty(&self) -> bool {
        self.common.is_empty() && self.selects.is_empty() && self.unmapped.is_empty()
    }
}

impl<T: Ord> From<BTreeMap<String, T>> for SelectDict<T> {
    fn from(common: BTreeMap<String, T>) -> Self {
        Self {
            common: common,
            selects: BTreeMap::new(),
            unmapped: BTreeMap::new(),
        }
    }
}

impl<T: Ord> From<(BTreeMap<String, T>, BTreeMap<String, BTreeMap<String, T>>)> for SelectDict<T> {
    fn from(
        (common, selects): (BTreeMap<String, T>, BTreeMap<String, BTreeMap<String, T>>),
    ) -> Self {
        Self {
            common: common,
            selects: selects,
            unmapped: BTreeMap::new(),
        }
    }
}

impl SelectDict<String> {
    pub fn extend_from_string_or_select<Iter: Iterator<Item = (String, StringOrSelect)>>(
        &mut self,
        values: Iter,
    ) {
        for (key, value) in values {
            match value {
                StringOrSelect::Value(value) => {
                    self.insert(key, value, None);
                }
                StringOrSelect::Select(select) => {
                    for (select_key, value) in select {
                        self.insert(key.clone(), value, Some(select_key));
                    }
                }
            }
        }
    }
}

impl<T: Ord + Clone> SelectDict<T> {
    /// Generates a new SelectDict re-keyed by the given configuration mapping.
    /// This mapping maps from configurations in the current SelectDict to sets
    /// of configurations in the new SelectDict.
    pub fn remap_configurations(
        self,
        mapping: &BTreeMap<String, BTreeSet<String>>,
    ) -> SelectDict<WithOriginalConfigurations<T>> {
        // Map new configuration -> entry -> old configurations.
        let mut remapped: BTreeMap<String, BTreeMap<(String, T), BTreeSet<String>>> =
            BTreeMap::new();
        // Map entry -> old configurations.
        let mut unmapped: BTreeMap<(String, T), BTreeSet<String>> = BTreeMap::new();

        for (original_configuration, entries) in self.selects {
            match mapping.get(&original_configuration) {
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

        SelectDict {
            common: self
                .common
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

impl<T: Ord> Select<T> for SelectDict<T> {
    fn configurations(&self) -> BTreeSet<Option<&String>> {
        let configs = self.selects.keys().map(Some);
        match self.common.is_empty() {
            true => configs.collect(),
            false => configs.chain(once(None)).collect(),
        }
    }
}

#[cfg(test)]
mod test {
    use super::*;

    use indoc::indoc;

    #[test]
    fn empty_select_dict() {
        let select_dict: SelectDict<String> = SelectDict::default();

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
        let mut select_dict = SelectDict::default();
        select_dict.insert("Greeting".to_owned(), "Hello".to_owned(), None);

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
        let mut select_dict = SelectDict::default();
        select_dict.insert(
            "Greeting".to_owned(),
            "Hello".to_owned(),
            Some("platform".to_owned()),
        );

        let expected_starlark = indoc! {r#"
            select({
                "platform": {
                    "Greeting": "Hello",
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
        let mut select_dict = SelectDict::default();
        select_dict.insert(
            "Greeting".to_owned(),
            "Hello".to_owned(),
            Some("platform".to_owned()),
        );
        select_dict.insert("Message".to_owned(), "Goodbye".to_owned(), None);

        let expected_starlark = indoc! {r#"
            select({
                "platform": {
                    "Greeting": "Hello",
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
        let mut select_dict = SelectDict::default();
        select_dict.insert(
            "dep-a".to_owned(),
            "a".to_owned(),
            Some("cfg(macos)".to_owned()),
        );
        select_dict.insert(
            "dep-b".to_owned(),
            "b".to_owned(),
            Some("cfg(macos)".to_owned()),
        );
        select_dict.insert(
            "dep-d".to_owned(),
            "d".to_owned(),
            Some("cfg(macos)".to_owned()),
        );
        select_dict.insert(
            "dep-a".to_owned(),
            "a".to_owned(),
            Some("cfg(x86_64)".to_owned()),
        );
        select_dict.insert(
            "dep-c".to_owned(),
            "c".to_owned(),
            Some("cfg(x86_64)".to_owned()),
        );
        select_dict.insert(
            "dep-e".to_owned(),
            "e".to_owned(),
            Some("cfg(pdp11)".to_owned()),
        );
        select_dict.insert("dep-d".to_owned(), "d".to_owned(), None);
        select_dict.insert(
            "dep-f".to_owned(),
            "f".to_owned(),
            Some("@platforms//os:magic".to_owned()),
        );
        select_dict.insert(
            "dep-g".to_owned(),
            "g".to_owned(),
            Some("//another:platform".to_owned()),
        );

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

        let mut expected = SelectDict::default();
        expected.insert(
            "dep-a".to_string(),
            WithOriginalConfigurations {
                value: "a".to_owned(),
                original_configurations: Some(BTreeSet::from([
                    "cfg(macos)".to_owned(),
                    "cfg(x86_64)".to_owned(),
                ])),
            },
            Some("x86_64-macos".to_owned()),
        );
        expected.insert(
            "dep-b".to_string(),
            WithOriginalConfigurations {
                value: "b".to_owned(),
                original_configurations: Some(BTreeSet::from(["cfg(macos)".to_owned()])),
            },
            Some("x86_64-macos".to_owned()),
        );
        expected.insert(
            "dep-c".to_string(),
            WithOriginalConfigurations {
                value: "c".to_owned(),
                original_configurations: Some(BTreeSet::from(["cfg(x86_64)".to_owned()])),
            },
            Some("x86_64-macos".to_owned()),
        );
        expected.insert(
            "dep-a".to_string(),
            WithOriginalConfigurations {
                value: "a".to_owned(),
                original_configurations: Some(BTreeSet::from(["cfg(macos)".to_owned()])),
            },
            Some("aarch64-macos".to_owned()),
        );
        expected.insert(
            "dep-b".to_string(),
            WithOriginalConfigurations {
                value: "b".to_owned(),
                original_configurations: Some(BTreeSet::from(["cfg(macos)".to_owned()])),
            },
            Some("aarch64-macos".to_owned()),
        );
        expected.insert(
            "dep-a".to_string(),
            WithOriginalConfigurations {
                value: "a".to_owned(),
                original_configurations: Some(BTreeSet::from(["cfg(x86_64)".to_owned()])),
            },
            Some("x86_64-linux".to_owned()),
        );
        expected.insert(
            "dep-c".to_string(),
            WithOriginalConfigurations {
                value: "c".to_owned(),
                original_configurations: Some(BTreeSet::from(["cfg(x86_64)".to_owned()])),
            },
            Some("x86_64-linux".to_owned()),
        );
        expected.insert(
            "dep-d".to_string(),
            WithOriginalConfigurations {
                value: "d".to_owned(),
                original_configurations: None,
            },
            None,
        );
        expected.unmapped.insert(
            "dep-e".to_string(),
            WithOriginalConfigurations {
                value: "e".to_owned(),
                original_configurations: Some(BTreeSet::from(["cfg(pdp11)".to_owned()])),
            },
        );
        expected.insert(
            "dep-f".to_string(),
            WithOriginalConfigurations {
                value: "f".to_owned(),
                original_configurations: Some(BTreeSet::from(["@platforms//os:magic".to_owned()])),
            },
            Some("@platforms//os:magic".to_owned()),
        );
        expected.insert(
            "dep-g".to_string(),
            WithOriginalConfigurations {
                value: "g".to_owned(),
                original_configurations: Some(BTreeSet::from(["//another:platform".to_owned()])),
            },
            Some("//another:platform".to_owned()),
        );

        let select_dict = select_dict.remap_configurations(&mapping);
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
