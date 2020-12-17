use anyhow::Context;
use heck::{CamelCase, SnakeCase};
use prost::Message;
use prost_types::FileDescriptorSet;
use std::path::PathBuf;
use std::result::Result;
use std::str::FromStr;
use std::vec::Vec;
use thiserror::Error;

#[derive(Debug, Error)]
pub enum ArgError {
    #[error(
        "Invalid argument `{0}`: external arguments must be of the form \
        --external=crate_name,file_descriptor_path."
    )]
    InvalidArgument(String),

    #[error("crate name `{crate_name:?}` in argument external=`{argument:?}` is not valid")]
    InvalidCrate {
        crate_name: String,
        argument: String,
    },

    #[error("An empty filename was provided in argument `{0}`")]
    EmptyFilename(String),
}

#[derive(Debug, Error, PartialEq)]
pub enum LoadError {
    #[error("Package name not set")]
    PackageNameUnset,

    #[error("Unable to load DescriptorProto for message[{index:?}]: {details:?}")]
    BadMessageDescriptor { index: usize, details: String },

    #[error("Unable to load EnumDescriptorProto for enum[{index:?}]: {details:?}")]
    BadEnumDescriptor { index: usize, details: String },
}

#[derive(Debug, Error, PartialEq)]
pub enum SetLoadError {
    #[error("Unabled to load FileDescriptorProto file[{index:?}]: {error:?}")]
    BadFileDescriptor { index: usize, error: LoadError },
}

/// The resulting paths that can be passed to prost_build's extern_path option.
#[derive(Debug, PartialEq)]
pub struct ExternPath {
    // The fully qualified rust path (i.e. ::crate::module::sub::Type)
    path: String,
    // The fully qualified protobuf package name (i.e. .google.protobuf.FileDescriptor)
    package: String,
}

impl ExternPath {
    pub fn apply(&self, builder: tonic_build::Builder) -> tonic_build::Builder {
        builder.extern_path(&self.package, &self.path)
    }
}

#[derive(Clone, Debug, PartialEq)]
struct CrateName(String);

impl CrateName {
    /// Converts a crate name into the identifier used in a source file.
    fn for_source(&self) -> String {
        self.0.replace("-", "_")
    }
}

impl FromStr for CrateName {
    type Err = ();

    /// "convert" a crate name by providing some validation on the name given.  Err is () as there's
    /// not really a useful signal here about validity that can't be provided by the calling
    /// function, with perhaps more context.
    fn from_str(s: &str) -> Result<CrateName, Self::Err> {
        if valid_crate(s) {
            Ok(CrateName(s.to_owned()))
        } else {
            Err(())
        }
    }
}

/// Holds the arguments passed into the --extern=crate_name,file_path option for ProstGen.
#[derive(Debug)]
pub struct ExternPathSetArg {
    crate_name: CrateName,
    descriptor_set: PathBuf,
}

impl ExternPathSetArg {
    /// Reads in the binary-serialized FileDescriptorSet pointed to by `descriptor_set`, and from
    /// that file loads in all of the valid `ExternPath` values.
    pub fn load(&self) -> anyhow::Result<Vec<ExternPath>> {
        let loaded = read_file_descriptor_set(&self.descriptor_set)
            .with_context(|| format!("Unable to load file {:?}", &self.descriptor_set))?;
        let paths = self.get_all_paths(&loaded)?;
        Ok(paths)
    }

    /// Collects all of the valid, top-level `ExternPath`s within a FileDescriptorSet from each
    /// file by using `get_paths`.
    fn get_all_paths(&self, set: &FileDescriptorSet) -> Result<Vec<ExternPath>, SetLoadError> {
        let mut out = Vec::new();
        for (index, file) in set.file.iter().enumerate() {
            out.append(
                &mut self
                    .get_paths(file)
                    .map_err(|error| SetLoadError::BadFileDescriptor { index, error })?,
            );
        }
        Ok(out)
    }

