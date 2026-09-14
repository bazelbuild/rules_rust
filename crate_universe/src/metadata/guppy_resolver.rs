//! Tools for producing Crate metadata using [guppy]'s simulation of Cargo's
//! dependency and feature resolution.
//!
//! This is the default resolver. It produces the same [TreeResolverMetadata] as the
//! legacy [crate::metadata::TreeResolver] but computes it in-process from a single
//! `cargo metadata` invocation instead of spawning
//! `{HOST_TRIPLES} * {TARGET_TRIPLES}` `cargo tree` processes. Setting
//! `RULES_RUST_CRATE_UNIVERSE_INCOMPATIBLE_GUPPY_RESOLVER=0` falls back to the
//! legacy resolver.
//!
//! Because guppy takes the host and target platforms as independent parameters, this
//! resolver needs neither the `RUSTC_WRAPPER` shim used to spoof the host platform nor
//! the synthetic proc-macro root package used to force proc-macros to resolve on every
//! platform. Both exist in [crate::metadata::cargo_tree_resolver] purely to work around
//! `cargo tree` having a single, implicit host.
//!
//! [guppy]: https://docs.rs/guppy

use std::collections::{BTreeMap, BTreeSet};
use std::path::Path;
use std::process::Command;
use std::sync::Arc;
use std::thread;

use anyhow::{bail, Context, Result};
use camino::Utf8Path;
use guppy::graph::cargo::{CargoOptions, CargoResolverVersion, CargoSet};
use guppy::graph::feature::{FeatureSet, StandardFeatures};
use guppy::graph::{DependencyDirection, PackageGraph, PackageMetadata};
use guppy::platform::{Platform, TargetFeatures};
use tracing::{debug, trace};

use crate::config::CrateId;
use crate::metadata::cargo_bin::Cargo;
use crate::metadata::tree_resolver_metadata::{
    collapse_to_selects, group_by_cargo_triple, host_triples_with_tools, merge_tree_data,
    CargoTreeEntry, PerTripleMetadata, TreeResolverMetadata,
};
use crate::utils::target_triple::TargetTriple;

/// The resolution of a single (host, target) pair, split by which side each crate
/// is built for.
struct PairResolution {
    target_tree_data: BTreeMap<CrateId, CargoTreeEntry>,
    host_tree_data: BTreeMap<CrateId, CargoTreeEntry>,
}

/// Generates metadata about a Cargo workspace tree using guppy's Cargo build
/// simulation. See the module documentation for how this differs from
/// [crate::metadata::TreeResolver].
pub(crate) struct GuppyResolver {
    /// The path to a `cargo` binary
    cargo_bin: Cargo,
}

impl GuppyResolver {
    pub(crate) fn new(cargo_bin: Cargo) -> Self {
        Self { cargo_bin }
    }

