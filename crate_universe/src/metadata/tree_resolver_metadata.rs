//! The output contract shared by the feature/dependency resolvers.
//!
//! [crate::metadata::TreeResolver] and [crate::metadata::GuppyResolver] compute the
//! same [TreeResolverMetadata] by very different means. Everything they agree on -
//! the shape of the data, which platforms may act as a host, and how per-platform
//! results are folded into [Select]s - lives here so the two cannot drift.

use std::collections::{BTreeMap, BTreeSet};

use anyhow::{bail, Result};
use itertools::Itertools;
use serde::{Deserialize, Serialize};

use crate::config::CrateId;
use crate::select::{Select, SelectableScalar};
use crate::utils::target_triple::TargetTriple;

/// The platform triples which ship host tools, and so may act as the platform a
/// build executes on.
///
/// This is every triple upstream marks as host-capable, not just the ones
/// `rules_rust` maps to a Bazel platform, because `supported_platform_triples` is
/// an unvalidated string list and users may name triples outside that mapping.
/// The `host_triples_with_tools_agrees_with_rules_rust` test keeps the overlap
/// honest.
///
/// Accuracy matters in both directions. Omitting a real host means no host-side
/// resolution happens for it, silently dropping `crate_features`; admitting a
/// platform that is not host-capable is worse, because host-side results are
/// filed under the host triple's key and would pollute that triple's target-side
/// entry with build script and proc macro features.
///
/// Sourced from rustc's platform support page, which is the source of truth:
/// [Tier 1](https://doc.rust-lang.org/nightly/rustc/platform-support.html#tier-1-with-host-tools)
/// [Tier 2](https://doc.rust-lang.org/nightly/rustc/platform-support.html#tier-2-with-host-tools)
/// [Tier 3](https://doc.rust-lang.org/nightly/rustc/platform-support.html#tier-3) (`host` column)
const RUSTC_TRIPLES_WITH_HOST_TOOLS: [&str; 76] = [
    // Tier 1
    "aarch64-apple-darwin",
    "aarch64-pc-windows-msvc",
    "aarch64-unknown-linux-gnu",
    "i686-unknown-linux-gnu",
    "x86_64-pc-windows-gnu",
    "x86_64-pc-windows-msvc",
    "x86_64-unknown-linux-gnu",
    // Tier 2
    "aarch64-pc-windows-gnullvm",
    "aarch64-unknown-freebsd",
    "aarch64-unknown-linux-musl",
    "aarch64-unknown-linux-ohos",
    "arm-unknown-linux-gnueabi",
    "arm-unknown-linux-gnueabihf",
    "armv7-unknown-linux-gnueabihf",
    "armv7-unknown-linux-ohos",
    "loongarch64-unknown-linux-gnu",
    "loongarch64-unknown-linux-musl",
    "powerpc-unknown-linux-gnu",
    "powerpc64-unknown-linux-gnu",
    "powerpc64-unknown-linux-musl",
    "powerpc64le-unknown-linux-gnu",
    "powerpc64le-unknown-linux-musl",
    "riscv64gc-unknown-linux-gnu",
    "riscv64gc-unknown-linux-musl",
    "s390x-unknown-linux-gnu",
    "sparcv9-sun-solaris",
    "x86_64-apple-darwin",
    "x86_64-pc-solaris",
    "x86_64-pc-windows-gnullvm",
    "x86_64-unknown-freebsd",
    "x86_64-unknown-illumos",
    "x86_64-unknown-linux-musl",
    "x86_64-unknown-linux-ohos",
    "x86_64-unknown-netbsd",
    // Tier 3
    "aarch64-unknown-illumos",
    "aarch64-unknown-linux-gnu_ilp32",
    "aarch64-unknown-linux-pauthtest",
    "aarch64-unknown-netbsd",
    "aarch64-unknown-openbsd",
    "aarch64_be-unknown-linux-gnu",
    "aarch64_be-unknown-linux-gnu_ilp32",
    "aarch64_be-unknown-linux-musl",
    "aarch64_be-unknown-netbsd",
    "arm64e-apple-darwin",
    "armv6-unknown-freebsd",
    "armv6-unknown-netbsd-eabihf",
    "armv7-unknown-freebsd",
    "armv7-unknown-linux-uclibceabi",
    "armv7-unknown-netbsd-eabihf",
    "i686-apple-darwin",
    "i686-unknown-haiku",
    "i686-unknown-hurd-gnu",
    "i686-unknown-netbsd",
    "i686-unknown-openbsd",
    "mips-unknown-linux-gnu",
    "mips64-unknown-linux-gnuabi64",
    "mips64-unknown-linux-muslabi64",
    "mips64el-unknown-linux-gnuabi64",
    "mipsel-unknown-linux-gnu",
    "mipsel-unknown-netbsd",
    "mipsisa64r6el-unknown-linux-gnuabi64",
    "powerpc-unknown-netbsd",
    "powerpc64-unknown-freebsd",
    "powerpc64-unknown-linux-gnuelfv2",
    "powerpc64-unknown-openbsd",
    "powerpc64le-unknown-freebsd",
    "riscv64gc-unknown-netbsd",
    "riscv64gc-unknown-openbsd",
    "sparc64-unknown-netbsd",
    "sparc64-unknown-openbsd",
    "x86_64-unknown-dragonfly",
    "x86_64-unknown-haiku",
    "x86_64-unknown-hurd-gnu",
    "x86_64-unknown-openbsd",
    "x86_64-win7-windows-msvc",
    "x86_64h-apple-darwin",
];