    /// Creates an ExternPath for every top-level enum and message within the FileDescriptorProto.
    /// We only care about the top-level messages, rather than any messages or enums that might be
    /// nested in a message, because this nesting cannot happen across files (i.e. a message type
    /// cannot be opened in a different file, and a message injected).  This means we can let
    /// prost_build handle the recursive paths.
    fn get_paths(
        &self,
        file: &prost_types::FileDescriptorProto,
    ) -> Result<Vec<ExternPath>, LoadError> {
        let builder = self.get_builder(file)?;
        let needed_capacity = file.message_type.len() + file.enum_type.len();

        let mut out = Vec::with_capacity(needed_capacity);

        for (index, message_type) in file.message_type.iter().enumerate() {
            let path = builder
                .from(message_type)
                .map_err(|details| LoadError::BadMessageDescriptor { index, details })?;
            out.push(path);
        }
        for (index, enum_type) in file.enum_type.iter().enumerate() {
            let path = builder
                .from(enum_type)
                .map_err(|details| LoadError::BadEnumDescriptor { index, details })?;
            out.push(path);
        }

        Ok(out)
    }

    /// Constructs an `IndividualExternPathBuilder` as a helper class to store onto a crate and
    /// package name that is used in constructing the paths of each message and enum, instead of
    /// having to provide three string arguments to a function each time.
    fn get_builder<'a>(
        &'a self,
        file: &'a prost_types::FileDescriptorProto,
    ) -> Result<IndividualExternPathBuilder<'a>, LoadError> {
        let package_name = file
            .package
            .as_ref()
            .ok_or(LoadError::PackageNameUnset)?
            .as_str();
        Ok(IndividualExternPathBuilder {
            crate_name: &self.crate_name,
            package_name,
        })
    }
}

/// Allows for StructOpt to parse ExternPathSetArg from the command line.
impl FromStr for ExternPathSetArg {
    type Err = ArgError;

    /// Provides a conversion from a string of "crate_name,file_descriptor_path" into the
    /// `ExternPathSetArg` struct.  Only checks the validity of the text format, not the file
    /// specified itself.
    fn from_str(s: &str) -> Result<ExternPathSetArg, Self::Err> {
        let parts: Vec<&str> = s.split(',').collect();

        if parts.len() != 2 {
            return Err(ArgError::InvalidArgument(s.to_owned()));
        }

        let crate_name = CrateName::from_str(parts[0]).map_err(|()| ArgError::InvalidCrate {
            crate_name: parts[0].to_owned(),
            argument: s.to_owned(),
        })?;

        if parts[1].is_empty() {
            return Err(ArgError::EmptyFilename(s.to_owned()));
        }
        // This conversion is infallible.  The FromStr::Err for this is the Infallible type:
        // https://doc.rust-lang.org/std/path/struct.PathBuf.html#impl-FromStr
        let descriptor_set = PathBuf::from_str(parts[1]).unwrap();

        Ok(ExternPathSetArg {
            crate_name,
            descriptor_set,
        })
    }
}

/// Constraint for from method in the `IndividualExternPathBuilder`
trait HasName {
    /// Expected to just return the name member of the struct.
    fn name(&self) -> &Option<String>;
}

impl HasName for prost_types::DescriptorProto {
    fn name(&self) -> &Option<String> {
        &self.name
    }
}

impl HasName for prost_types::EnumDescriptorProto {
    fn name(&self) -> &Option<String> {
        &self.name
    }
}

/// Helper struct that holds onto references needed across multiple calls to build `ExternPath`s
struct IndividualExternPathBuilder<'a> {
    crate_name: &'a CrateName,
    package_name: &'a str,
}

