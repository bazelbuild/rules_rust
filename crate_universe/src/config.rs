//! A module for configuration information

use std::collections::{BTreeMap, BTreeSet};
use std::convert::AsRef;
use std::iter::Sum;
use std::ops::Add;
use std::path::Path;
use std::{fmt, fs};

use anyhow::Result;
use cargo_lock::package::GitReference;
use cargo_metadata::Package;
use semver::VersionReq;
use serde::de::value::SeqAccessDeserializer;
use serde::de::{Deserializer, SeqAccess, Visitor};
use serde::{Deserialize, Serialize, Serializer};

/// Representations of different kinds of crate vendoring into workspaces.
#[derive(Debug, Serialize, Deserialize, Clone)]
#[serde(rename_all = "lowercase")]
pub enum VendorMode {
    /// Crates having full source being vendored into a workspace
    Local,

    /// Crates having only BUILD files with repository rules vendored into a workspace
    Remote,
}

impl std::fmt::Display for VendorMode {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        fmt::Display::fmt(
            match self {
                VendorMode::Local => "local",
                VendorMode::Remote => "remote",
            },
            f,
        )
    }
}

#[derive(Debug, Serialize, Deserialize, Clone)]
#[serde(deny_unknown_fields)]
pub struct RenderConfig {
    /// The name of the repository being rendered
    pub repository_name: String,

    /// The pattern to use for BUILD file names.
    /// Eg. `//:BUILD.{name}-{version}.bazel`
    #[serde(default = "default_build_file_template")]
    pub build_file_template: String,

    /// The pattern to use for a crate target.
    /// Eg. `@{repository}__{name}-{version}//:{target}`
    #[serde(default = "default_crate_label_template")]
    pub crate_label_template: String,

    /// The pattern to use for the `defs.bzl` and `BUILD.bazel`
    /// file names used for the crates module.
    /// Eg. `//:{file}`
    #[serde(default = "default_crates_module_template")]
    pub crates_module_template: String,

    /// The pattern used for a crate's repository name.
    /// Eg. `{repository}__{name}-{version}`
    #[serde(default = "default_crate_repository_template")]
    pub crate_repository_template: String,

    /// The default of the `package_name` parameter to use for the module macros like `all_crate_deps`.
    /// In general, this should be be unset to allow the macros to do auto-detection in the analysis phase.
    pub default_package_name: Option<String>,

    /// The pattern to use for platform constraints.
    /// Eg. `@rules_rust//rust/platform:{triple}`.
    #[serde(default = "default_platforms_template")]
    pub platforms_template: String,

    /// The command to use for regenerating generated files.
    pub regen_command: String,

    /// An optional configuration for rendering content to be rendered into repositories.
    pub vendor_mode: Option<VendorMode>,
}

// Default is manually implemented so that the default values match the default
// values when deserializing, which involves calling the vairous `default_x()`
// functions specified in `#[serde(default = "default_x")]`.
impl Default for RenderConfig {
    fn default() -> Self {
        RenderConfig {
            repository_name: String::default(),
            build_file_template: default_build_file_template(),
            crate_label_template: default_crate_label_template(),
            crates_module_template: default_crates_module_template(),
            crate_repository_template: default_crate_repository_template(),
            default_package_name: Option::default(),
            platforms_template: default_platforms_template(),
            regen_command: String::default(),
            vendor_mode: Option::default(),
        }
    }
}

fn default_build_file_template() -> String {
    "//:BUILD.{name}-{version}.bazel".to_owned()
}

fn default_crates_module_template() -> String {
    "//:{file}".to_owned()
}

fn default_crate_label_template() -> String {
    "@{repository}__{name}-{version}//:{target}".to_owned()
}

fn default_crate_repository_template() -> String {
    "{repository}__{name}-{version}".to_owned()
}

fn default_platforms_template() -> String {
    "@rules_rust//rust/platform:{triple}".to_owned()
}

