use serde::{Deserialize, Serialize};
use std::collections::{btree_set, BTreeMap, BTreeSet};
use std::iter::once;

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

#[derive(Debug, PartialEq, Eq, PartialOrd, Ord, Deserialize, Serialize, Clone)]
pub struct SelectList<T: Ord> {
    common: BTreeSet<T>,
    selects: BTreeMap<String, BTreeSet<T>>,
}

impl<T: Ord> Default for SelectList<T> {
    fn default() -> Self {
        Self {
            common: BTreeSet::new(),
            selects: BTreeMap::new(),
        }
    }
}

impl<T: Ord> SelectList<T> {
    // TODO: This should probably be added to the [Select] trait
    pub fn insert(&mut self, value: T, configuration: Option<String>) {
        match configuration {
            None => {
                self.common.insert(value);
            }
            Some(cfg) => {
                match self.selects.get_mut(&cfg) {
                    None => {
                        let mut set = BTreeSet::new();
                        set.insert(value);
                        self.selects.insert(cfg, set);
                    }
                    Some(set) => {
                        set.insert(value);
                    }
                };
            }
        };
    }

    // TODO: This should probably be added to the [Select] trait
    pub fn get_iter<'a>(&'a self, config: Option<&String>) -> Option<btree_set::Iter<T>> {
        match config {
            Some(conf) => self.selects.get(conf).map(|set| set.iter()),
            None => Some(self.common.iter()),
        }
    }

    /// Determine whether or not the select should be serialized
    pub fn should_skip_serializing(&self) -> bool {
        self.common.is_empty() && self.selects.is_empty()
    }
}

#[derive(Debug, PartialEq, Eq, PartialOrd, Ord, Deserialize, Serialize, Clone)]
pub struct WithOriginalConfigurations<T> {
    value: T,
    original_configurations: BTreeSet<Option<String>>,
}

impl<T: Ord + Clone> SelectList<T> {
    /// Generates a new SelectList re-keyed by the given configuration mapping.
    /// This mapping maps from configurations in the current SelectList to sets of
    /// configurations in the new SelectList.
    ///
    /// This returns the new SelectList as well as a BTreeMap of unmapped select configurations.
    pub fn remap_configurations<'a, I, S>(
        &self,
        mapping: &'a BTreeMap<String, I>,
    ) -> (
        SelectList<WithOriginalConfigurations<T>>,
        BTreeMap<String, BTreeSet<T>>,
    )
    where
        &'a I: IntoIterator<Item = S>,
        S: AsRef<str>,
    {
        // Map new configuraiton -> value -> old configurations.
        let mut remapped: BTreeMap<String, BTreeMap<T, BTreeSet<Option<String>>>> = BTreeMap::new();
        let mut unmapped: BTreeMap<String, BTreeSet<T>> = BTreeMap::new();

        for (original_configuration, values) in &self.selects {
            match mapping.get(original_configuration) {
                Some(configurations) => {
                    for configuration in configurations {
                        for value in values {
                            remapped
                                .entry(configuration.as_ref().to_owned())
                                .or_default()
                                .entry(value.clone())
                                .or_default()
                                .insert(Some(original_configuration.to_owned()));
                        }
                    }
                }
                None => unmapped
                    .entry(original_configuration.clone())
                    .or_default()
                    .append(&mut values.clone()),
            }
        }
        for value in &self.common {
            for (_, value_to_configs) in remapped.iter_mut() {
                value_to_configs
                    .entry(value.clone())
                    .or_default()
                    .insert(None);
            }
        }
        (
            SelectList {
                common: self
                    .common
                    .iter()
                    .map(|value| WithOriginalConfigurations {
                        value: value.clone(),
                        original_configurations: BTreeSet::from([None]),
                    })
                    .collect(),
                selects: remapped
                    .into_iter()
                    .map(|(new_configuration, value_to_original_configuration)| {
                        (
                            new_configuration,
                            value_to_original_configuration
                                .into_iter()
                                .map(|(value, original_configurations)| {
                                    WithOriginalConfigurations {
                                        value,
                                        original_configurations,
                                    }
                                })
                                .collect(),
                        )
                    })
                    .collect(),
            },
            unmapped,
        )
    }
}

impl<T: Ord> Select<T> for SelectList<T> {
    fn configurations(&self) -> BTreeSet<Option<&String>> {
        let configs = self.selects.keys().map(Some);
        match self.common.is_empty() {
            true => configs.collect(),
            false => configs.chain(once(None)).collect(),
        }
    }
}

impl<T: Ord, U: Ord> SelectMap<T, U> for SelectList<T> {
    type Mapped = SelectList<U>;

    fn map<F: Copy + Fn(T) -> U>(self, func: F) -> Self::Mapped {
        SelectList {
            common: self.common.into_iter().map(func).collect(),
            selects: self
                .selects
                .into_iter()
                .map(|(key, map)| (key, map.into_iter().map(func).collect()))
                .collect(),
        }
    }
}

#[derive(Debug, PartialEq, Eq, PartialOrd, Ord, Deserialize, Serialize, Clone)]
pub struct SelectDict<T: Ord> {
    common: BTreeMap<String, T>,
    selects: BTreeMap<String, BTreeMap<String, T>>,
}