impl IndividualExternPathBuilder<'_> {
    /// Converts a proto with a `name` member to an `ExternPath` relative to `crate_name` and
    /// `pacakage_name` for this builder.
    fn from<T>(&self, description: &T) -> Result<ExternPath, String>
    where
        T: HasName,
    {
        let name = description
            .name()
            .as_ref()
            .ok_or_else(|| "Name was not set".to_owned())?
            .as_str();
        Ok(ExternPath {
            path: format!(
                "::{}::{}::{}",
                self.crate_name.for_source(),
                to_module_name(self.package_name),
                to_upper_camel(name)
            ),
            package: format!(".{}.{}", self.package_name, name),
        })
    }
}

fn read_file_descriptor_set(path: &PathBuf) -> std::io::Result<FileDescriptorSet> {
    let buf = std::fs::read(path)?;
    let message = FileDescriptorSet::decode(&*buf)?;
    Ok(message)
}

/// A valid crate name is just a valid identifier, with '-' allowed, but converted to '_' in source.
/// Though, as a note, rule_rust does this converstion on bazel target names for us already.
/// https://github.com/bazelbuild/rules_rust/blob/master/rust/private/rust.bzl#L116
fn valid_crate(name: &str) -> bool {
    !name.is_empty()
        && name.chars().next().unwrap().is_alphabetic()
        && name
            .chars()
            .all(|c| c.is_ascii() && (c.is_alphanumeric() || c == '_' || c == '-'))
}

/// Converts a `snake_case` identifier to an `UpperCamel` case Rust type identifier.
/// needs to match the behavior of prost_build::ident::to_upper_camel, which is private.
fn to_upper_camel(s: &str) -> String {
    let mut ident = s.to_camel_case();
    // Suffix an underscore for the `Self` Rust keyword as it is not allowed as raw identifier.
    if ident == "Self" {
        ident += "_";
    }
    ident
}

/// Conversion for a proto
fn to_module_name(package_name: &str) -> String {
    package_name
        .split('.')
        .map(|x| to_snake(x))
        .collect::<Vec<_>>()
        .join("::")
}