/// A representation of some Git identifier used to represent the "revision" or "pin" of a checkout.
#[derive(Debug, Serialize, Deserialize, Clone, PartialEq, Eq, PartialOrd, Ord)]
pub enum Commitish {
    /// From a tag.
    Tag(String),

    /// From the HEAD of a branch.
    Branch(String),

    /// From a specific revision.
    Rev(String),
}

impl From<GitReference> for Commitish {
    fn from(git_ref: GitReference) -> Self {
        match git_ref {
            GitReference::Tag(v) => Self::Tag(v),
            GitReference::Branch(v) => Self::Branch(v),
            GitReference::Rev(v) => Self::Rev(v),
        }
    }
}
/// A value which may either be a plain String, or a dict of platform triples
/// (or other cfg expressions understood by `crate::context::platforms::resolve_cfg_platforms`) to Strings.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(untagged)]
pub enum StringOrSelect {
    Value(String),
    Select(BTreeMap<String, String>),
}

/// Information representing deterministic identifiers for some remote asset.
#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
pub enum Checksumish {
    Http {
        /// The sha256 digest of an http archive
        sha256: Option<String>,
    },
    Git {
        /// The revision of the git repository
        commitsh: Commitish,

        /// An optional date, not after the specified commit; the argument is
        /// not allowed if a tag is specified (which allows cloning with depth
        /// 1).
        shallow_since: Option<String>,
    },
}

#[derive(Debug, Default, Deserialize, Serialize, Clone, PartialEq)]
pub struct CrateAnnotations {
    /// Which subset of the crate's bins should get produced as `rust_binary` targets.
    pub gen_binaries: Option<GenBinaries>,

    /// Determins whether or not Cargo build scripts should be generated for the current package
    pub gen_build_script: Option<bool>,

    /// Additional data to pass to
    /// [deps](https://bazelbuild.github.io/rules_rust/defs.html#rust_library-deps) attribute.
    pub deps: Option<BTreeSet<String>>,

    /// Additional data to pass to
    /// [proc_macro_deps](https://bazelbuild.github.io/rules_rust/defs.html#rust_library-proc_macro_deps) attribute.
    pub proc_macro_deps: Option<BTreeSet<String>>,

    /// Additional data to pass to  the target's
    /// [crate_features](https://bazelbuild.github.io/rules_rust/defs.html#rust_library-crate_features) attribute.
    pub crate_features: Option<BTreeSet<String>>,

    /// Additional data to pass to  the target's
    /// [data](https://bazelbuild.github.io/rules_rust/defs.html#rust_library-data) attribute.
    pub data: Option<BTreeSet<String>>,

    /// An optional glob pattern to set on the
    /// [data](https://bazelbuild.github.io/rules_rust/defs.html#rust_library-data) attribute.
    pub data_glob: Option<BTreeSet<String>>,

    /// Additional data to pass to
    /// [compile_data](https://bazelbuild.github.io/rules_rust/defs.html#rust_library-compile_data) attribute.
    pub compile_data: Option<BTreeSet<String>>,

    /// An optional glob pattern to set on the
    /// [compile_data](https://bazelbuild.github.io/rules_rust/defs.html#rust_library-compile_data) attribute.
    pub compile_data_glob: Option<BTreeSet<String>>,

    /// If true, disables pipelining for library targets generated for this crate.
    pub disable_pipelining: bool,

    /// Additional data to pass to  the target's
    /// [rustc_env](https://bazelbuild.github.io/rules_rust/defs.html#rust_library-rustc_env) attribute.
    pub rustc_env: Option<BTreeMap<String, String>>,

    /// Additional data to pass to  the target's
    /// [rustc_env_files](https://bazelbuild.github.io/rules_rust/defs.html#rust_library-rustc_env_files) attribute.
    pub rustc_env_files: Option<BTreeSet<String>>,

