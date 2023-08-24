//! A module for representations of starlark constructs

mod glob;
mod label;
mod select;
mod serialize;
mod target_compatible_with;

use std::collections::BTreeSet as Set;

use serde::{Serialize, Serializer};
use serde_starlark::Error as StarlarkError;

pub use glob::*;
pub use label::*;
pub use select::*;
pub use target_compatible_with::*;

pub type SelectStringList = SelectList<String>;
pub type SelectStringDict = SelectDict<String>;

#[derive(Serialize)]
#[serde(untagged)]
pub enum Starlark {
    Load(Load),
    Package(Package),
    ExportsFiles(ExportsFiles),
    Filegroup(Filegroup),
    Alias(Alias),
    CargoBuildScript(CargoBuildScript),
    #[serde(serialize_with = "serialize::rust_proc_macro")]
    RustProcMacro(RustProcMacro),
    #[serde(serialize_with = "serialize::rust_library")]
    RustLibrary(RustLibrary),
    #[serde(serialize_with = "serialize::rust_binary")]
    RustBinary(RustBinary),

    #[serde(skip_serializing)]
    Verbatim(String),
}

pub struct Load {
    pub bzl: String,
    pub items: Set<String>,
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

#[derive(Serialize)]
#[serde(rename = "cargo_build_script")]
pub struct CargoBuildScript {
    pub name: String,
    #[serde(
        skip_serializing_if = "SelectDict::is_empty",
        serialize_with = "SelectDict::serialize_starlark"
    )]
    pub aliases: SelectDict<WithOriginalConfigurations<String>>,
    #[serde(
        skip_serializing_if = "SelectDict::is_empty",
        serialize_with = "SelectDict::serialize_starlark"
    )]
    pub build_script_env: SelectDict<WithOriginalConfigurations<String>>,
    #[serde(skip_serializing_if = "Data::is_empty")]
    pub compile_data: Data,
    #[serde(
        skip_serializing_if = "SelectList::is_empty",
        serialize_with = "SelectList::serialize_starlark"
    )]
    pub crate_features: SelectList<String>,
    pub crate_name: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub crate_root: Option<String>,
    #[serde(skip_serializing_if = "Data::is_empty")]
    pub data: Data,
    #[serde(
        skip_serializing_if = "SelectList::is_empty",
        serialize_with = "SelectList::serialize_starlark"
    )]
    pub deps: SelectList<WithOriginalConfigurations<String>>,
    #[serde(
        skip_serializing_if = "SelectList::is_empty",
        serialize_with = "SelectList::serialize_starlark"
    )]
    pub link_deps: SelectList<WithOriginalConfigurations<String>>,
    pub edition: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub linker_script: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub links: Option<String>,
    #[serde(
        skip_serializing_if = "SelectList::is_empty",
        serialize_with = "SelectList::serialize_starlark"
    )]
    pub proc_macro_deps: SelectList<WithOriginalConfigurations<String>>,
    #[serde(
        skip_serializing_if = "SelectDict::is_empty",
        serialize_with = "SelectDict::serialize_starlark"
    )]
    pub rustc_env: SelectDict<WithOriginalConfigurations<String>>,
    #[serde(
        skip_serializing_if = "SelectList::is_empty",
        serialize_with = "SelectList::serialize_starlark"
    )]
    pub rustc_env_files: SelectList<WithOriginalConfigurations<String>>,
    #[serde(
        skip_serializing_if = "SelectList::is_empty",
        serialize_with = "SelectList::serialize_starlark"
    )]
    pub rustc_flags: SelectList<WithOriginalConfigurations<String>>,
    pub srcs: Glob,
    #[serde(skip_serializing_if = "Set::is_empty")]
    pub tags: Set<String>,
    #[serde(
        skip_serializing_if = "SelectList::is_empty",
        serialize_with = "SelectList::serialize_starlark"
    )]
    pub tools: SelectList<WithOriginalConfigurations<String>>,
    #[serde(skip_serializing_if = "Set::is_empty")]
    pub toolchains: Set<String>,
    pub version: String,
    pub visibility: Set<String>,
}

