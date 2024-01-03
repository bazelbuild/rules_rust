//! A module for representations of starlark constructs

mod glob;
mod label;
mod select;
mod select_dict;
mod select_list;
mod select_scalar;
mod select_set;
mod serialize;
mod target_compatible_with;

use std::collections::BTreeSet as Set;

use serde::{Serialize, Serializer};
use serde_starlark::{Error as StarlarkError, FunctionCall};

pub use glob::*;
pub use label::*;
pub use select::*;
pub use select_dict::*;
pub use select_list::*;
pub use select_scalar::*;
pub use select_set::*;
pub use target_compatible_with::*;

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

pub struct Alias {
    pub rule: String,
    pub name: String,
    pub actual: String,
    pub tags: Set<String>,
}

#[derive(Serialize)]
#[serde(rename = "cargo_build_script")]
pub struct CargoBuildScript {
    pub name: String,
    #[serde(skip_serializing_if = "SelectDict::is_empty")]
    pub aliases: SelectDict<String>,
    #[serde(skip_serializing_if = "SelectDict::is_empty")]
    pub build_script_env: SelectDict<String>,
    #[serde(skip_serializing_if = "Data::is_empty")]
    pub compile_data: Data,
    #[serde(skip_serializing_if = "SelectSet::is_empty")]
    pub crate_features: SelectSet<String>,
    pub crate_name: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub crate_root: Option<String>,
    #[serde(skip_serializing_if = "Data::is_empty")]
    pub data: Data,
    #[serde(skip_serializing_if = "SelectSet::is_empty")]
    pub deps: SelectSet<String>,
    #[serde(skip_serializing_if = "SelectSet::is_empty")]
    pub link_deps: SelectSet<String>,
    pub edition: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub linker_script: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub links: Option<String>,
    #[serde(skip_serializing_if = "SelectSet::is_empty")]
    pub proc_macro_deps: SelectSet<String>,
    #[serde(skip_serializing_if = "SelectScalar::is_empty")]
    pub rundir: SelectScalar<String>,
    #[serde(skip_serializing_if = "SelectDict::is_empty")]
    pub rustc_env: SelectDict<String>,
    #[serde(skip_serializing_if = "SelectSet::is_empty")]
    pub rustc_env_files: SelectSet<String>,
    #[serde(skip_serializing_if = "SelectList::is_empty")]
    pub rustc_flags: SelectList<String>,
    pub srcs: Glob,
    #[serde(skip_serializing_if = "Set::is_empty")]
    pub tags: Set<String>,
    #[serde(skip_serializing_if = "SelectSet::is_empty")]
    pub tools: SelectSet<String>,
    #[serde(skip_serializing_if = "Set::is_empty")]
    pub toolchains: Set<String>,
    pub version: String,
    pub visibility: Set<String>,
}

#[derive(Serialize)]
pub struct RustProcMacro {
    pub name: String,
    #[serde(skip_serializing_if = "SelectSet::is_empty")]
    pub deps: SelectSet<String>,
    #[serde(skip_serializing_if = "SelectSet::is_empty")]
    pub proc_macro_deps: SelectSet<String>,
    #[serde(skip_serializing_if = "SelectDict::is_empty")]
    pub aliases: SelectDict<String>,
    #[serde(flatten)]
    pub common: CommonAttrs,
}

#[derive(Serialize)]
pub struct RustLibrary {
    pub name: String,
    #[serde(skip_serializing_if = "SelectSet::is_empty")]
    pub deps: SelectSet<String>,
    #[serde(skip_serializing_if = "SelectSet::is_empty")]
    pub proc_macro_deps: SelectSet<String>,
    #[serde(skip_serializing_if = "SelectDict::is_empty")]
    pub aliases: SelectDict<String>,
    #[serde(flatten)]
    pub common: CommonAttrs,
    #[serde(skip_serializing_if = "std::ops::Not::not")]
    pub disable_pipelining: bool,
}

#[derive(Serialize)]
pub struct RustBinary {
    pub name: String,
    #[serde(skip_serializing_if = "SelectSet::is_empty")]
    pub deps: SelectSet<String>,
    #[serde(skip_serializing_if = "SelectSet::is_empty")]
    pub proc_macro_deps: SelectSet<String>,
    #[serde(skip_serializing_if = "SelectDict::is_empty")]
    pub aliases: SelectDict<String>,
    #[serde(flatten)]
    pub common: CommonAttrs,
}

#[derive(Serialize)]
pub struct CommonAttrs {
    #[serde(skip_serializing_if = "Data::is_empty")]
    pub compile_data: Data,
    #[serde(skip_serializing_if = "SelectSet::is_empty")]
    pub crate_features: SelectSet<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub crate_root: Option<String>,
    #[serde(skip_serializing_if = "Data::is_empty")]
    pub data: Data,
    pub edition: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub linker_script: Option<String>,
    #[serde(skip_serializing_if = "SelectDict::is_empty")]
    pub rustc_env: SelectDict<String>,
    #[serde(skip_serializing_if = "SelectSet::is_empty")]
    pub rustc_env_files: SelectSet<String>,
    #[serde(skip_serializing_if = "SelectList::is_empty")]
    pub rustc_flags: SelectList<String>,
    pub srcs: Glob,
    #[serde(skip_serializing_if = "Set::is_empty")]
    pub tags: Set<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub target_compatible_with: Option<TargetCompatibleWith>,
    pub version: String,
}

pub struct Data {
    pub glob: Glob,
    pub select: SelectSet<String>,
}

impl Package {
    pub fn default_visibility_public() -> Self {
        let mut default_visibility = Set::new();
        default_visibility.insert("//visibility:public".to_owned());
        Package { default_visibility }
    }
}

impl Serialize for Alias {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        // Output looks like:
        //
        //     rule(
        //         name = "name",
        //         actual = "actual",
        //         tags = [
        //            "tag1",
        //            "tag2",
        //         ],
        //     )

        #[derive(Serialize)]
        struct AliasInner<'a> {
            pub name: &'a String,
            pub actual: &'a String,
            pub tags: &'a Set<String>,
        }

        FunctionCall::new(
            &self.rule,
            AliasInner {
                name: &self.name,
                actual: &self.actual,
                tags: &self.tags,
            },
        )
        .serialize(serializer)
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