    /// Additional data to pass to the target's
    /// [rustc_flags](https://bazelbuild.github.io/rules_rust/defs.html#rust_library-rustc_flags) attribute.
    pub rustc_flags: Option<Vec<String>>,

    /// Additional dependencies to pass to a build script's
    /// [deps](https://bazelbuild.github.io/rules_rust/cargo.html#cargo_build_script-deps) attribute.
    pub build_script_deps: Option<BTreeSet<String>>,

    /// Additional data to pass to a build script's
    /// [proc_macro_deps](https://bazelbuild.github.io/rules_rust/cargo.html#cargo_build_script-proc_macro_deps) attribute.
    pub build_script_proc_macro_deps: Option<BTreeSet<String>>,

    /// Additional data to pass to a build script's
    /// [build_script_data](https://bazelbuild.github.io/rules_rust/cargo.html#cargo_build_script-data) attribute.
    pub build_script_data: Option<BTreeSet<String>>,

    /// Additional data to pass to a build script's
    /// [tools](https://bazelbuild.github.io/rules_rust/cargo.html#cargo_build_script-tools) attribute.
    pub build_script_tools: Option<BTreeSet<String>>,

    /// An optional glob pattern to set on the
    /// [build_script_data](https://bazelbuild.github.io/rules_rust/cargo.html#cargo_build_script-build_script_env) attribute.
    pub build_script_data_glob: Option<BTreeSet<String>>,

    /// Additional environment variables to pass to a build script's
    /// [build_script_env](https://bazelbuild.github.io/rules_rust/cargo.html#cargo_build_script-rustc_env) attribute.
    pub build_script_env: Option<BTreeMap<String, StringOrSelect>>,

    /// Additional rustc_env flags to pass to a build script's
    /// [rustc_env](https://bazelbuild.github.io/rules_rust/cargo.html#cargo_build_script-rustc_env) attribute.
    pub build_script_rustc_env: Option<BTreeMap<String, String>>,

    /// Additional labels to pass to a build script's
    /// [toolchains](https://bazel.build/reference/be/common-definitions#common-attributes) attribute.
    pub build_script_toolchains: Option<BTreeSet<String>>,

    /// A scratch pad used to write arbitrary text to target BUILD files.
    pub additive_build_file_content: Option<String>,

    /// For git sourced crates, this is a the
    /// [git_repository::shallow_since](https://docs.bazel.build/versions/main/repo/git.html#new_git_repository-shallow_since) attribute.
    pub shallow_since: Option<String>,

    /// The `patch_args` attribute of a Bazel repository rule. See
    /// [http_archive.patch_args](https://docs.bazel.build/versions/main/repo/http.html#http_archive-patch_args)
    pub patch_args: Option<Vec<String>>,

    /// The `patch_tool` attribute of a Bazel repository rule. See
    /// [http_archive.patch_tool](https://docs.bazel.build/versions/main/repo/http.html#http_archive-patch_tool)
    pub patch_tool: Option<String>,

    /// The `patches` attribute of a Bazel repository rule. See
    /// [http_archive.patches](https://docs.bazel.build/versions/main/repo/http.html#http_archive-patches)
    pub patches: Option<BTreeSet<String>>,

    /// Extra targets the should be aliased during rendering.
    pub extra_aliased_targets: Option<BTreeMap<String, String>>,
}

macro_rules! joined_extra_member {
    ($lhs:expr, $rhs:expr, $fn_new:expr, $fn_extend:expr) => {
        if let Some(lhs) = $lhs {
            if let Some(rhs) = $rhs {
                let mut new = $fn_new();
                $fn_extend(&mut new, lhs);
                $fn_extend(&mut new, rhs);
                Some(new)
            } else {
                Some(lhs)
            }
        } else if $rhs.is_some() {
            $rhs
        } else {
            None
        }
    };
}

impl Add for CrateAnnotations {
    type Output = CrateAnnotations;

