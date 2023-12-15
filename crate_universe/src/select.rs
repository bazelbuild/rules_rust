use std::collections::{BTreeMap, BTreeSet};
use std::fmt::Debug;

use serde::{de::DeserializeOwned, Deserialize, Deserializer, Serialize};

#[derive(Debug, Default, Clone, PartialEq, Eq, Serialize)]
pub struct Select<T> {
    common: T,
    selects: BTreeMap<String, T>,
}

pub trait SelectCommon {
    fn is_empty(&self) -> bool;

    fn merge(lhs: Self, rhs: Self) -> Self;
}

// General
impl<T> Select<T> {
    pub fn common(&self) -> &T {
        &self.common
    }

    pub fn selects(&self) -> &BTreeMap<String, T> {
        &self.selects
    }

    pub fn into_parts(self) -> (T, BTreeMap<String, T>) {
        (self.common, self.selects)
    }
}

impl<T> From<T> for Select<T>
where
    T: Debug + Default + Clone + PartialEq + Eq + Serialize + DeserializeOwned,
{
    fn from(common: T) -> Self {
        Self {
            common: common,
            selects: BTreeMap::new(),
        }
    }
}

impl<T> From<(T, BTreeMap<String, T>)> for Select<T>
where
    T: Debug + Default + Clone + PartialEq + Eq + Serialize + DeserializeOwned,
{
    fn from((common, selects): (T, BTreeMap<String, T>)) -> Self {
        Self {
            common: common,
            selects: selects,
        }
    }
}

impl<'de, T> Deserialize<'de> for Select<T>
where
    T: Debug + Default + Clone + PartialEq + Eq + Serialize + DeserializeOwned,
{
    fn deserialize<D>(deserializer: D) -> Result<Select<T>, D::Error>
    where
        D: Deserializer<'de>,
    {
        #[derive(Debug, Deserialize)]
        #[serde(untagged)]
        enum Either<T> {
            Select {
                common: T,
                selects: BTreeMap<String, T>,
            },
            Value(T),
        }

        let either = Either::deserialize(deserializer)?;
        match either {
            Either::Select { common, selects } => Ok(Select::from((common, selects))),
            Either::Value(common) => Ok(Select::from(common)),
        }
    }
}

// String
impl Select<String> {
    pub fn configurations(&self) -> BTreeSet<Option<&String>> {
        let configs = self.selects.keys().map(Some);
        match self.common.is_empty() {
            true => configs.collect(),
            false => configs.chain(std::iter::once(None)).collect(),
        }
    }

    pub fn set(&mut self, value: String, configuration: Option<String>) {
        match configuration {
            None => {
                self.common = value;
            }
            Some(configuration) => {
                self.selects.insert(configuration, value);
            }
        }
    }
}

impl SelectCommon for Select<String> {
    fn is_empty(&self) -> bool {
        self.common.is_empty() && self.selects.is_empty()
    }

    fn merge(lhs: Self, rhs: Self) -> Self {
        let mut result = Self::default();
        if !lhs.common.is_empty() {
            result.common = lhs.common;
        }
        if !rhs.common.is_empty() {
            result.common = rhs.common;
        }
        for (configuration, value) in lhs.selects.into_iter() {
            let entry = result.selects.entry(configuration).or_default();
            *entry = value;
        }
        for (configuration, value) in rhs.selects.into_iter() {
            let entry = result.selects.entry(configuration).or_default();
            *entry = value;
        }
        result
    }
}

// Vec<T>
impl<T> Select<Vec<T>>
where
    T: Debug + Clone + PartialEq + Eq + Serialize + DeserializeOwned,
{
    pub fn configurations(&self) -> BTreeSet<Option<&String>> {
        let configs = self.selects.keys().map(Some);
        match self.common.is_empty() {
            true => configs.collect(),
            false => configs.chain(std::iter::once(None)).collect(),
        }
    }

    pub fn insert(&mut self, value: T, configuration: Option<String>) {
        match configuration {
            None => self.common.push(value),
            Some(configuration) => self.selects.entry(configuration).or_default().push(value),
        }
    }

    pub fn map<U, F>(self, func: F) -> Select<Vec<U>>
    where
        U: Debug + Clone + PartialEq + Eq + Serialize + DeserializeOwned,
        F: Copy + FnMut(T) -> U,
    {
        Select {
            common: self.common.into_iter().map(func).collect(),
            selects: self
                .selects
                .into_iter()
                .map(|(configuration, values)| {
                    (configuration, values.into_iter().map(func).collect())
                })
                .collect(),
        }
    }
}

impl<T> SelectCommon for Select<Vec<T>>
where
    T: Debug + Clone + PartialEq + Eq + Serialize + DeserializeOwned,
{
    fn is_empty(&self) -> bool {
        self.common.is_empty() && self.selects.is_empty()
    }

    fn merge(lhs: Self, rhs: Self) -> Self {
        let mut result = Self::default();
        for value in lhs.common.into_iter() {
            result.common.push(value);
        }
        for value in rhs.common.into_iter() {
            result.common.push(value);
        }
        for (configuration, values) in lhs.selects.into_iter() {
            let entry = result.selects.entry(configuration).or_default();
            for value in values.into_iter() {
                entry.push(value);
            }
        }
        for (configuration, values) in rhs.selects.into_iter() {
            let entry = result.selects.entry(configuration).or_default();
            for value in values.into_iter() {
                entry.push(value);
            }
        }
        result.selects.retain(|_, values| !values.is_empty());
        result
    }
}

