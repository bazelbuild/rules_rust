use std::fmt::{self, Display};
use std::path::Path;
use std::str::FromStr;

use anyhow::{anyhow, bail, Context, Result};
use regex::Regex;
use serde::de::Visitor;
use serde::{Deserialize, Serialize, Serializer};

// Note that this type assumes there's no such thing as a relative label;
// `:foo` is assumed to be relative to the repo root, and parses out to equivalent to `//:foo`.
#[derive(Debug, Default, PartialEq, Eq, PartialOrd, Ord, Clone)]
pub struct Label {
    pub repository: Option<String>,
    pub package: Option<String>,
    pub target: String,
}

impl FromStr for Label {
    type Err = anyhow::Error;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        let re = Regex::new(r"^(@@?[\w\d\-_\.]*)?/{0,2}([\w\d\-_\./+]+)?(:([\+\w\d\-_\./]+))?$")?;
        let cap = re
            .captures(s)
            .with_context(|| format!("Failed to parse label from string: {s}"))?;

        let repository = cap
            .get(1)
            .map(|m| m.as_str().trim_start_matches('@').to_owned());

        let package = cap.get(2).map(|m| m.as_str().to_owned());
        let mut target = cap.get(4).map(|m| m.as_str().to_owned());

        if target.is_none() {
            if let Some(pkg) = &package {
                target = Some(pkg.clone());
            } else if let Some(repo) = &repository {
                target = Some(repo.clone())
            } else {
                bail!("The label is missing a label")
            }
        }

        // The target should be set at this point
        let target = target.unwrap();

        Ok(Self {
            repository,
            package,
            target,
        })
    }
}

impl Display for Label {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        // Add the repository
        if let Some(repo) = &self.repository {
            write!(f, "@{repo}")?;
        }

        write!(f, "//")?;

        // Add the package
        if let Some(pkg) = &self.package {
            write!(f, "{pkg}")?;
        }

        write!(f, ":{}", self.target)?;

        Ok(())
    }
}

impl Label {
    /// Generates a label appropriate for the passed Path by walking the filesystem to identify its
    /// workspace and package.
    pub fn from_absolute_path(p: &Path) -> Result<Self, anyhow::Error> {
        let mut workspace_root = None;
        let mut package_root = None;
        for ancestor in p.ancestors().skip(1) {
            if package_root.is_none()
                && (ancestor.join("BUILD").exists() || ancestor.join("BUILD.bazel").exists())
            {
                package_root = Some(ancestor);
            }
            if workspace_root.is_none()
                && (ancestor.join("WORKSPACE").exists()
                    || ancestor.join("WORKSPACE.bazel").exists())
            {
                workspace_root = Some(ancestor);
                break;
            }
        }
        match (workspace_root, package_root) {
            (Some(workspace_root), Some(package_root)) => {
                // These unwraps are safe by construction of the ancestors and prefix calls which set up these paths.
                let target = p.strip_prefix(package_root).unwrap();
                let workspace_relative = p.strip_prefix(workspace_root).unwrap();
                let mut package_path = workspace_relative.to_path_buf();
                for _ in target.components() {
                    package_path.pop();
                }

                let package = if package_path.components().count() > 0 {
                    Some(path_to_label_part(&package_path)?)
                } else {
                    None
                };
                let target = path_to_label_part(target)?;

                Ok(Label {
                    repository: None,
                    package,
                    target,
                })
            }
            (Some(_workspace_root), None) => {
                bail!(
                    "Could not identify package for path {}. Maybe you need to add a BUILD.bazel file.",
                    p.display()
                );
            }
            _ => {
                bail!("Could not identify workspace for path {}", p.display());
            }
        }
    }
}

/// Converts a path to a forward-slash-delimited label-appropriate path string.
fn path_to_label_part(path: &Path) -> Result<String, anyhow::Error> {
    let components: Result<Vec<_>, _> = path
        .components()
        .map(|c| {
            c.as_os_str().to_str().ok_or_else(|| {
                anyhow!(
                    "Found non-UTF8 component turning path into label: {}",
                    path.display()
                )
            })
        })
        .collect();
    Ok(components?.join("/"))
}

impl Serialize for Label {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        serializer.serialize_str(&self.repr())
    }
}

struct LabelVisitor;
impl<'de> Visitor<'de> for LabelVisitor {
    type Value = Label;

    fn expecting(&self, formatter: &mut fmt::Formatter) -> fmt::Result {
        formatter.write_str("Expected string value of `{name} {version}`.")
    }

    fn visit_str<E>(self, v: &str) -> Result<Self::Value, E>
    where
        E: serde::de::Error,
    {
        Label::from_str(v).map_err(E::custom)
    }
}

impl<'de> Deserialize<'de> for Label {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        deserializer.deserialize_str(LabelVisitor)
    }
}

impl Label {
    pub fn repr(&self) -> String {
        self.to_string()
    }
}

#[cfg(test)]
mod test {
    use super::*;
    use spectral::prelude::*;
    use std::fs::{create_dir_all, File};
    use tempfile::tempdir;

    #[test]
    fn full_label_bzlmod() {
        let label = Label::from_str("@@repo//package/sub_package:target").unwrap();
        assert_eq!(label.to_string(), "@repo//package/sub_package:target");
        assert_eq!(label.repository.unwrap(), "repo");
        assert_eq!(label.package.unwrap(), "package/sub_package");
        assert_eq!(label.target, "target");
    }