    /// Computes the set of enabled features and resolved dependencies for each
    /// target triplet for each crate.
    ///
    /// The signature and return value match [crate::metadata::TreeResolver::generate]
    /// so the two are interchangeable.
    #[tracing::instrument(name = "GuppyResolver::generate", skip_all)]
    pub(crate) fn generate(
        &self,
        pristine_manifest_path: &Utf8Path,
        target_triples: &BTreeSet<TargetTriple>,
    ) -> Result<TreeResolverMetadata> {
        debug!(
            "Generating features for manifest {} using guppy",
            pristine_manifest_path
        );

        // Mirrors `TreeResolver::generate`: only platforms which ship host tools are
        // considered as hosts. guppy itself has no such restriction (the host platform
        // is just another parameter) but matching the set keeps the output identical.
        let host_triples = host_triples_with_tools(target_triples)?;

        // We only want to resolve once per unique cargo platform, then replicate the
        // result across every Bazel triple that maps onto it.
        let cargo_host_triples = group_by_cargo_triple(&host_triples);
        let cargo_target_triples = group_by_cargo_triple(target_triples);

        let package_graph = self.build_package_graph(pristine_manifest_path)?;
        let resolver = resolver_version(pristine_manifest_path)?;

        // Build a `Platform` per unique cargo triple from real `rustc --print=cfg`
        // output. Using rustc rather than guppy's built-in target database means
        // `cfg(target_feature = "...")` and out-of-tree triples evaluate the same way
        // they did under `cargo tree`. Hosts are a subset of the targets, so the target
        // triples alone cover every platform needed below.
        let platforms = cargo_target_triples
            .keys()
            .map(|triple| {
                let platform = self.platform_for_triple(triple)?;
                Ok((triple.clone(), Arc::new(platform)))
            })
            .collect::<Result<BTreeMap<String, Arc<Platform>>>>()?;

        // The initials are what Cargo starts resolution from and do not vary with the
        // platform pair. Building them here also warms the feature graph guppy builds
        // lazily, which the workers below would otherwise race to build a copy of.
        let initials = package_graph
            .resolve_workspace()
            .to_feature_set(StandardFeatures::Default);

        let jobs: Vec<(&String, &String)> = cargo_host_triples
            .keys()
            .flat_map(|host| {
                cargo_target_triples
                    .keys()
                    .map(move |target| (host, target))
            })
            .collect();

        // Each pair is independent and only reads the package graph, so spread them
        // over the available cores rather than resolving `{HOSTS} * {TARGETS}` pairs
        // one at a time.
        let max_parallel = thread::available_parallelism()
            .map(|n| n.get())
            .unwrap_or(4);
        let chunk_size = jobs.len().div_ceil(max_parallel).max(1);

        let resolutions = thread::scope(|scope| -> Result<Vec<PairResolution>> {
            let workers: Vec<_> = jobs
                .chunks(chunk_size)
                .map(|chunk| {
                    let (initials, platforms) = (&initials, &platforms);
                    scope.spawn(move || {
                        chunk
                            .iter()
                            .map(|(host, target)| {
                                resolve_pair(initials, platforms, resolver, host, target)
                            })
                            .collect::<Result<Vec<_>>>()
                    })
                })
                .collect();

            let mut resolutions = Vec::with_capacity(jobs.len());
            for worker in workers {
                resolutions.extend(worker.join().expect("worker thread panicked")?);
            }
            Ok(resolutions)
        })?;

        // Replicate outputs for any de-duplicated platforms. Target-side data is keyed
        // by the target triple and host-side data by the host triple, matching how
        // `TreeResolver` splits `cargo tree` output.
        let mut metadata = PerTripleMetadata::new();
        for ((cargo_host, cargo_target), resolution) in jobs.iter().zip(resolutions) {
            for target_plat in &cargo_target_triples[*cargo_target] {
                merge_tree_data(&mut metadata, target_plat, &resolution.target_tree_data);
            }
            for host_plat in &cargo_host_triples[*cargo_host] {
                merge_tree_data(&mut metadata, host_plat, &resolution.host_tree_data);
            }
        }

        Ok(collapse_to_selects(metadata))
    }

    /// Runs `cargo metadata` and builds a guppy [PackageGraph] from the output.
    ///
    /// `--all-features` is required: guppy derives dependency edges from
    /// `resolve.nodes`, which omits optional dependencies that are not enabled by
    /// default. Feature resolution itself is performed by guppy against the
    /// `StandardFeatures::Default` initials, so this only widens the graph guppy is
    /// allowed to see, not the features it reports.
    fn build_package_graph(&self, manifest_path: &Utf8Path) -> Result<PackageGraph> {
        let output = self
            .cargo_bin
            .metadata_command_with_options(
                manifest_path.as_std_path(),
                vec!["--locked".to_owned(), "--all-features".to_owned()],
            )?
            .cargo_command()
            .output()
            .with_context(|| {
                format!(
                    "Error spawning cargo in child process to compute metadata for manifest '{}'",
                    manifest_path
                )
            })?;

        if !output.status.success() {
            tracing::error!("{}", String::from_utf8_lossy(&output.stderr));
            bail!("Failed to run cargo metadata: {}", output.status);
        }

        let json = String::from_utf8(output.stdout)
            .context("`cargo metadata` produced output which was not valid UTF-8")?;

        PackageGraph::from_json(&json)
            .map_err(anyhow::Error::new)
            .with_context(|| {
                format!(
                    "Failed to build a package graph from the metadata of '{}'",
                    manifest_path
                )
            })
    }

    /// Builds a guppy [Platform] for a cargo target triple from the output of
    /// `rustc --print=cfg --target={triple}`.
    fn platform_for_triple(&self, triple: &str) -> Result<Platform> {
        let cfg_text = rustc_print_cfg(self.cargo_bin.rustc_path(), triple)?;
        let target_features = parse_target_features(&cfg_text);

        Platform::new_custom_cfg(triple.to_owned(), &cfg_text, target_features)
            .map_err(anyhow::Error::new)
            .with_context(|| format!("Failed to build a platform for the triple '{triple}'"))
    }
}