    fn add(self, rhs: Self) -> Self::Output {
        let concat_string = |lhs: &mut String, rhs: String| {
            *lhs = format!("{lhs}{rhs}");
        };

        #[rustfmt::skip]
        let output = CrateAnnotations {
            gen_binaries: self.gen_binaries.or(rhs.gen_binaries),
            gen_build_script: self.gen_build_script.or(rhs.gen_build_script),
            deps: joined_extra_member!(self.deps, rhs.deps, BTreeSet::new, BTreeSet::extend),
            proc_macro_deps: joined_extra_member!(self.proc_macro_deps, rhs.proc_macro_deps, BTreeSet::new, BTreeSet::extend),
            crate_features: joined_extra_member!(self.crate_features, rhs.crate_features, BTreeSet::new, BTreeSet::extend),
            data: joined_extra_member!(self.data, rhs.data, BTreeSet::new, BTreeSet::extend),
            data_glob: joined_extra_member!(self.data_glob, rhs.data_glob, BTreeSet::new, BTreeSet::extend),
            disable_pipelining: self.disable_pipelining || rhs.disable_pipelining,
            compile_data: joined_extra_member!(self.compile_data, rhs.compile_data, BTreeSet::new, BTreeSet::extend),
            compile_data_glob: joined_extra_member!(self.compile_data_glob, rhs.compile_data_glob, BTreeSet::new, BTreeSet::extend),
            rustc_env: joined_extra_member!(self.rustc_env, rhs.rustc_env, BTreeMap::new, BTreeMap::extend),
            rustc_env_files: joined_extra_member!(self.rustc_env_files, rhs.rustc_env_files, BTreeSet::new, BTreeSet::extend),
            rustc_flags: joined_extra_member!(self.rustc_flags, rhs.rustc_flags, Vec::new, Vec::extend),
            build_script_deps: joined_extra_member!(self.build_script_deps, rhs.build_script_deps, BTreeSet::new, BTreeSet::extend),
            build_script_proc_macro_deps: joined_extra_member!(self.build_script_proc_macro_deps, rhs.build_script_proc_macro_deps, BTreeSet::new, BTreeSet::extend),
            build_script_data: joined_extra_member!(self.build_script_data, rhs.build_script_data, BTreeSet::new, BTreeSet::extend),
            build_script_tools: joined_extra_member!(self.build_script_tools, rhs.build_script_tools, BTreeSet::new, BTreeSet::extend),
            build_script_data_glob: joined_extra_member!(self.build_script_data_glob, rhs.build_script_data_glob, BTreeSet::new, BTreeSet::extend),
            build_script_env: joined_extra_member!(self.build_script_env, rhs.build_script_env, BTreeMap::new, BTreeMap::extend),
            build_script_rustc_env: joined_extra_member!(self.build_script_rustc_env, rhs.build_script_rustc_env, BTreeMap::new, BTreeMap::extend),
            build_script_toolchains: joined_extra_member!(self.build_script_toolchains, rhs.build_script_toolchains, BTreeSet::new, BTreeSet::extend),
            additive_build_file_content: joined_extra_member!(self.additive_build_file_content, rhs.additive_build_file_content, String::new, concat_string),
            shallow_since: self.shallow_since.or(rhs.shallow_since),
            patch_args: joined_extra_member!(self.patch_args, rhs.patch_args, Vec::new, Vec::extend),
            patch_tool: self.patch_tool.or(rhs.patch_tool),
            patches: joined_extra_member!(self.patches, rhs.patches, BTreeSet::new, BTreeSet::extend),
            extra_aliased_targets: joined_extra_member!(self.extra_aliased_targets, rhs.extra_aliased_targets, BTreeMap::new, BTreeMap::extend),
        };

        output
    }
}

impl Sum for CrateAnnotations {
    fn sum<I: Iterator<Item = Self>>(iter: I) -> Self {
        iter.fold(CrateAnnotations::default(), |a, b| a + b)
    }
}