    #[test]
    fn full_label() {
        let label = Label::from_str("@repo//package/sub_package:target").unwrap();
        assert_eq!(label.to_string(), "@repo//package/sub_package:target");
        assert_eq!(label.repository.unwrap(), "repo");
        assert_eq!(label.package.unwrap(), "package/sub_package");
        assert_eq!(label.target, "target");
    }

    #[test]
    fn no_repository() {
        let label = Label::from_str("//package:target").unwrap();
        assert_eq!(label.to_string(), "//package:target");
        assert_eq!(label.repository, None);
        assert_eq!(label.package.unwrap(), "package");
        assert_eq!(label.target, "target");
    }

    #[test]
    fn no_slashes() {
        let label = Label::from_str("package:target").unwrap();
        assert_eq!(label.to_string(), "//package:target");
        assert_eq!(label.repository, None);
        assert_eq!(label.package.unwrap(), "package");
        assert_eq!(label.target, "target");
    }

    #[test]
    fn root_label() {
        let label = Label::from_str("@repo//:target").unwrap();
        assert_eq!(label.to_string(), "@repo//:target");
        assert_eq!(label.repository.unwrap(), "repo");
        assert_eq!(label.package, None);
        assert_eq!(label.target, "target");
    }

    #[test]
    fn root_label_no_repository() {
        let label = Label::from_str("//:target").unwrap();
        assert_eq!(label.to_string(), "//:target");
        assert_eq!(label.repository, None);
        assert_eq!(label.package, None);
        assert_eq!(label.target, "target");
    }

    #[test]
    fn root_label_no_slashes() {
        let label = Label::from_str(":target").unwrap();
        assert_eq!(label.to_string(), "//:target");
        assert_eq!(label.repository, None);
        assert_eq!(label.package, None);
        assert_eq!(label.target, "target");
    }

    #[test]
    fn full_label_with_slash_after_colon() {
        let label = Label::from_str("@repo//package/sub_package:subdir/target").unwrap();
        assert_eq!(
            label.to_string(),
            "@repo//package/sub_package:subdir/target"
        );
        assert_eq!(label.repository.unwrap(), "repo");
        assert_eq!(label.package.unwrap(), "package/sub_package");
        assert_eq!(label.target, "subdir/target");
    }

    #[test]
    fn label_contains_plus() {
        let label = Label::from_str("@repo//vendor/wasi-0.11.0+wasi-snapshot-preview1:BUILD.bazel")
            .unwrap();
        assert_eq!(label.repository.unwrap(), "repo");
        assert_eq!(
            label.package.unwrap(),
            "vendor/wasi-0.11.0+wasi-snapshot-preview1"
        );
        assert_eq!(label.target, "BUILD.bazel");
    }

    #[test]
    fn invalid_double_colon() {
        assert!(Label::from_str("::target").is_err());
    }

    #[test]
    fn invalid_triple_at() {
        assert!(Label::from_str("@@@repo//pkg:target").is_err());
    }

    #[test]
    #[ignore = "This currently fails. The Label parsing logic needs to be updated"]
    fn invalid_no_double_slash() {
        assert!(Label::from_str("@repo:target").is_err());
    }

    #[test]
    fn from_absolute_path_exists() {
        let dir = tempdir().unwrap();
        let workspace = dir.path().join("WORKSPACE.bazel");
        let build_file = dir.path().join("parent").join("child").join("BUILD.bazel");
        let subdir = dir.path().join("parent").join("child").join("grandchild");
        let actual_file = subdir.join("greatgrandchild");
        create_dir_all(subdir).unwrap();
        {
            File::create(workspace).unwrap();
            File::create(build_file).unwrap();
            File::create(&actual_file).unwrap();
        }
        let label = Label::from_absolute_path(&actual_file).unwrap();
        assert_eq!(label.repository, None);
        assert_eq!(label.package.unwrap(), "parent/child");
        assert_eq!(label.target, "grandchild/greatgrandchild")
    }

    #[test]
    fn from_absolute_path_no_workspace() {
        let dir = tempdir().unwrap();
        let build_file = dir.path().join("parent").join("child").join("BUILD.bazel");
        let subdir = dir.path().join("parent").join("child").join("grandchild");
        let actual_file = subdir.join("greatgrandchild");
        create_dir_all(subdir).unwrap();
        {
            File::create(build_file).unwrap();
            File::create(&actual_file).unwrap();
        }
        let err = Label::from_absolute_path(&actual_file)
            .unwrap_err()
            .to_string();
        assert_that(&err).contains("Could not identify workspace");
        assert_that(&err).contains(format!("{}", actual_file.display()).as_str());
    }

    #[test]
    fn from_absolute_path_no_build_file() {
        let dir = tempdir().unwrap();
        let workspace = dir.path().join("WORKSPACE.bazel");
        let subdir = dir.path().join("parent").join("child").join("grandchild");
        let actual_file = subdir.join("greatgrandchild");
        create_dir_all(subdir).unwrap();
        {
            File::create(workspace).unwrap();
            File::create(&actual_file).unwrap();
        }
        let err = Label::from_absolute_path(&actual_file)
            .unwrap_err()
            .to_string();
        assert_that(&err).contains("Could not identify package");
        assert_that(&err).contains("Maybe you need to add a BUILD.bazel file");
        assert_that(&err).contains(format!("{}", actual_file.display()).as_str());
    }
}
