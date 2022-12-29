use super::generator::{stringify, JsonGenerateResult};
use std::collections::HashMap;
use std::convert::TryInto;
use std::error;
use std::fmt;
use std::ops::{Index, IndexMut};

const NULL: () = ();

#[derive(Debug, Clone, PartialEq)]
pub enum JsonValue {
    Number(f64),
    Boolean(bool),
    String(String),
    Null,
    Array(Vec<JsonValue>),
    Object(HashMap<String, JsonValue>),
}

pub trait InnerAsRef {
    fn json_value_as(v: &JsonValue) -> Option<&Self>;
}

macro_rules! impl_inner_ref {
    ($to:ty, $pat:pat => $val:expr) => {
        impl InnerAsRef for $to {
            fn json_value_as(v: &JsonValue) -> Option<&$to> {
                use JsonValue::*;
                match v {
                    $pat => Some($val),
                    _ => None,
                }
            }
        }
    };
}

impl_inner_ref!(f64, Number(n) => n);
impl_inner_ref!(bool, Boolean(b) => b);
impl_inner_ref!(String, String(s) => s);
impl_inner_ref!((), Null => &NULL);
impl_inner_ref!(Vec<JsonValue>, Array(a) => a);
impl_inner_ref!(HashMap<String, JsonValue>, Object(h) => h);

pub trait InnerAsRefMut {
    fn json_value_as_mut(v: &mut JsonValue) -> Option<&mut Self>;
}

macro_rules! impl_inner_ref_mut {
    ($to:ty, $pat:pat => $val:expr) => {
        impl InnerAsRefMut for $to {
            fn json_value_as_mut(v: &mut JsonValue) -> Option<&mut $to> {
                use JsonValue::*;
                match v {
                    $pat => Some($val),
                    _ => None,
                }
            }
        }
    };
}

impl_inner_ref_mut!(f64, Number(n) => n);
impl_inner_ref_mut!(bool, Boolean(b) => b);
impl_inner_ref_mut!(String, String(s) => s);
impl_inner_ref_mut!(Vec<JsonValue>, Array(a) => a);
impl_inner_ref_mut!(HashMap<String, JsonValue>, Object(h) => h);

// Note: matches! is available from Rust 1.42
macro_rules! is_xxx {
    ($name:ident, $variant:pat) => {
        pub fn $name(&self) -> bool {
            match self {
                $variant => true,
                _ => false,
            }
        }
    };
}

impl JsonValue {
    pub fn get<T: InnerAsRef>(&self) -> Option<&T> {
        T::json_value_as(self)
    }

    pub fn get_mut<T: InnerAsRefMut>(&mut self) -> Option<&mut T> {
        T::json_value_as_mut(self)
    }

    is_xxx!(is_bool, JsonValue::Boolean(_));
    is_xxx!(is_number, JsonValue::Number(_));
    is_xxx!(is_string, JsonValue::String(_));
    is_xxx!(is_null, JsonValue::Null);
    is_xxx!(is_array, JsonValue::Array(_));
    is_xxx!(is_object, JsonValue::Object(_));

    pub fn stringify(&self) -> JsonGenerateResult {
        stringify(self)
    }
}

impl<'a> Index<&'a str> for JsonValue {
    type Output = JsonValue;

    fn index(&self, key: &'a str) -> &Self::Output {
        let obj = match self {
            JsonValue::Object(o) => o,
            _ => panic!(
                "Attempted to access to an object with key '{}' but actually it was {:?}",
                key, self
            ),
        };

        match obj.get(key) {
            Some(json) => json,
            None => panic!("Key '{}' was not found in {:?}", key, self),
        }
    }
}

impl Index<usize> for JsonValue {
    type Output = JsonValue;

    fn index(&self, index: usize) -> &'_ Self::Output {
        let array = match self {
            JsonValue::Array(a) => a,
            _ => panic!(
                "Attempted to access to an array with index {} but actually the value was {:?}",
                index, self,
            ),
        };
        &array[index]
    }
}

impl<'a> IndexMut<&'a str> for JsonValue {
    fn index_mut(&mut self, key: &'a str) -> &mut Self::Output {
        let obj = match self {
            JsonValue::Object(o) => o,
            _ => panic!(
                "Attempted to access to an object with key '{}' but actually it was {:?}",
                key, self
            ),
        };

        if let Some(json) = obj.get_mut(key) {
            json
        } else {
            panic!("Key '{}' was not found in object", key)
        }
    }
}

impl IndexMut<usize> for JsonValue {
    fn index_mut(&mut self, index: usize) -> &mut Self::Output {
        let array = match self {
            JsonValue::Array(a) => a,
            _ => panic!(
                "Attempted to access to an array with index {} but actually the value was {:?}",
                index, self,
            ),
        };

        &mut array[index]
    }
}

#[derive(Debug)]
pub struct UnexpectedValue {
    value: JsonValue,
    expected: &'static str,
}

impl fmt::Display for UnexpectedValue {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "Unexpected JSON value: {:?}. Expected {} value",
            self.value, self.expected
        )
    }
}

impl error::Error for UnexpectedValue {}

macro_rules! impl_try_into {
    ($ty:ty, $pat:pat => $val:expr) => {
        impl TryInto<$ty> for JsonValue {
            type Error = UnexpectedValue;

            fn try_into(self) -> Result<$ty, UnexpectedValue> {
                match self {
                    $pat => Ok($val),
                    v => Err(UnexpectedValue {
                        value: v,
                        expected: stringify!($ty),
                    }),
                }
            }
        }
    };
}

impl_try_into!(f64, JsonValue::Number(n) => n);
impl_try_into!(bool, JsonValue::Boolean(b) => b);
impl_try_into!(String, JsonValue::String(s) => s);
impl_try_into!((), JsonValue::Null => ());
impl_try_into!(Vec<JsonValue>, JsonValue::Array(a) => a);
impl_try_into!(HashMap<String, JsonValue>, JsonValue::Object(o) => o);
