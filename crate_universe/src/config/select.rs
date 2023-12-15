use std::collections::{BTreeMap, BTreeSet};
use std::fmt::Debug;

use serde::{de::DeserializeOwned, Deserialize, Deserializer, Serialize};

#[derive(Debug, Default, Clone, PartialEq, Eq, Serialize)]
pub struct Select<T>
where
    T: SelectValue,
{
    pub common: T,
    pub selects: BTreeMap<String, T>,
}

pub trait SelectValue
where
    Self: Debug + Default + Clone + PartialEq + Eq + Serialize + DeserializeOwned,
{
    fn merge(lhs: Select<Self>, rhs: Select<Self>) -> Select<Self>;
}

impl<T> Select<T>
where
    T: SelectValue,
{
    pub fn merge(lhs: Self, rhs: Self) -> Self {
        SelectValue::merge(lhs, rhs)
    }
}

impl<T> From<T> for Select<T>
where
    T: SelectValue,
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
    T: SelectValue,
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
    T: SelectValue,
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

impl SelectValue for String {
    fn merge(lhs: Select<String>, rhs: Select<String>) -> Select<String> {
        let mut result: Select<String> = Select::default();
        if !lhs.common.is_empty() {
            result.common = lhs.common;
        }
        if !rhs.common.is_empty() {
            result.common = rhs.common;
        }
        for (cfg, value) in lhs.selects.into_iter() {
            let entry = result.selects.entry(cfg).or_default();
            *entry = value;
        }
        for (cfg, value) in rhs.selects.into_iter() {
            let entry = result.selects.entry(cfg).or_default();
            *entry = value;
        }
        result
    }
}

impl<T> SelectValue for Vec<T>
where
    T: Debug + Clone + PartialEq + Eq + Serialize + DeserializeOwned,
{
    fn merge(lhs: Select<Vec<T>>, rhs: Select<Vec<T>>) -> Select<Vec<T>> {
        let mut result: Select<Vec<T>> = Select::default();
        for value in lhs.common.into_iter() {
            result.common.push(value);
        }
        for value in rhs.common.into_iter() {
            result.common.push(value);
        }
        for (cfg, values) in lhs.selects.into_iter() {
            let entry = result.selects.entry(cfg).or_default();
            for value in values.into_iter() {
                entry.push(value);
            }
        }
        for (cfg, values) in rhs.selects.into_iter() {
            let entry = result.selects.entry(cfg).or_default();
            for value in values.into_iter() {
                entry.push(value);
            }
        }
        result
    }
}

impl<T> SelectValue for BTreeSet<T>
where
    T: Debug + Clone + PartialEq + Eq + PartialOrd + Ord + Serialize + DeserializeOwned,
{
    fn merge(lhs: Select<BTreeSet<T>>, rhs: Select<BTreeSet<T>>) -> Select<BTreeSet<T>> {
        let mut result: Select<BTreeSet<T>> = Select::default();
        for value in lhs.common.into_iter() {
            result.common.insert(value);
        }
        for value in rhs.common.into_iter() {
            result.common.insert(value);
        }
        for (cfg, values) in lhs.selects.into_iter() {
            let entry = result.selects.entry(cfg).or_default();
            for value in values
                .into_iter()
                .filter(|value| !result.common.contains(value))
            {
                entry.insert(value);
            }
        }
        for (cfg, values) in rhs.selects.into_iter() {
            let entry = result.selects.entry(cfg).or_default();
            for value in values
                .into_iter()
                .filter(|value| !result.common.contains(value))
            {
                entry.insert(value);
            }
        }
        result
    }
}

impl<T> SelectValue for BTreeMap<String, T>
where
    T: Debug + Clone + PartialEq + Eq + PartialOrd + Ord + Serialize + DeserializeOwned,
{
    fn merge(
        lhs: Select<BTreeMap<String, T>>,
        rhs: Select<BTreeMap<String, T>>,
    ) -> Select<BTreeMap<String, T>> {
        let mut result: Select<BTreeMap<String, T>> = Select::default();
        for (key, value) in lhs.common.into_iter() {
            result.common.insert(key, value);
        }
        for (key, value) in rhs.common.into_iter() {
            result.common.insert(key, value);
        }
        for (cfg, entries) in lhs.selects.into_iter() {
            let entry = result.selects.entry(cfg).or_default();
            for (key, value) in entries
                .into_iter()
                .filter(|(key, _)| !result.common.contains_key(key))
            {
                entry.insert(key, value);
            }
        }
        for (cfg, entries) in rhs.selects.into_iter() {
            let entry = result.selects.entry(cfg).or_default();
            for (key, value) in entries
                .into_iter()
                .filter(|(key, _)| !result.common.contains_key(key))
            {
                entry.insert(key, value);
            }
        }
        result
    }
}