impl<T: Ord> Default for SelectDict<T> {
    fn default() -> Self {
        Self {
            common: BTreeMap::new(),
            selects: BTreeMap::new(),
        }
    }
}

impl<T: Ord> SelectDict<T> {
    // TODO: This should probably be added to the [Select] trait
    pub fn insert(&mut self, value: BTreeMap<String, T>, configuration: Option<String>) {
        match configuration {
            None => {
                self.common.extend(value);
            }
            Some(cfg) => {
                match self.selects.get_mut(&cfg) {
                    None => {
                        let mut set = BTreeMap::new();
                        set.extend(value);
                        self.selects.insert(cfg, set);
                    }
                    Some(set) => {
                        set.extend(value);
                    }
                };
            }
        };
    }

    /// Determine whether or not the select should be serialized
    pub fn should_skip_serializing(&self) -> bool {
        self.common.is_empty() && self.selects.is_empty()
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

impl<T: Ord, U: Ord> SelectMap<T, U> for SelectDict<T> {
    type Mapped = SelectDict<U>;

    fn map<F: Copy + Fn(T) -> U>(self, func: F) -> Self::Mapped {
        SelectDict {
            common: self
                .common
                .into_iter()
                .map(|(key, val)| (key, func(val)))
                .collect(),
            selects: self
                .selects
                .into_iter()
                .map(|(key, map)| (key, map.into_iter().map(|(k, v)| (k, func(v))).collect()))
                .collect(),
        }
    }
}

#[cfg(test)]
mod test {
    use super::*;

    #[test]
    fn remap_select_list_configurations() {
        let mut select_list = SelectList::default();
        select_list.insert("dep-a".to_owned(), Some("cfg(macos)".to_owned()));
        select_list.insert("dep-b".to_owned(), Some("cfg(macos)".to_owned()));
        select_list.insert("dep-d".to_owned(), Some("cfg(macos)".to_owned()));
        select_list.insert("dep-a".to_owned(), Some("cfg(x86_64)".to_owned()));
        select_list.insert("dep-c".to_owned(), Some("cfg(x86_64)".to_owned()));
        select_list.insert("dep-e".to_owned(), Some("cfg(pdp11)".to_owned()));
        select_list.insert("dep-d".to_owned(), None);

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

        let mut expected = SelectList::default();
        expected.insert(
            WithOriginalConfigurations {
                value: "dep-a".to_owned(),
                original_configurations: BTreeSet::from([
                    Some("cfg(macos)".to_owned()),
                    Some("cfg(x86_64)".to_owned()),
                ]),
            },
            Some("x86_64-macos".to_owned()),
        );
        expected.insert(
            WithOriginalConfigurations {
                value: "dep-b".to_owned(),
                original_configurations: BTreeSet::from([Some("cfg(macos)".to_owned())]),
            },
            Some("x86_64-macos".to_owned()),
        );
        expected.insert(
            WithOriginalConfigurations {
                value: "dep-c".to_owned(),
                original_configurations: BTreeSet::from([Some("cfg(x86_64)".to_owned())]),
            },
            Some("x86_64-macos".to_owned()),
        );
        expected.insert(
            WithOriginalConfigurations {
                value: "dep-d".to_owned(),
                original_configurations: BTreeSet::from([None, Some("cfg(macos)".to_owned())]),
            },
            Some("x86_64-macos".to_owned()),
        );

        expected.insert(
            WithOriginalConfigurations {
                value: "dep-a".to_owned(),
                original_configurations: BTreeSet::from([Some("cfg(macos)".to_owned())]),
            },
            Some("aarch64-macos".to_owned()),
        );
        expected.insert(
            WithOriginalConfigurations {
                value: "dep-b".to_owned(),
                original_configurations: BTreeSet::from([Some("cfg(macos)".to_owned())]),
            },
            Some("aarch64-macos".to_owned()),
        );
        expected.insert(
            WithOriginalConfigurations {
                value: "dep-d".to_owned(),
                original_configurations: BTreeSet::from([None, Some("cfg(macos)".to_owned())]),
            },
            Some("aarch64-macos".to_owned()),
        );

        expected.insert(
            WithOriginalConfigurations {
                value: "dep-a".to_owned(),
                original_configurations: BTreeSet::from([Some("cfg(x86_64)".to_owned())]),
            },
            Some("x86_64-linux".to_owned()),
        );
        expected.insert(
            WithOriginalConfigurations {
                value: "dep-c".to_owned(),
                original_configurations: BTreeSet::from([Some("cfg(x86_64)".to_owned())]),
            },
            Some("x86_64-linux".to_owned()),
        );
        expected.insert(
            WithOriginalConfigurations {
                value: "dep-d".to_owned(),
                original_configurations: BTreeSet::from([None]),
            },
            Some("x86_64-linux".to_owned()),
        );

        expected.insert(
            WithOriginalConfigurations {
                value: "dep-d".to_owned(),
                original_configurations: BTreeSet::from([None]),
            },
            None,
        );

        let expected_unmapped = BTreeMap::from([(
            "cfg(pdp11)".to_owned(),
            BTreeSet::from(["dep-e".to_owned()]),
        )]);

        assert_eq!(
            &select_list.remap_configurations(&mapping),
            &(expected, expected_unmapped)
        );
    }
}