/// Converts a `camelCase` or `SCREAMING_SNAKE_CASE` identifier to a `lower_snake` case Rust field
/// identifier.
/// needs to match the behavior of prost_build::ident::to_snake, which is private.
fn to_snake(s: &str) -> String {
    let mut ident = s.to_snake_case();

    // Use a raw identifier if the identifier matches a Rust keyword:
    // https://doc.rust-lang.org/reference/keywords.html.
    match ident.as_str() {
        // 2015 strict keywords.
        | "as" | "break" | "const" | "continue" | "else" | "enum" | "false"
        | "fn" | "for" | "if" | "impl" | "in" | "let" | "loop" | "match" | "mod" | "move" | "mut"
        | "pub" | "ref" | "return" | "static" | "struct" | "trait" | "true"
        | "type" | "unsafe" | "use" | "where" | "while"
        // 2018 strict keywords.
        | "dyn"
        // 2015 reserved keywords.
        | "abstract" | "become" | "box" | "do" | "final" | "macro" | "override" | "priv" | "typeof"
        | "unsized" | "virtual" | "yield"
        // 2018 reserved keywords.
        | "async" | "await" | "try" => ident.insert_str(0, "r#"),
        // the following keywords are not supported as raw identifiers and are therefore suffixed with an underscore.
        "self" | "super" | "extern" | "crate" => ident += "_",
        _ => (),
    }
    ident
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_extern_path_from_str() {
        let normal = ExternPathSetArg::from_str("crate-name,/path/to/file/descriptor").unwrap();

        assert_eq!(
            normal.crate_name,
            CrateName::from_str("crate-name").unwrap()
        );
        assert_eq!(
            normal.descriptor_set,
            PathBuf::from("/path/to/file/descriptor")
        );

        assert!(ExternPathSetArg::from_str(",/path/to/file/descriptor").is_err());
        assert!(ExternPathSetArg::from_str("crate_name,").is_err());
        assert!(ExternPathSetArg::from_str("crate_name/path/to/file/descriptor").is_err());
        assert!(ExternPathSetArg::from_str("").is_err());
    }

    #[test]
    fn test_valid_crate() {
        assert!(CrateName::from_str("prost_types").is_ok());
        assert!(CrateName::from_str("prost-types").is_ok());
        assert!(CrateName::from_str("::prost-types").is_err());
        assert!(CrateName::from_str("prost-types::").is_err());
    }

    #[test]
    fn test_crate_name_for_source() {
        assert_eq!(
            CrateName::from_str("prost_types")
                .unwrap()
                .for_source()
                .as_str(),
            "prost_types"
        );
        assert_eq!(
            CrateName::from_str("prost-types")
                .unwrap()
                .for_source()
                .as_str(),
            "prost_types"
        );
    }

    #[test]
    fn test_to_module_name() {
        assert_eq!(
            to_module_name("google.protobuf").as_str(),
            "google::protobuf"
        );
        assert_eq!(
            to_module_name("google.protobuf.FileDescriptorProto").as_str(),
            "google::protobuf::file_descriptor_proto"
        );
    }

    #[test]
    fn test_path_builder() {
        let crate_name = CrateName::from_str("prost-types").unwrap();
        let builder = IndividualExternPathBuilder {
            crate_name: &crate_name,
            package_name: "google.protobuf",
        };
        assert!(builder
            .from(&prost_types::DescriptorProto::default())
            .is_err());
        assert!(builder
            .from(&prost_types::EnumDescriptorProto::default())
            .is_err());

        let valid_message = prost_types::DescriptorProto {
            name: Some("SomeMessageType".to_owned()),
            ..prost_types::DescriptorProto::default()
        };
        assert_eq!(
            builder.from(&valid_message).unwrap(),
            ExternPath {
                path: "::prost_types::google::protobuf::SomeMessageType".to_owned(),
                package: ".google.protobuf.SomeMessageType".to_owned(),
            }
        );

        let valid_enum = prost_types::EnumDescriptorProto {
            name: Some("SomeEnumType".to_owned()),
            ..prost_types::EnumDescriptorProto::default()
        };
        assert_eq!(
            builder.from(&valid_enum).unwrap(),
            ExternPath {
                path: "::prost_types::google::protobuf::SomeEnumType".to_owned(),
                package: ".google.protobuf.SomeEnumType".to_owned(),
            }
        );
    }

    #[test]
    fn test_get_all_paths() {
        let arg = ExternPathSetArg::from_str("uploader,irrelevant").unwrap();
        // Not having any files is not an error, fairly arbitrary.
        assert!(arg
            .get_all_paths(&FileDescriptorSet::default())
            .unwrap()
            .is_empty());

        assert_eq!(
            arg.get_all_paths(&FileDescriptorSet {
                file: vec![prost_types::FileDescriptorProto::default()]
            })
            .err()
            .unwrap(),
            SetLoadError::BadFileDescriptor {
                index: 0,
                error: LoadError::PackageNameUnset
            }
        );

        let valid_message = prost_types::DescriptorProto {
            name: Some("SomeMessageType".to_owned()),
            ..prost_types::DescriptorProto::default()
        };
        let valid_enum = prost_types::EnumDescriptorProto {
            name: Some("SomeEnumType".to_owned()),
            ..prost_types::EnumDescriptorProto::default()
        };
        let valid_file = prost_types::FileDescriptorProto {
            package: Some("google.protobuf".to_owned()),
            message_type: vec![valid_message],
            enum_type: vec![valid_enum],
            ..prost_types::FileDescriptorProto::default()
        };

        assert_eq!(
            arg.get_all_paths(&FileDescriptorSet {
                file: vec![valid_file]
            })
            .unwrap(),
            vec![
                ExternPath {
                    path: "::uploader::google::protobuf::SomeMessageType".to_owned(),
                    package: ".google.protobuf.SomeMessageType".to_owned(),
                },
                ExternPath {
                    path: "::uploader::google::protobuf::SomeEnumType".to_owned(),
                    package: ".google.protobuf.SomeEnumType".to_owned(),
                }
            ]
        );
    }
}
