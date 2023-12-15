use std::collections::{BTreeMap, BTreeSet};
use std::fmt::Debug;

use serde::ser::{SerializeMap, Serializer};
use serde::Serialize;
use serde_starlark::{FunctionCall, MULTILINE};

use crate::select::{Select, SelectableScalar};
use crate::utils::starlark::serialize::MultilineArray;
use crate::utils::starlark::{
    looks_like_bazel_configuration_label, NoMatchingPlatformTriples, WithOriginalConfigurations,
};

#[derive(Debug, PartialEq, Eq)]
pub struct SelectValue<T>
where
    T: SelectableScalar,
{
    common: Option<T>,
    selects: BTreeMap<String, WithOriginalConfigurations<T>>,
    // Element that used to be in `selects` before the most recent
    // `remap_configurations` operation, but whose old configuration did not get
    // mapped to any new configuration. This could be ignored, but are preserved
    // here to generate comments that help the user understand what happened.
    unmapped: Vec<WithOriginalConfigurations<T>>,
}

impl<T> SelectValue<T>
where
    T: SelectableScalar,
{
    /// Re-keys the provided Select by the given configuration mapping.
    /// This mapping maps from configurations in the input Select to sets of
    /// configurations in the output SelectValue.
    pub fn new(select: Select<T>, platforms: &BTreeMap<String, BTreeSet<String>>) -> Self {
        let (common, selects) = select.into_parts();

        // Map new configuration -> value -> old configurations.
        // let mut remapped: BTreeMap<String, (T, BTreeSet<String>)> = BTreeMap::new();
        let mut remapped: BTreeMap<String, (T, BTreeSet<String>)> = BTreeMap::new();
        // Map value -> old configurations.
        let mut unmapped: BTreeMap<T, BTreeSet<String>> = BTreeMap::new();

        for (original_configuration, value) in selects {
            match platforms.get(&original_configuration) {
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

        Self {
            common,
            selects: remapped
                .into_iter()
                .map(|(new_configuration, (value, original_configurations))| {
                    (
                        new_configuration,
                        WithOriginalConfigurations {
                            value,
                            original_configurations,
                        },
                    )
                })
                .collect(),
            unmapped: unmapped
                .into_iter()
                .map(
                    |(value, original_configurations)| WithOriginalConfigurations {
                        value,
                        original_configurations,
                    },
                )
                .collect(),
        }
    }

    /// Determine whether or not the select should be serialized
    pub fn is_empty(&self) -> bool {
        self.common.is_none() && self.selects.is_empty() && self.unmapped.is_empty()
    }
}

impl<T> Serialize for SelectValue<T>
where
    T: SelectableScalar,
{
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        // If there are no platform-specific entries, we output just an ordinary
        // value.
        //
        // If there are platform-specific ones, we use the following.
        //
        //     select({
        //         "configuration": "plat-value",  # cfg(whatever),
        //         "//conditions:default": "common-value",
        //     })
        //
        // If there are unmapped entries, we include them like this:
        //
        //     selects.with_unmapped({
        //         "configuration": "plat-value",  # cfg(whatever),
        //         "//conditions:default": "common-value",
        //         selects.NO_MATCHING_PLATFORM_TRIPLES: [
        //             "unmapped-value",  # cfg(obscure)
        //         ],
        //     })

        if self.common.is_some() && self.selects.is_empty() && self.unmapped.is_empty() {
            return self.common.as_ref().unwrap().serialize(serializer);
        }

        struct SelectInner<'a, T>(&'a SelectValue<T>)
        where
            T: SelectableScalar;

        impl<'a, T> Serialize for SelectInner<'a, T>
        where
            T: SelectableScalar,
        {
            fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
            where
                S: Serializer,
            {
                let mut map = serializer.serialize_map(Some(MULTILINE))?;
                for (configuration, value) in &self.0.selects {
                    map.serialize_entry(configuration, value)?;
                }
                if let Some(common) = self.0.common.as_ref() {
                    map.serialize_entry("//conditions:default", common)?;
                }
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

        FunctionCall::new(function, [SelectInner(self)]).serialize(serializer)
    }
}

#[cfg(test)]
mod test {
    use super::*;

    use indoc::indoc;

    #[test]
    fn empty_select_value() {
        let select_value: SelectValue<String> =
            SelectValue::new(Default::default(), &Default::default());

        let expected_starlark = indoc! {r#"
            select({})
        "#};

        assert_eq!(
            select_value.serialize(serde_starlark::Serializer).unwrap(),
            expected_starlark,
        );
    }

    #[test]
    fn no_platform_specific_select_value() {
        let mut select: Select<String> = Select::default();
        select.set("Hello".to_owned(), None);

        let select_value = SelectValue::new(select, &Default::default());

        let expected_starlark = indoc! {r#"
            "Hello"
        "#};

        assert_eq!(
            select_value.serialize(serde_starlark::Serializer).unwrap(),
            expected_starlark,
        );
    }

    #[test]
    fn only_platform_specific_select_value() {
        let mut select: Select<String> = Select::default();
        select.set("Hello".to_owned(), Some("platform".to_owned()));

        let platforms = BTreeMap::from([(
            "platform".to_owned(),
            BTreeSet::from(["platform".to_owned()]),
        )]);

        let select_value = SelectValue::new(select, &platforms);

        let expected_starlark = indoc! {r#"
            select({
                "platform": "Hello",  # platform
            })
        "#};

        assert_eq!(
            select_value.serialize(serde_starlark::Serializer).unwrap(),
            expected_starlark,
        );
    }

    #[test]
    fn mixed_select_value() {
        let mut select: Select<String> = Select::default();
        select.set("Hello".to_owned(), Some("platform".to_owned()));
        select.set("Goodbye".to_owned(), None);

        let platforms = BTreeMap::from([(
            "platform".to_owned(),
            BTreeSet::from(["platform".to_owned()]),
        )]);

        let select_value = SelectValue::new(select, &platforms);

        let expected_starlark = indoc! {r#"
            select({
                "platform": "Hello",  # platform
                "//conditions:default": "Goodbye",
            })
        "#};

        assert_eq!(
            select_value.serialize(serde_starlark::Serializer).unwrap(),
            expected_starlark,
        );
    }

    #[test]
    fn remap_select_value_configurations() {
        let mut select: Select<String> = Select::default();
        select.set("a".to_owned(), Some("cfg(macos)".to_owned()));
        select.set("a".to_owned(), Some("cfg(x86_64)".to_owned()));
        select.set("e".to_owned(), Some("cfg(pdp11)".to_owned()));
        select.set("f".to_owned(), Some("@platforms//os:magic".to_owned()));
        select.set("g".to_owned(), Some("//another:platform".to_owned()));

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

        let select_value = SelectValue::new(select, &platforms);

        let expected = SelectValue {
            common: None,
            selects: BTreeMap::from([
                (
                    "x86_64-macos".to_owned(),
                    WithOriginalConfigurations {
                        value: "a".to_owned(),
                        original_configurations: BTreeSet::from([
                            "cfg(macos)".to_owned(),
                            "cfg(x86_64)".to_owned(),
                        ]),
                    },
                ),
                (
                    "aarch64-macos".to_owned(),
                    WithOriginalConfigurations {
                        value: "a".to_owned(),
                        original_configurations: BTreeSet::from(["cfg(macos)".to_owned()]),
                    },
                ),
                (
                    "x86_64-linux".to_owned(),
                    WithOriginalConfigurations {
                        value: "a".to_owned(),
                        original_configurations: BTreeSet::from(["cfg(x86_64)".to_owned()]),
                    },
                ),
                (
                    "@platforms//os:magic".to_owned(),
                    WithOriginalConfigurations {
                        value: "f".to_owned(),
                        original_configurations: BTreeSet::from(
                            ["@platforms//os:magic".to_owned()],
                        ),
                    },
                ),
                (
                    "//another:platform".to_owned(),
                    WithOriginalConfigurations {
                        value: "g".to_owned(),
                        original_configurations: BTreeSet::from(["//another:platform".to_owned()]),
                    },
                ),
            ]),
            unmapped: Vec::from([WithOriginalConfigurations {
                value: "e".to_owned(),
                original_configurations: BTreeSet::from(["cfg(pdp11)".to_owned()]),
            }]),
        };

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
            select_value.serialize(serde_starlark::Serializer).unwrap(),
            expected_starlark,
        );
    }
}
