//! A module for representations of starlark constructs

mod glob;
mod label;
mod select;
mod serialize;

use std::collections::BTreeSet as Set;

use serde::Serialize;
use serde_starlark::Error as StarlarkError;

pub use glob::*;
pub use label::*;
pub use select::*;

pub type SelectStringList = SelectList<String>;
pub type SelectStringDict = SelectDict<String>;

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
#[serde(rename = "alias")]
pub struct Alias {
    pub name: String,
    pub actual: String,
    pub tags: Set<String>,
}

impl Package {
    pub fn default_visibility_public() -> Self {
        let mut default_visibility = Set::new();
        default_visibility.insert("//visibility:public".to_owned());
        Package { default_visibility }
    }
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
