use std::collections::{BTreeMap, BTreeSet};
use std::fmt::Debug;

use serde::{de::DeserializeOwned, Deserialize, Deserializer, Serialize};

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct Select<T>
where
    T: Selectable,
{
    common: T::CommonType,
    selects: BTreeMap<String, T::SelectsType>,
}

pub trait Selectable
where
    Self: SelectableValue,
{
    type ItemType: SelectableValue;
    type CommonType: SelectableValue + Default;
    type SelectsType: SelectableValue;

    fn is_empty(this: &Select<Self>) -> bool;
    fn insert(this: &mut Select<Self>, value: Self::ItemType, configuration: Option<String>);

    fn merge(lhs: Select<Self>, rhs: Select<Self>) -> Select<Self>;
}

// Replace with `trait_alias` once stabilized.
// https://github.com/rust-lang/rust/issues/41517
pub trait SelectableValue
where
    Self: Debug + Clone + PartialEq + Eq + PartialOrd + Ord + Serialize + DeserializeOwned,
{
}

impl<T> SelectableValue for T where
    T: Debug + Clone + PartialEq + Eq + PartialOrd + Ord + Serialize + DeserializeOwned
{
}

pub trait SelectableScalar
where
    Self: SelectableValue,
{
}

impl SelectableScalar for String {}
impl SelectableScalar for bool {}
impl SelectableScalar for i64 {}

// General
impl<T> Select<T>
where
    T: Selectable,
{
    pub fn new() -> Self {
        Self {
            common: Default::default(),
            selects: BTreeMap::new(),
        }
    }

    pub fn from_value(value: T::CommonType) -> Self {
        Self {
            common: value,
            selects: BTreeMap::new(),
        }
    }

    pub fn common(&self) -> &T::CommonType {
        &self.common
    }

    pub fn selects(&self) -> &BTreeMap<String, T::SelectsType> {
        &self.selects
    }

    pub fn is_empty(&self) -> bool {
        T::is_empty(&self)
    }

    pub fn into_parts(self) -> (T::CommonType, BTreeMap<String, T::SelectsType>) {
        (self.common, self.selects)
    }

    pub fn configurations(&self) -> impl Iterator<Item = &String> {
        self.selects.keys()
    }

    pub fn insert(&mut self, value: T::ItemType, configuration: Option<String>) {
        T::insert(self, value, configuration);
    }

    pub fn merge(lhs: Self, rhs: Self) -> Self {
        T::merge(lhs, rhs)
    }
}

impl<T> Default for Select<T>
where
    T: Selectable,
{
    fn default() -> Self {
        Self::new()
    }
}

impl<'de, T> Deserialize<'de> for Select<T>
where
    T: Selectable,
{
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: Deserializer<'de>,
    {
        #[derive(Debug, Deserialize)]
        #[serde(untagged)]
        enum Either<T>
        where
            T: Selectable,
        {
            Select {
                common: T::CommonType,
                selects: BTreeMap<String, T::SelectsType>,
            },
            Value(T::CommonType),
        }

        let either = Either::<T>::deserialize(deserializer)?;
        match either {
            Either::Select { common, selects } => Ok(Self { common, selects }),
            Either::Value(common) => Ok(Self {
                common,
                selects: BTreeMap::new(),
            }),
        }
    }
}

// Scalar
impl<T> Selectable for T
where
    T: SelectableScalar,
{
    type ItemType = T;
    type CommonType = Option<T>;
    type SelectsType = T;

    fn is_empty(this: &Select<Self>) -> bool {
        this.common.is_none() && this.selects.is_empty()
    }

    fn insert(this: &mut Select<Self>, value: Self::ItemType, configuration: Option<String>) {
        match configuration {
            None => {
                this.common = Some(value);
                this.selects.retain(|_, value| {
                    this.common
                        .as_ref()
                        .map(|common| value != common)
                        .unwrap_or(true)
                });
            }
            Some(configuration) => {
                if Some(&value) != this.common.as_ref() {
                    this.selects.insert(configuration, value);
                }
            }
        }
    }

    fn merge(lhs: Select<Self>, rhs: Select<Self>) -> Select<Self> {
        let mut result: Select<Self> = Select::new();

        if let Some(value) = lhs.common {
            result.common = Some(value);
        }
        if let Some(value) = rhs.common {
            result.common = Some(value);
        }

        for (configuration, value) in lhs.selects.into_iter().filter(|(_, value)| {
            result
                .common
                .as_ref()
                .map(|common| value != common)
                .unwrap_or(true)
        }) {
            result.selects.insert(configuration, value);
        }
        for (configuration, value) in rhs.selects.into_iter().filter(|(_, value)| {
            result
                .common
                .as_ref()
                .map(|common| value != common)
                .unwrap_or(true)
        }) {
            result.selects.insert(configuration, value);
        }

        result
    }
}

