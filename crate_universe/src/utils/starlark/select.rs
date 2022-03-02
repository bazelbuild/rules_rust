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