/// A subset of `crate.annotation` that we allow packages to define in their
/// free-form Cargo.toml metadata.
///
/// ```toml
/// [package.metadata.bazel]
/// additive_build_file_contents = """
///     ...
/// """
/// data = ["font.woff2"]
/// extra_aliased_targets = { ... }
/// gen_build_script = false
/// ```
///
/// These are considered default values which apply if the Bazel workspace does
/// not specify a different value for the same annotation in their
/// crates_repository attributes.
#[derive(Debug, Deserialize)]
pub struct AnnotationsProvidedByPackage {
    pub gen_build_script: Option<bool>,
    pub data: Option<BTreeSet<String>>,
    pub data_glob: Option<BTreeSet<String>>,
    pub compile_data: Option<BTreeSet<String>>,
    pub compile_data_glob: Option<BTreeSet<String>>,
    pub rustc_env: Option<BTreeMap<String, String>>,
    pub rustc_env_files: Option<BTreeSet<String>>,
    pub rustc_flags: Option<Vec<String>>,
    pub build_script_env: Option<BTreeMap<String, StringOrSelect>>,
    pub build_script_rustc_env: Option<BTreeMap<String, String>>,
    pub additive_build_file_content: Option<String>,
    pub extra_aliased_targets: Option<BTreeMap<String, String>>,
}

impl CrateAnnotations {
    pub fn apply_defaults_from_package_metadata(&mut self, pkg_metadata: &serde_json::Value) {
        #[deny(unused_variables)]
        let AnnotationsProvidedByPackage {
            gen_build_script,
            data,
            data_glob,
            compile_data,
            compile_data_glob,
            rustc_env,
            rustc_env_files,
            rustc_flags,
            build_script_env,
            build_script_rustc_env,
            additive_build_file_content,
            extra_aliased_targets,
        } = match AnnotationsProvidedByPackage::deserialize(&pkg_metadata["bazel"]) {
            Ok(annotations) => annotations,
            // Ignore bad annotations. The set of supported annotations evolves
            // over time across different versions of crate_universe, and we
            // don't want a library to be impossible to import into Bazel for
            // having old or broken annotations. The Bazel workspace can specify
            // its own correct annotations.
            Err(_) => return,
        };

        fn default<T>(workspace_value: &mut Option<T>, default_value: Option<T>) {
            if workspace_value.is_none() {
                *workspace_value = default_value;
            }
        }

        default(&mut self.gen_build_script, gen_build_script);
        default(&mut self.gen_build_script, gen_build_script);
        default(&mut self.data, data);
        default(&mut self.data_glob, data_glob);
        default(&mut self.compile_data, compile_data);
        default(&mut self.compile_data_glob, compile_data_glob);
        default(&mut self.rustc_env, rustc_env);
        default(&mut self.rustc_env_files, rustc_env_files);
        default(&mut self.rustc_flags, rustc_flags);
        default(&mut self.build_script_env, build_script_env);
        default(&mut self.build_script_rustc_env, build_script_rustc_env);
        default(
            &mut self.additive_build_file_content,
            additive_build_file_content,
        );
        default(&mut self.extra_aliased_targets, extra_aliased_targets);
    }
}

/// A unique identifier for Crates
#[derive(Debug, PartialEq, Eq, PartialOrd, Ord, Clone)]
pub struct CrateId {
    /// The name of the crate
    pub name: String,

    /// The crate's semantic version
    pub version: String,
}

impl CrateId {
    /// Construct a new [CrateId]
    pub fn new(name: String, version: String) -> Self {
        Self { name, version }
    }