// BTreeSet<T>
impl<T> Select<BTreeSet<T>>
where
    T: Debug + Clone + PartialEq + Eq + PartialOrd + Ord + Serialize + DeserializeOwned,
{
    pub fn configurations(&self) -> BTreeSet<Option<&String>> {
        let configs = self.selects.keys().map(Some);
        match self.common.is_empty() {
            true => configs.collect(),
            false => configs.chain(std::iter::once(None)).collect(),
        }
    }

    pub fn iter(&self) -> impl Iterator<Item = (Option<&String>, &T)> {
        Iterator::chain(
            self.common.iter().map(|value| (None, value)),
            self.selects.iter().flat_map(|(configuration, values)| {
                values.iter().map(move |value| (Some(configuration), value))
            }),
        )
    }

    pub fn values(&self) -> impl Iterator<Item = &T> {
        Iterator::chain(
            self.common.iter(),
            self.selects.values().flat_map(|values| values.iter()),
        )
    }

    pub fn insert(&mut self, value: T, configuration: Option<String>) {
        match configuration {
            None => {
                self.selects.retain(|_, set| {
                    set.remove(&value);
                    !set.is_empty()
                });
                self.common.insert(value);
            }
            Some(configuration) => {
                if !self.common.contains(&value) {
                    self.selects.entry(configuration).or_default().insert(value);
                }
            }
        }
    }

    pub fn map<U, F>(self, func: F) -> Select<BTreeSet<U>>
    where
        U: Debug + Clone + PartialEq + Eq + PartialOrd + Ord + Serialize + DeserializeOwned,
        F: Copy + FnMut(T) -> U,
    {
        Select {
            common: self.common.into_iter().map(func).collect(),
            selects: self
                .selects
                .into_iter()
                .map(|(configuration, values)| {
                    (configuration, values.into_iter().map(func).collect())
                })
                .collect(),
        }
    }
}

impl<T> SelectCommon for Select<BTreeSet<T>>
where
    T: Debug + Clone + PartialEq + Eq + PartialOrd + Ord + Serialize + DeserializeOwned,
{
    fn is_empty(&self) -> bool {
        self.common.is_empty() && self.selects.is_empty()
    }

    fn merge(lhs: Self, rhs: Self) -> Self {
        let mut result = Self::default();
        for value in lhs.common.into_iter() {
            result.common.insert(value);
        }
        for value in rhs.common.into_iter() {
            result.common.insert(value);
        }
        for (configuration, values) in lhs.selects.into_iter() {
            let entry = result.selects.entry(configuration).or_default();
            for value in values
                .into_iter()
                .filter(|value| !result.common.contains(value))
            {
                entry.insert(value);
            }
        }
        for (configuration, values) in rhs.selects.into_iter() {
            let entry = result.selects.entry(configuration).or_default();
            for value in values
                .into_iter()
                .filter(|value| !result.common.contains(value))
            {
                entry.insert(value);
            }
        }
        result.selects.retain(|_, values| !values.is_empty());
        result
    }
}

// BTreeMap<String, T>
impl<T> Select<BTreeMap<String, T>>
where
    T: Debug + Clone + PartialEq + Eq + PartialOrd + Ord + Serialize + DeserializeOwned,
{
    pub fn configurations(&self) -> BTreeSet<Option<&String>> {
        let configs = self.selects.keys().map(Some);
        match self.common.is_empty() {
            true => configs.collect(),
            false => configs.chain(std::iter::once(None)).collect(),
        }
    }

    pub fn insert(&mut self, key: String, value: T, configuration: Option<String>) {
        match configuration {
            None => {
                self.selects.retain(|_, map| {
                    map.remove(&key);
                    !map.is_empty()
                });
                self.common.insert(key, value);
            }
            Some(configuration) => {
                if !self.common.contains_key(&key) {
                    self.selects
                        .entry(configuration)
                        .or_default()
                        .insert(key, value);
                }
            }
        }
    }

    pub fn map<U, F>(self, mut func: F) -> Select<BTreeMap<String, U>>
    where
        U: Debug + Clone + PartialEq + Eq + PartialOrd + Ord + Serialize + DeserializeOwned,
        F: Copy + FnMut(T) -> U,
    {
        Select {
            common: self
                .common
                .into_iter()
                .map(|(key, value)| (key, func(value)))
                .collect(),
            selects: self
                .selects
                .into_iter()
                .map(|(configuration, entries)| {
                    (
                        configuration,
                        entries
                            .into_iter()
                            .map(|(key, value)| (key, func(value)))
                            .collect(),
                    )
                })
                .collect(),
        }
    }
}

impl<T> SelectCommon for Select<BTreeMap<String, T>>
where
    T: Debug + Clone + PartialEq + Eq + PartialOrd + Ord + Serialize + DeserializeOwned,
{
    fn is_empty(&self) -> bool {
        self.common.is_empty() && self.selects.is_empty()
    }

    fn merge(lhs: Self, rhs: Self) -> Self {
        let mut result = Self::default();
        for (key, value) in lhs.common.into_iter() {
            result.common.insert(key, value);
        }
        for (key, value) in rhs.common.into_iter() {
            result.common.insert(key, value);
        }
        for (configuration, entries) in lhs.selects.into_iter() {
            let entry = result.selects.entry(configuration).or_default();
            for (key, value) in entries
                .into_iter()
                .filter(|(key, _)| !result.common.contains_key(key))
            {
                entry.insert(key, value);
            }
        }
        for (configuration, entries) in rhs.selects.into_iter() {
            let entry = result.selects.entry(configuration).or_default();
            for (key, value) in entries
                .into_iter()
                .filter(|(key, _)| !result.common.contains_key(key))
            {
                entry.insert(key, value);
            }
        }
        result.selects.retain(|_, values| !values.is_empty());
        result
    }
}
