use super::{ExportsFiles, Package};
use serde::ser::{Serialize, SerializeStruct, SerializeTupleStruct, Serializer};
use serde_starlark::{FunctionCall, MULTILINE, ONELINE};

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