    /// Compares a [CrateId] against a [cargo_metadata::Package].
    pub fn matches(&self, package: &Package) -> bool {
        // If the package name does not match, it's obviously
        // not the right package
        if self.name != "*" && self.name != package.name {
            return false;
        }

        // First see if the package version matches exactly
        if package.version.to_string() == self.version {
            return true;
        }

        // If the version provided is the wildcard "*", it matches. Do not
        // delegate to the semver crate in this case because semver does not
        // consider "*" to match prerelease packages. That's expected behavior
        // in the context of declaring package dependencies, but not in the
        // context of declaring which versions of preselected packages an
        // annotation applies to.
        if self.version == "*" {
            return true;
        }

        // Next, check to see if the version provided is a semver req and
        // check if the package matches the condition
        if let Ok(semver) = VersionReq::parse(&self.version) {
            if semver.matches(&package.version) {
                return true;
            }
        }

        false
    }
}

impl From<&Package> for CrateId {
    fn from(package: &Package) -> Self {
        Self {
            name: package.name.clone(),
            version: package.version.to_string(),
        }
    }
}

impl Serialize for CrateId {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        serializer.serialize_str(&format!("{} {}", self.name, self.version))
    }
}

struct CrateIdVisitor;
impl<'de> Visitor<'de> for CrateIdVisitor {
    type Value = CrateId;

    fn expecting(&self, formatter: &mut fmt::Formatter) -> fmt::Result {
        formatter.write_str("Expected string value of `{name} {version}`.")
    }

    fn visit_str<E>(self, v: &str) -> Result<Self::Value, E>
    where
        E: serde::de::Error,
    {
        v.rsplit_once(' ')
            .map(|(name, version)| CrateId {
                name: name.to_string(),
                version: version.to_string(),
            })
            .ok_or_else(|| {
                E::custom(format!(
                    "Expected string value of `{{name}} {{version}}`. Got '{v}'"
                ))
            })
    }
}

impl<'de> Deserialize<'de> for CrateId {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        deserializer.deserialize_str(CrateIdVisitor)
    }
}

impl std::fmt::Display for CrateId {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        fmt::Display::fmt(&format!("{} {}", self.name, self.version), f)
    }
}

#[derive(Debug, Hash, Clone, PartialEq)]
pub enum GenBinaries {
    All,
    Some(BTreeSet<String>),
}

impl Default for GenBinaries {
    fn default() -> Self {
        GenBinaries::Some(BTreeSet::new())
    }
}

impl Serialize for GenBinaries {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        match self {
            GenBinaries::All => serializer.serialize_bool(true),
            GenBinaries::Some(set) if set.is_empty() => serializer.serialize_bool(false),
            GenBinaries::Some(set) => serializer.collect_seq(set),
        }
    }
}

impl<'de> Deserialize<'de> for GenBinaries {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: Deserializer<'de>,
    {
        deserializer.deserialize_any(GenBinariesVisitor)
    }
}

struct GenBinariesVisitor;
impl<'de> Visitor<'de> for GenBinariesVisitor {
    type Value = GenBinaries;

    fn expecting(&self, formatter: &mut fmt::Formatter) -> fmt::Result {
        formatter.write_str("boolean, or array of bin names")
    }

    fn visit_bool<E>(self, gen_binaries: bool) -> Result<Self::Value, E> {
        if gen_binaries {
            Ok(GenBinaries::All)
        } else {
            Ok(GenBinaries::Some(BTreeSet::new()))
        }
    }

    fn visit_seq<A>(self, seq: A) -> Result<Self::Value, A::Error>
    where
        A: SeqAccess<'de>,
    {
        BTreeSet::deserialize(SeqAccessDeserializer::new(seq)).map(GenBinaries::Some)
    }
}

/// Workspace specific settings to control how targets are generated
#[derive(Debug, Default, Serialize, Deserialize, Clone)]
#[serde(deny_unknown_fields)]
pub struct Config {
    /// Whether to generate `rust_binary` targets for all bins by default
    pub generate_binaries: bool,

    /// Whether or not to generate Cargo build scripts by default
    pub generate_build_scripts: bool,

