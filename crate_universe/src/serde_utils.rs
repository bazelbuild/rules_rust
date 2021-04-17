use std::{collections::BTreeSet, fmt, path::PathBuf, str::FromStr};

use serde::{
    de::{self, Error, MapAccess, Visitor},
    Deserialize,
};

use crate::parser::{DepSpec, VersionSpec};

// Work around https://github.com/serde-rs/serde/issues/368
const fn always_true() -> bool {
    true
}

// See https://stackoverflow.com/questions/54761790/how-to-deserialize-with-for-a-container-using-serde-in-rust
pub struct DepSpecDeserializer;

#[derive(Debug, Default, Deserialize)]
#[serde(deny_unknown_fields)]
struct RawDepSpec {
    #[serde(rename = "default-features", default = "always_true")]
    default_features: bool,
    #[serde(default = "BTreeSet::new")]
    features: BTreeSet<String>,
    version: Option<String>,
    git: Option<String>,
    rev: Option<String>,
    tag: Option<String>,
    path: Option<PathBuf>,

    #[serde(skip_serializing)]
    optional: Option<bool>,
}

impl FromStr for DepSpec {
    type Err = semver::ReqParseError;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        let version = VersionSpec::Semver(semver::VersionReq::parse(s)?);
        Ok(DepSpec {
            version,
            default_features: true,
            features: BTreeSet::new(),
        })
    }
}

impl<'de> Visitor<'de> for DepSpecDeserializer {
    type Value = DepSpec;

    fn expecting(&self, formatter: &mut fmt::Formatter) -> fmt::Result {
        formatter.write_str("string or map")
    }

    fn visit_str<E>(self, value: &str) -> Result<Self::Value, E>
    where
        E: de::Error,
    {
        FromStr::from_str(value)
            .map_err(|err| E::custom(format!("Error parsing string in Cargo.toml: {:?}", err)))
    }

    fn visit_map<M>(self, visitor: M) -> Result<Self::Value, M::Error>
    where
        M: MapAccess<'de>,
    {
        let copy: RawDepSpec =
            Deserialize::deserialize(de::value::MapAccessDeserializer::new(visitor))?;

        let RawDepSpec {
            default_features,
            features,
            version,
            git,
            rev,
            tag,
            path,
            // We always generate deps for optional deps.
            optional: _,
        } = copy;

        let version = match (version, git, path, rev, tag) {
            (Some(version), None, None, None, None) => {
                VersionSpec::Semver(version.parse().map_err(M::Error::custom)?)
            }
            (None, Some(url), None, rev, tag) => VersionSpec::Git { url, rev, tag },
            (None, None, Some(path), None, None) => VersionSpec::Local(path),
            _ => return Err(M::Error::custom("Must set exactly one of version, git, or path, and may not specify git specifiers for non-git deps.")),
        };

        Ok(DepSpec {
            default_features,
            features,
            version,
        })
    }
}