/// Feature resolver info about a given crate.
#[derive(Debug, Default, Clone, Eq, PartialEq, Serialize, Deserialize)]
pub(crate) struct CargoTreeEntry {
    /// The set of features active on a given crate.
    #[serde(default, skip_serializing_if = "BTreeSet::is_empty")]
    pub features: BTreeSet<String>,

    /// The dependencies of a given crate based on feature resolution.
    #[serde(default, skip_serializing_if = "BTreeSet::is_empty")]
    pub deps: BTreeSet<CrateId>,
}

impl CargoTreeEntry {
    pub fn new() -> Self {
        Self {
            features: BTreeSet::new(),
            deps: BTreeSet::new(),
        }
    }

    pub fn is_empty(&self) -> bool {
        self.features.is_empty() && self.deps.is_empty()
    }
}

impl SelectableScalar for CargoTreeEntry {}

/// Feature and dependency metadata generated from a resolver.
pub(crate) type TreeResolverMetadata = BTreeMap<CrateId, Select<CargoTreeEntry>>;

/// The accumulator a resolver fills in before collapsing it into
/// [TreeResolverMetadata] with [collapse_to_selects].
pub(crate) type PerTripleMetadata = BTreeMap<CrateId, BTreeMap<TargetTriple, CargoTreeEntry>>;

/// The subset of `target_triples` which ship host tools, and so may act as the
/// platform a build executes on.
///
/// Without any host triples no resolution happens at all and the resulting BUILD
/// files would silently be missing `crate_features` and optional dependencies, so
/// this bails with an actionable message instead.
pub(crate) fn host_triples_with_tools(
    target_triples: &BTreeSet<TargetTriple>,
) -> Result<BTreeSet<TargetTriple>> {
    let hosts: BTreeSet<TargetTriple> = target_triples
        .iter()
        .filter(|triple| RUSTC_TRIPLES_WITH_HOST_TOOLS.contains(&triple.to_cargo().as_str()))
        .cloned()
        .collect();

    if hosts.is_empty() {
        bail!(
            "`supported_platform_triples` contains no platforms with host tools, so feature \
             resolution cannot be performed. Bazel's execution platform triple typically should \
             be included in `supported_platform_triples` (e.g. `x86_64-unknown-linux-gnu`). \
             target_triples=[{}]",
            target_triples
                .iter()
                .map(TargetTriple::to_cargo)
                .collect::<BTreeSet<_>>()
                .iter()
                .join(", "),
        );
    }

    Ok(hosts)
}

/// Groups triples by the cargo triple they map onto, so equivalent platforms are
/// only resolved once.
pub(crate) fn group_by_cargo_triple(
    triples: &BTreeSet<TargetTriple>,
) -> BTreeMap<String, BTreeSet<TargetTriple>> {
    let mut grouped = BTreeMap::<String, BTreeSet<TargetTriple>>::new();
    for triple in triples {
        grouped
            .entry(triple.to_cargo())
            .or_default()
            .insert(triple.clone());
    }
    grouped
}

/// Merges per-crate tree data into the accumulator under the given triple.
pub(crate) fn merge_tree_data(
    metadata: &mut PerTripleMetadata,
    triple: &TargetTriple,
    tree_data: &BTreeMap<CrateId, CargoTreeEntry>,
) {
    for (crate_id, entry) in tree_data {
        let accumulated = metadata
            .entry(crate_id.clone())
            .or_default()
            .entry(triple.clone())
            .or_default();
        accumulated.features.extend(entry.features.iter().cloned());
        accumulated.deps.extend(entry.deps.iter().cloned());
    }
}

/// The intersection of every set yielded by `sets`, or an empty set if there are none.
fn intersect_all<'a, T>(mut sets: impl Iterator<Item = &'a BTreeSet<T>>) -> BTreeSet<T>
where
    T: Ord + Clone + 'a,
{
    let Some(first) = sets.next() else {
        return BTreeSet::new();
    };

    let mut common = first.clone();
    for set in sets {
        if common.is_empty() {
            break;
        }
        common.retain(|item| set.contains(item));
    }
    common
}