// Vec<T>
impl<T> Selectable for Vec<T>
where
    T: SelectableValue,
{
    type ItemType = T;
    type CommonType = Vec<T>;
    type SelectsType = Vec<T>;

    fn is_empty(this: &Select<Self>) -> bool {
        this.common.is_empty() && this.selects.is_empty()
    }

    fn insert(this: &mut Select<Self>, value: Self::ItemType, configuration: Option<String>) {
        match configuration {
            None => this.common.push(value),
            Some(configuration) => this.selects.entry(configuration).or_default().push(value),
        }
    }

    fn merge(lhs: Select<Self>, rhs: Select<Self>) -> Select<Self> {
        let mut result: Select<Self> = Select::new();

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

impl<T> Select<Vec<T>>
where
    T: SelectableValue,
{
    pub fn map<U, F>(self, func: F) -> Select<Vec<U>>
    where
        U: SelectableValue,
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

// BTreeSet<T>
impl<T> Selectable for BTreeSet<T>
where
    T: SelectableValue,
{
    type ItemType = T;
    type CommonType = BTreeSet<T>;
    type SelectsType = BTreeSet<T>;

    fn is_empty(this: &Select<Self>) -> bool {
        this.common.is_empty() && this.selects.is_empty()
    }

    fn insert(this: &mut Select<Self>, value: Self::ItemType, configuration: Option<String>) {
        match configuration {
            None => {
                this.selects.retain(|_, set| {
                    set.remove(&value);
                    !set.is_empty()
                });
                this.common.insert(value);
            }
            Some(configuration) => {
                if !this.common.contains(&value) {
                    this.selects.entry(configuration).or_default().insert(value);
                }
            }
        }
    }

    fn merge(lhs: Select<Self>, rhs: Select<Self>) -> Select<Self> {
        let mut result: Select<Self> = Select::new();

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

impl<T> Select<BTreeSet<T>>
where
    T: SelectableValue,
{
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

    pub fn map<U, F>(self, func: F) -> Select<BTreeSet<U>>
    where
        U: SelectableValue,
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

// BTreeMap<String, T>
impl<T> Selectable for BTreeMap<String, T>
where
    T: SelectableValue,
{
    type ItemType = (String, T);
    type CommonType = BTreeMap<String, T>;
    type SelectsType = BTreeMap<String, T>;

    fn is_empty(this: &Select<Self>) -> bool {
        this.common.is_empty() && this.selects.is_empty()
    }

    fn insert(
        this: &mut Select<Self>,
        (key, value): Self::ItemType,
        configuration: Option<String>,
    ) {
        match configuration {
            None => {
                this.selects.retain(|_, map| {
                    map.remove(&key);
                    !map.is_empty()
                });
                this.common.insert(key, value);
            }
            Some(configuration) => {
                if !this.common.contains_key(&key) {
                    this.selects
                        .entry(configuration)
                        .or_default()
                        .insert(key, value);
                }
            }
        }
    }

    fn merge(lhs: Select<Self>, rhs: Select<Self>) -> Select<Self> {
        let mut result: Select<Self> = Select::new();

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

impl<T> Select<BTreeMap<String, T>>
where
    T: SelectableValue,
{
    pub fn map<U, F>(self, mut func: F) -> Select<BTreeMap<String, U>>
    where
        U: SelectableValue,
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
