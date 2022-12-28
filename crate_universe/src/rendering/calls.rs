use std::collections::BTreeSet as Set;

use serde::ser::{SerializeStruct, SerializeTupleStruct, Serializer};
use serde::Serialize;
use serde_starlark::{Error as StarlarkError, FunctionCall, MULTILINE, ONELINE};

#[derive(Serialize)]
#[serde(untagged)]
pub enum Starlark {
    Package(Package),
    ExportsFiles(ExportsFiles),
    Filegroup(Filegroup),
    Alias(Alias),

    #[serde(skip_serializing)]
    Comment(String),
}

pub struct Package {
    pub default_visibility: Set<String>,
}

pub struct ExportsFiles {
    pub paths: Set<String>,
    pub globs: Glob,
}

#[derive(Serialize)]
#[serde(rename = "filegroup")]
pub struct Filegroup {
    pub name: String,
    pub srcs: Glob,
}

#[derive(Serialize)]
#[serde(rename = "glob")]
pub struct Glob(pub Set<String>);

#[derive(Serialize)]
#[serde(rename = "alias")]
pub struct Alias {
    pub name: String,
    pub actual: String,
    pub tags: Set<String>,
}

pub fn serialize(starlark: &[Starlark]) -> Result<String, StarlarkError> {
    let mut content = String::new();
    for call in starlark {
        if !content.is_empty() {
            content.push('\n');
        }
        if let Starlark::Comment(comment) = call {
            content.push_str(comment);
        } else {
            content.push_str(&serde_starlark::to_string(call)?);
        }
    }
    Ok(content)
}

impl Package {
    pub fn default_visibility_public() -> Self {
        let mut default_visibility = Set::new();
        default_visibility.insert("//visibility:public".to_owned());
        Package { default_visibility }
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