/// Simulates a Cargo build of the workspace for a single (host, target) pair.
fn resolve_pair<'g>(
    initials: &FeatureSet<'g>,
    platforms: &BTreeMap<String, Arc<Platform>>,
    resolver: CargoResolverVersion,
    cargo_host: &str,
    cargo_target: &str,
) -> Result<PairResolution> {
    trace!("Simulating Cargo build for host `{cargo_host}` targeting `{cargo_target}`");

    let mut opts = CargoOptions::new();
    opts.set_resolver(resolver)
        // `cargo tree` was invoked with `--edges normal,build,dev`.
        .set_include_dev(true)
        .set_host_platform(platforms[cargo_host].clone())
        .set_target_platform(platforms[cargo_target].clone());

    let cargo_set = initials.clone().into_cargo_set(&opts).with_context(|| {
        format!("Failed to simulate Cargo build for host `{cargo_host}` targeting `{cargo_target}`")
    })?;

    Ok(PairResolution {
        target_tree_data: collect_tree_data(
            cargo_set.target_features(),
            target_side_links(&cargo_set),
        ),
        host_tree_data: collect_tree_data(
            cargo_set.host_features(),
            cargo_set.host_links().map(|link| link.endpoints()),
        ),
    })
}

/// The dependency edges belonging to the target side of a build.
///
/// `cargo tree` attributes a dependency edge to the side its *parent* is built for,
/// while a crate's features are attributed to the side that crate itself is built
/// for. Proc-macro and build-dependency links cross from a target parent to a host
/// child, so the edges belong to the target side even though the child's features
/// are reported under the host. guppy keeps those two categories out of both
/// `target_links` and `host_links`, so they have to be folded back in explicitly.
fn target_side_links<'a, 'g>(
    cargo_set: &'a CargoSet<'g>,
) -> impl Iterator<Item = (PackageMetadata<'g>, PackageMetadata<'g>)> + 'a {
    cargo_set
        .target_links()
        .chain(cargo_set.proc_macro_links())
        .chain(cargo_set.build_dep_links())
        .map(|link| link.endpoints())
}

/// Runs `rustc --print=cfg --target={triple}` and returns its stdout.
fn rustc_print_cfg(rustc: &Path, triple: &str) -> Result<String> {
    let output = Command::new(rustc)
        .arg("--print=cfg")
        .arg(format!("--target={triple}"))
        .output()
        .with_context(|| {
            format!(
                "Error spawning `{} --print=cfg --target={}`",
                rustc.display(),
                triple
            )
        })?;

    if !output.status.success() {
        tracing::error!("{}", String::from_utf8_lossy(&output.stderr));
        bail!(
            "Failed to query rustc for the cfg values of the target triple '{}': {}",
            triple,
            output.status
        );
    }

    String::from_utf8(output.stdout)
        .with_context(|| format!("`rustc --print=cfg --target={triple}` emitted invalid UTF-8"))
}

/// Extracts the `target_feature="..."` values from `rustc --print=cfg` output.
///
/// `Platform::new_custom_cfg` parses the cfg text for target info but requires target
/// features to be passed separately. Supplying them (instead of
/// [TargetFeatures::Unknown]) matters because guppy treats an unknown result as
/// enabled, which would over-report dependencies gated on `cfg(target_feature = ...)`.
fn parse_target_features(cfg_text: &str) -> TargetFeatures {
    // `TargetFeatures::features` requires `Cow<'static, str>`, so the values must be
    // owned rather than borrowed from `cfg_text`.
    let features: BTreeSet<String> = cfg_text
        .lines()
        .filter_map(|line| line.trim().strip_prefix("target_feature="))
        .map(|value| value.trim_matches('"').to_owned())
        .collect();

    TargetFeatures::features(features)
}

/// Converts a guppy package into the [CrateId] used throughout `cargo-bazel`.
fn crate_id(package: &PackageMetadata<'_>) -> CrateId {
    CrateId::new(package.name().to_owned(), package.version().clone())
}

