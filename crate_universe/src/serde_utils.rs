use std::{
    collections::{BTreeMap, BTreeSet},
    fmt,
    path::PathBuf,
    str::FromStr,
};

use serde::{
    de::{self, Error, MapAccess, Visitor},
    {Deserialize, Serialize},
};
use url::Url;

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
    registry: Option<String>,

    #[serde(skip_serializing)]
    optional: Option<bool>,
}

impl FromStr for DepSpec {
    type Err = semver::Error;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        let version = VersionSpec::Semver {
            version_req: semver::VersionReq::parse(s)?,
            registry: None,
        };
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
            registry,
            // We always generate deps for optional deps.
            optional: _,
        } = copy;

        let version = match (version, git, path, rev, tag, registry) {
            (Some(version), None, None, None, None, registry) => {
                VersionSpec::Semver {
                    version_req: version.parse().map_err(M::Error::custom)?,
                    registry,
                }
            }
            (None, Some(url), None, rev, tag, None) => VersionSpec::Git { url, rev, tag },
            (None, None, Some(path), None, None, None) => VersionSpec::Local(path),
            _ => return Err(M::Error::custom("Must set exactly one of version, git, or path, and may not specify git specifiers for non-git deps or registry for git deps.")),
        };

        Ok(DepSpec {
            default_features,
            features,
            version,
        })
    }
}

/// A representation of the parts of .cargo/config.toml files we generate.
#[derive(Serialize)]
pub struct CargoConfig {
    pub registries: BTreeMap<String, Registry>,
}

#[derive(Serialize)]
pub struct Registry {
    pub index: Url,
}