/// Collapses per-triple data into [Select]s, hoisting anything common to every
/// triple into the unconditional bucket.
pub(crate) fn collapse_to_selects(metadata: PerTripleMetadata) -> TreeResolverMetadata {
    let mut result = TreeResolverMetadata::new();
    for (crate_id, tree_data) in metadata.into_iter() {
        let common = CargoTreeEntry {
            features: intersect_all(tree_data.values().map(|data| &data.features)),
            deps: intersect_all(tree_data.values().map(|data| &data.deps)),
        };
        let mut select: Select<CargoTreeEntry> = Select::default();
        for (target_triple, data) in tree_data {
            let mut entry = CargoTreeEntry::new();
            entry.features.extend(
                data.features
                    .into_iter()
                    .filter(|f| !common.features.contains(f)),
            );
            entry
                .deps
                .extend(data.deps.into_iter().filter(|d| !common.deps.contains(d)));
            if !entry.is_empty() {
                select.insert(entry, Some(target_triple.to_bazel()));
            }
        }
        if !common.is_empty() {
            select.insert(common, None);
        }
        result.insert(crate_id, select);
    }
    result
}

#[cfg(test)]
mod test {
    use super::*;

    #[test]
    fn group_triples_by_cargo_triple() {
        let triples = BTreeSet::from([
            TargetTriple::from_bazel("x86_64-unknown-linux-gnu".to_owned()),
            TargetTriple::from_bazel("aarch64-apple-darwin".to_owned()),
        ]);

        let grouped = group_by_cargo_triple(&triples);

        assert_eq!(2, grouped.len());
        assert!(grouped.contains_key("x86_64-unknown-linux-gnu"));
        assert!(grouped.contains_key("aarch64-apple-darwin"));
    }

    #[test]
    fn host_triples_are_filtered_to_platforms_with_tools() {
        let triples = BTreeSet::from([
            TargetTriple::from_bazel("wasm32-unknown-unknown".to_owned()),
            TargetTriple::from_bazel("x86_64-unknown-linux-gnu".to_owned()),
        ]);

        assert_eq!(
            BTreeSet::from([TargetTriple::from_bazel(
                "x86_64-unknown-linux-gnu".to_owned()
            )]),
            host_triples_with_tools(&triples).unwrap(),
        );
    }

    #[test]
    fn host_triples_without_any_host_tools_is_an_error() {
        let triples = BTreeSet::from([TargetTriple::from_bazel("thumbv6m-none-eabi".to_owned())]);

        let msg = host_triples_with_tools(&triples).unwrap_err().to_string();

        assert!(
            msg.contains("supported_platform_triples"),
            "error message should mention `supported_platform_triples`, got: {msg}",
        );
        assert!(
            msg.contains("host tools"),
            "error message should mention host tools, got: {msg}",
        );
        assert!(
            msg.contains("thumbv6m-none-eabi"),
            "error message should list the configured target triples, got: {msg}",
        );
    }

    /// `rules_rust` records the same property as `host_tools` in
    /// `//rust/platform:triple_mappings.bzl`. Both tables are curated by hand from
    /// rustc's platform support page, so assert they agree wherever they overlap.
    /// Without this they drift silently, and both have before.
    #[test]
    fn host_triples_with_tools_agrees_with_rules_rust() {
        let parse = |value: &str| -> BTreeSet<TargetTriple> {
            value
                .split(',')
                .map(|triple| TargetTriple::from_bazel(triple.to_owned()))
                .collect()
        };
        let names = |triples: &BTreeSet<TargetTriple>| -> Vec<String> {
            triples.iter().map(TargetTriple::to_bazel).collect()
        };

        let supported = parse(env!("SUPPORTED_PLATFORM_TRIPLES"));
        let expected = parse(env!("SUPPORTED_PLATFORM_TRIPLES_WITH_HOST_TOOLS"));

        assert_eq!(
            names(&expected),
            names(&host_triples_with_tools(&supported).unwrap()),
            "`RUSTC_TRIPLES_WITH_HOST_TOOLS` disagrees with `host_tools` in \
             //rust/platform:triple_mappings.bzl. Both are curated from rustc's platform \
             support page, so update whichever one is stale.",
        );
    }

    #[test]
    fn intersect_all_of_nothing_is_empty() {
        let sets: Vec<BTreeSet<String>> = Vec::new();

        assert!(intersect_all(sets.iter()).is_empty());
    }

    #[test]
    fn intersect_all_keeps_only_shared_members() {
        let sets = [
            BTreeSet::from(["a".to_owned(), "b".to_owned(), "c".to_owned()]),
            BTreeSet::from(["b".to_owned(), "c".to_owned()]),
            BTreeSet::from(["c".to_owned(), "d".to_owned()]),
        ];

        assert_eq!(BTreeSet::from(["c".to_owned()]), intersect_all(sets.iter()));
    }
}