/// Folds a resolved feature set and its dependency edges into the per-crate shape
/// produced by parsing `cargo tree` output.
fn collect_tree_data<'g>(
    features: &FeatureSet<'g>,
    links: impl Iterator<Item = (PackageMetadata<'g>, PackageMetadata<'g>)>,
) -> BTreeMap<CrateId, CargoTreeEntry> {
    let mut tree_data = BTreeMap::<CrateId, CargoTreeEntry>::new();

    for feature_list in features.packages_with_features(DependencyDirection::Forward) {
        // `named_features` covers both features declared in `[features]` and the
        // implicit features created by optional dependencies, which is exactly what
        // `cargo tree --format={f}` prints. The `dep:name` labels guppy also tracks are
        // deliberately excluded.
        tree_data
            .entry(crate_id(feature_list.package()))
            .or_default()
            .features
            .extend(feature_list.named_features().map(str::to_owned));
    }

    for (from, to) in links {
        tree_data
            .entry(crate_id(&from))
            .or_default()
            .deps
            .insert(crate_id(&to));
    }

    tree_data
}

/// Reads the resolver version out of the workspace manifest.
///
/// `cargo tree` picks this up implicitly from the manifest it is pointed at, so the
/// guppy resolver has to read it explicitly to match. Getting this wrong is not a
/// subtle error: the v1 resolver unions features across every platform and ignores
/// target-specific dependency filtering, so target-gated optional dependencies leak
/// onto platforms that should not have them.
fn resolver_version(manifest_path: &Utf8Path) -> Result<CargoResolverVersion> {
    let manifest = cargo_toml::Manifest::from_path(manifest_path.as_std_path())
        .with_context(|| format!("Failed to parse Cargo.toml file at {manifest_path}"))?;

    let explicit = manifest
        .workspace
        .as_ref()
        .and_then(|workspace| workspace.resolver.as_ref())
        .or_else(|| {
            manifest
                .package
                .as_ref()
                .and_then(|package| package.resolver.as_ref())
        });

    if let Some(resolver) = explicit {
        return Ok(match resolver {
            cargo_toml::Resolver::V1 => CargoResolverVersion::V1,
            cargo_toml::Resolver::V2 => CargoResolverVersion::V2,
            // `cargo_toml::Resolver` is `#[non_exhaustive]`. Treat anything newer as
            // the newest resolver we know about rather than silently falling back to
            // v1, which resolves features far more coarsely.
            _ => CargoResolverVersion::V3,
        });
    }

    // With no explicit `resolver`, Cargo derives the default from the edition of the
    // package at the workspace root. A virtual manifest has no such package and stays
    // on the v1 resolver no matter what editions its members declare (Cargo warns
    // about this rather than inferring a version).
    //
    // https://doc.rust-lang.org/cargo/reference/resolver.html#resolver-versions
    let edition = manifest
        .package
        .as_ref()
        .map(|package| package.edition())
        .unwrap_or(cargo_toml::Edition::E2015);

    Ok(match edition {
        cargo_toml::Edition::E2015 | cargo_toml::Edition::E2018 => CargoResolverVersion::V1,
        cargo_toml::Edition::E2021 => CargoResolverVersion::V2,
        // `cargo_toml::Edition` is `#[non_exhaustive]`; editions past 2024 keep the
        // newest resolver we know about.
        _ => CargoResolverVersion::V3,
    })
}

#[cfg(test)]
mod test {
    use super::*;