    /// A set of platform triples to use in generated select statements
    #[serde(
        default = "default_generate_target_compatible_with",
        skip_serializing_if = "skip_generate_target_compatible_with"
    )]
    pub generate_target_compatible_with: bool,

    /// Additional settings to apply to generated crates
    #[serde(default, skip_serializing_if = "BTreeMap::is_empty")]
    pub annotations: BTreeMap<CrateId, CrateAnnotations>,

    /// Settings used to determine various render info
    pub rendering: RenderConfig,

    /// The contents of a Cargo configuration file
    pub cargo_config: Option<toml::Value>,

    /// A set of platform triples to use in generated select statements
    #[serde(default, skip_serializing_if = "BTreeSet::is_empty")]
    pub supported_platform_triples: BTreeSet<String>,
}

impl Config {
    pub fn try_from_path<T: AsRef<Path>>(path: T) -> Result<Self> {
        let data = fs::read_to_string(path)?;
        Ok(serde_json::from_str(&data)?)
    }
}

fn default_generate_target_compatible_with() -> bool {
    true
}
fn skip_generate_target_compatible_with(value: &bool) -> bool {
    *value
}

#[cfg(test)]
mod test {
    use super::*;

    use crate::test::*;

    #[test]
    fn test_crate_id_serde() {
        let id: CrateId = serde_json::from_str("\"crate 0.1.0\"").unwrap();
        assert_eq!(id, CrateId::new("crate".to_owned(), "0.1.0".to_owned()));
        assert_eq!(serde_json::to_string(&id).unwrap(), "\"crate 0.1.0\"");
    }

    #[test]
    fn test_crate_id_serde_semver() {
        let semver_id: CrateId = serde_json::from_str("\"crate *\"").unwrap();
        assert_eq!(semver_id, CrateId::new("crate".to_owned(), "*".to_owned()));
        assert_eq!(serde_json::to_string(&semver_id).unwrap(), "\"crate *\"");
    }

    #[test]
    fn test_crate_id_matches() {
        let mut package = mock_cargo_metadata_package();
        let id = CrateId::new("mock-pkg".to_owned(), "0.1.0".to_owned());

        package.version = cargo_metadata::semver::Version::new(0, 1, 0);
        assert!(id.matches(&package));

        package.version = cargo_metadata::semver::Version::new(1, 0, 0);
        assert!(!id.matches(&package));
    }

    #[test]
    fn test_crate_id_semver_matches() {
        let mut package = mock_cargo_metadata_package();
        package.version = cargo_metadata::semver::Version::new(1, 0, 0);
        let mut id = CrateId::new("mock-pkg".to_owned(), "0.1.0".to_owned());

        id.version = "*".to_owned();
        assert!(id.matches(&package));

        let mut prerelease = mock_cargo_metadata_package();
        prerelease.version = cargo_metadata::semver::Version::parse("1.0.0-pre.0").unwrap();
        assert!(id.matches(&prerelease));

        id.version = "<1".to_owned();
        assert!(!id.matches(&package));
    }

    #[test]
    fn deserialize_config() {
        let runfiles = runfiles::Runfiles::create().unwrap();
        let path = runfiles
            .rlocation("rules_rust/crate_universe/test_data/serialized_configs/config.json");

        let content = std::fs::read_to_string(path).unwrap();

        let config: Config = serde_json::from_str(&content).unwrap();

        // Annotations
        let annotation = config
            .annotations
            .get(&CrateId::new("rand".to_owned(), "0.8.5".to_owned()))
            .unwrap();
        assert_eq!(
            annotation.crate_features,
            Some(BTreeSet::from(["small_rng".to_owned()]))
        );

        // Global settings
        assert!(config.cargo_config.is_none());
        assert!(!config.generate_binaries);
        assert!(!config.generate_build_scripts);

        // Render Config
        assert_eq!(
            config.rendering.platforms_template,
            "//custom/platform:{triple}"
        );
    }
}
