use serde::ser::{SerializeSeq, SerializeStruct, SerializeTupleStruct, Serializer};
use serde::Serialize;
use serde_starlark::{FunctionCall, MULTILINE, ONELINE};

use super::{
    Data, ExportsFiles, Load, Package, RustBinary, RustLibrary, RustProcMacro, SelectList,
};

// For structs that contain #[serde(flatten)], a quirk of how Serde processes
// that attribute is that they get serialized as a map, not struct. In Starlark
// unlike in JSON, maps and structs are differently serialized, so we need to
// help fill in the function name or else we'd get a Starlark map instead.
pub fn rust_proc_macro<S>(rule: &RustProcMacro, serializer: S) -> Result<S::Ok, S::Error>
where
    S: Serializer,
{
    FunctionCall::new("rust_proc_macro", rule).serialize(serializer)
}

pub fn rust_library<S>(rule: &RustLibrary, serializer: S) -> Result<S::Ok, S::Error>
where
    S: Serializer,
{
    FunctionCall::new("rust_library", rule).serialize(serializer)
}

pub fn rust_binary<S>(rule: &RustBinary, serializer: S) -> Result<S::Ok, S::Error>
where
    S: Serializer,
{
    FunctionCall::new("rust_binary", rule).serialize(serializer)
}

// Serialize an array with each element on its own line, even if there is just a
// single element which serde_starlark would ordinarily place on the same line
// as the array brackets.
pub struct MultilineArray<'a, A>(pub &'a A);

impl<'a, A, T> Serialize for MultilineArray<'a, A>
where
    &'a A: IntoIterator<Item = &'a T>,
    T: Serialize + 'a,
{
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        let mut array = serializer.serialize_seq(Some(serde_starlark::MULTILINE))?;
        for element in self.0 {
            array.serialize_element(element)?;
        }
        array.end()
    }
}

// TODO: This can go away after SelectList's derived Serialize impl (used by
// tera) goes away and `serialize_starlark` becomes its real Serialize impl.
#[derive(Serialize)]
#[serde(transparent)]
pub struct SelectListWrapper<'a, T: Ord + Serialize>(
    #[serde(serialize_with = "SelectList::serialize_starlark")] &'a SelectList<T>,
);

impl Serialize for Load {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        let line = if self.items.len() > 1 {
            MULTILINE
        } else {
            ONELINE
        };
        let mut call = serializer.serialize_tuple_struct("load", line)?;
        call.serialize_field(&self.bzl)?;
        for item in &self.items {
            call.serialize_field(item)?;
        }
        call.end()
    }
}

impl Serialize for Package {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        let mut call = serializer.serialize_struct("package", ONELINE)?;
        call.serialize_field("default_visibility", &self.default_visibility)?;
        call.end()
    }
}

impl Serialize for ExportsFiles {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        let mut call = serializer.serialize_tuple_struct("exports_files", MULTILINE)?;
        call.serialize_field(&FunctionCall::new("+", (&self.paths, &self.globs)))?;
        call.end()
    }
}

impl Data {
    pub fn is_empty(&self) -> bool {
        self.glob.is_empty() && self.select.is_empty()
    }
}

impl Serialize for Data {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        let mut plus = serializer.serialize_tuple_struct("+", MULTILINE)?;
        if !self.glob.is_empty() {
            plus.serialize_field(&self.glob)?;
        }
        if !self.select.is_empty() || self.glob.is_empty() {
            plus.serialize_field(&SelectListWrapper(&self.select))?;
        }
        plus.end()
    }
}