    #[test]
    fn parse_target_features_from_cfg() {
        let cfg_text = indoc::indoc! {r#"
            debug_assertions
            panic="unwind"
            target_arch="x86_64"
            target_endian="little"
            target_env="gnu"
            target_family="unix"
            target_feature="fxsr"
            target_feature="sse"
            target_feature="sse2"
            target_os="linux"
            target_pointer_width="64"
            unix
        "#};

        assert_eq!(
            TargetFeatures::features(["fxsr", "sse", "sse2"]),
            parse_target_features(cfg_text)
        );
    }

    #[test]
    fn parse_target_features_when_absent() {
        let cfg_text = indoc::indoc! {r#"
            target_arch="wasm32"
            target_endian="little"
            target_family="wasm"
            target_os="unknown"
            target_pointer_width="32"
        "#};

        assert_eq!(
            TargetFeatures::features(std::iter::empty::<&str>()),
            parse_target_features(cfg_text)
        );
    }

    /// Real `rustc --print=cfg --target=x86_64-unknown-linux-gnu` output.
    const X86_64_LINUX_GNU_CFG: &str = indoc::indoc! {r#"
        debug_assertions
        panic="unwind"
        target_abi=""
        target_arch="x86_64"
        target_endian="little"
        target_env="gnu"
        target_family="unix"
        target_feature="fxsr"
        target_feature="sse"
        target_feature="sse2"
        target_has_atomic="16"
        target_has_atomic="32"
        target_has_atomic="64"
        target_has_atomic="8"
        target_has_atomic="ptr"
        target_has_atomic_primitive_alignment="16"
        target_has_atomic_primitive_alignment="32"
        target_has_atomic_primitive_alignment="64"
        target_has_atomic_primitive_alignment="8"
        target_has_atomic_primitive_alignment="ptr"
        target_os="linux"
        target_pointer_width="64"
        target_vendor="unknown"
        unix
    "#};

    /// A platform built from `rustc --print=cfg` has to evaluate `cfg(...)`
    /// predicates exactly as Cargo does, since that is what decides whether a
    /// target-gated dependency is pulled in.
    #[test]
    fn custom_cfg_platform_evaluates_predicates() {
        let platform = Platform::new_custom_cfg(
            "x86_64-unknown-linux-gnu".to_owned(),
            X86_64_LINUX_GNU_CFG,
            parse_target_features(X86_64_LINUX_GNU_CFG),
        )
        .unwrap();

        for (spec, expected) in [
            (r#"cfg(target_os = "linux")"#, true),
            (r#"cfg(unix)"#, true),
            (r#"cfg(windows)"#, false),
            (r#"cfg(target_arch = "x86_64")"#, true),
            (r#"cfg(target_arch = "aarch64")"#, false),
            (r#"cfg(target_feature = "sse2")"#, true),
            (r#"cfg(target_feature = "avx512f")"#, false),
            // Unrecognized bare flags (`rustix_use_libc`, `miri`, ...) must be
            // false, not unknown, or every dependency gated behind one is pulled
            // in on every platform.
            (r#"cfg(rustix_use_libc)"#, false),
            (r#"cfg(not(rustix_use_libc))"#, true),
        ] {
            let parsed: target_spec::TargetSpec = spec.parse().unwrap();
            assert_eq!(
                Some(expected),
                parsed.eval(&platform),
                "unexpected evaluation of `{spec}`"
            );
        }
    }

    /// Writes `contents` to a `Cargo.toml` in a fresh temp dir and resolves its
    /// resolver version.
    fn resolver_version_of(name: &str, contents: &str) -> CargoResolverVersion {
        let (_tempdir, dir) = crate::test::test_tempdir(name);
        let manifest_path = dir.join("Cargo.toml");
        std::fs::write(&manifest_path, contents).unwrap();
        resolver_version(Utf8Path::from_path(&manifest_path).unwrap()).unwrap()
    }

    #[test]
    fn resolver_version_is_read_from_the_manifest() {
        assert_eq!(
            CargoResolverVersion::V2,
            resolver_version_of(
                "explicit_resolver",
                indoc::indoc! {r#"
                    [workspace]
                    resolver = "2"

                    [package]
                    name = "example"
                    version = "0.0.0"
                    edition = "2015"
                "#},
            ),
        );
    }

    /// Cargo infers the resolver from the edition of the package at the workspace
    /// root when no `resolver` is declared. Defaulting to v1 here instead would
    /// union features across platforms and pull target-gated optional dependencies
    /// onto every platform.
    #[test]
    fn resolver_version_defaults_to_the_edition_default() {
        for (edition, expected) in [
            ("2015", CargoResolverVersion::V1),
            ("2018", CargoResolverVersion::V1),
            ("2021", CargoResolverVersion::V2),
            ("2024", CargoResolverVersion::V3),
        ] {
            assert_eq!(
                expected,
                resolver_version_of(
                    &format!("edition_{edition}"),
                    &format!(
                        indoc::indoc! {r#"
                            [workspace]

                            [package]
                            name = "example"
                            version = "0.0.0"
                            edition = "{}"
                        "#},
                        edition,
                    ),
                ),
                "unexpected resolver for edition {edition}",
            );
        }
    }

    /// A virtual manifest has no root package to take an edition from, so Cargo
    /// leaves it on the v1 resolver.
    #[test]
    fn resolver_version_of_a_virtual_manifest_defaults_to_v1() {
        assert_eq!(
            CargoResolverVersion::V1,
            resolver_version_of(
                "virtual_manifest",
                indoc::indoc! {r#"
                    [workspace]
                    members = []
                "#},
            ),
        );
    }
}