#[derive(Serialize)]
pub struct RustProcMacro {
    pub name: String,
    #[serde(
        skip_serializing_if = "SelectList::is_empty",
        serialize_with = "SelectList::serialize_starlark"
    )]
    pub deps: SelectList<WithOriginalConfigurations<String>>,
    #[serde(
        skip_serializing_if = "SelectList::is_empty",
        serialize_with = "SelectList::serialize_starlark"
    )]
    pub proc_macro_deps: SelectList<WithOriginalConfigurations<String>>,
    #[serde(
        skip_serializing_if = "SelectDict::is_empty",
        serialize_with = "SelectDict::serialize_starlark"
    )]
    pub aliases: SelectDict<WithOriginalConfigurations<String>>,
    #[serde(flatten)]
    pub common: CommonAttrs,
}

#[derive(Serialize)]
pub struct RustLibrary {
    pub name: String,
    #[serde(
        skip_serializing_if = "SelectList::is_empty",
        serialize_with = "SelectList::serialize_starlark"
    )]
    pub deps: SelectList<WithOriginalConfigurations<String>>,
    #[serde(
        skip_serializing_if = "SelectList::is_empty",
        serialize_with = "SelectList::serialize_starlark"
    )]
    pub proc_macro_deps: SelectList<WithOriginalConfigurations<String>>,
    #[serde(
        skip_serializing_if = "SelectDict::is_empty",
        serialize_with = "SelectDict::serialize_starlark"
    )]
    pub aliases: SelectDict<WithOriginalConfigurations<String>>,
    #[serde(flatten)]
    pub common: CommonAttrs,
    #[serde(skip_serializing_if = "std::ops::Not::not")]
    pub disable_pipelining: bool,
}

#[derive(Serialize)]
pub struct RustBinary {
    pub name: String,
    #[serde(
        skip_serializing_if = "SelectList::is_empty",
        serialize_with = "SelectList::serialize_starlark"
    )]
    pub deps: SelectList<WithOriginalConfigurations<String>>,
    #[serde(
        skip_serializing_if = "SelectList::is_empty",
        serialize_with = "SelectList::serialize_starlark"
    )]
    pub proc_macro_deps: SelectList<WithOriginalConfigurations<String>>,
    #[serde(
        skip_serializing_if = "SelectDict::is_empty",
        serialize_with = "SelectDict::serialize_starlark"
    )]
    pub aliases: SelectDict<WithOriginalConfigurations<String>>,
    #[serde(flatten)]
    pub common: CommonAttrs,
}

#[derive(Serialize)]
pub struct CommonAttrs {
    #[serde(skip_serializing_if = "Data::is_empty")]
    pub compile_data: Data,
    #[serde(
        skip_serializing_if = "SelectList::is_empty",
        serialize_with = "SelectList::serialize_starlark"
    )]
    pub crate_features: SelectList<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub crate_root: Option<String>,
    #[serde(skip_serializing_if = "Data::is_empty")]
    pub data: Data,
    pub edition: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub linker_script: Option<String>,
    #[serde(
        skip_serializing_if = "SelectDict::is_empty",
        serialize_with = "SelectDict::serialize_starlark"
    )]
    pub rustc_env: SelectDict<WithOriginalConfigurations<String>>,
    #[serde(
        skip_serializing_if = "SelectList::is_empty",
        serialize_with = "SelectList::serialize_starlark"
    )]
    pub rustc_env_files: SelectList<WithOriginalConfigurations<String>>,
    #[serde(skip_serializing_if = "Vec::is_empty")]
    pub rustc_flags: Vec<String>,
    pub srcs: Glob,
    #[serde(skip_serializing_if = "Set::is_empty")]
    pub tags: Set<String>,
    #[serde(
        serialize_with = "serialize_target_compatible_with",
        skip_serializing_if = "Option::is_none"
    )]
    pub target_compatible_with: Option<TargetCompatibleWith>,
    pub version: String,
}

fn serialize_target_compatible_with<S>(
    value: &Option<TargetCompatibleWith>,
    serializer: S,
) -> Result<S::Ok, S::Error>
where
    S: Serializer,
{
    // SAFETY: Option::is_none causes serialization to get skipped.
    value.as_ref().unwrap().serialize_starlark(serializer)
}

pub struct Data {
    pub glob: Glob,
    pub select: SelectList<WithOriginalConfigurations<String>>,
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
        if let Starlark::Verbatim(comment) = call {
            content.push_str(comment);
        } else {
            content.push_str(&serde_starlark::to_string(call)?);
        }
    }
    Ok(content)
}
