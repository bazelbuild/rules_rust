//! Crate metadata from Cargo's own feature resolver, through the
//! `cargo_resolver` crate extracted from Cargo.
//!
//! [TreeResolverMetadata] is computed in-process from one `cargo metadata` call.
//! The package graph it reports is rebuilt as Cargo's `Resolve`, and Cargo's
//! feature resolver runs over it once per (host, target) pair with the host an
//! explicit input. The dependencies of proc-macros and build scripts are
//! resolved for the host that builds them and recorded under that triple, which
//! is where Bazel analyzes them. `cfg(...)` dependencies are evaluated against
//! the recorded `rustc --print=cfg` table, so the resolution does not depend on
//! the rustc at hand.

use std::collections::{BTreeMap, BTreeSet, HashMap, HashSet};
use std::path::Path;

use anyhow::{bail, Context, Result};
use camino::Utf8Path;
use cargo_metadata::{DependencyKind, Metadata, TargetKind};
use cargo_platform::{Cfg, Platform};
use cargo_resolver::util::data_structures::{HashMap as FxHashMap, HashSet as FxHashSet};
use cargo_resolver::{
    CliFeatures, CompileKind, CompileTarget, DepKind, Dependency, FeatureOpts, FeatureResolver,
    FeaturesFor, GlobalContext, Graph, HasDevUnits, InternedString, Package, PackageId, PackageSet,
    Resolve, ResolveBehavior, ResolveVersion, ResolvedFeatures, RustcTargetData, Shell, SourceId,
    Summary, Target, Workspace,
};
use cargo_util_schemas::lockfile::TomlLockfileMetadata;
use cargo_util_schemas::manifest::RustVersion;
use tracing::{debug, trace, warn};

use crate::config::CrateId;
use crate::metadata::cargo_bin::Cargo;
use crate::metadata::rustc_cfgs::{print_cfg, RustcCfgs};
use crate::metadata::tree_resolver_metadata::{
    collapse_to_selects, group_by_cargo_triple, host_triples_with_tools, merge_tree_data,
    CargoTreeEntry, PerTripleMetadata, TreeResolverMetadata,
};
use crate::utils::target_triple::TargetTriple;

/// Generates metadata about a Cargo workspace tree with Cargo's feature resolver.
pub(crate) struct CargoResolver {
    /// The path to a `cargo` binary
    cargo_bin: Cargo,
}

impl CargoResolver {
    pub(crate) fn new(cargo_bin: Cargo) -> Self {
        Self { cargo_bin }
    }

    /// Computes the set of enabled features and resolved dependencies for each
    /// target triplet for each crate.
    #[tracing::instrument(name = "CargoResolver::generate", skip_all)]
    pub(crate) fn generate(
        &self,
        pristine_manifest_path: &Utf8Path,
        target_triples: &BTreeSet<TargetTriple>,
    ) -> Result<TreeResolverMetadata> {
        debug!(
            "Generating features for manifest {} with Cargo's resolver",
            pristine_manifest_path
        );

        let host_triples = host_triples_with_tools(target_triples)?;
        let cargo_host_triples = group_by_cargo_triple(&host_triples);
        let cargo_target_triples = group_by_cargo_triple(target_triples);

        let metadata = self.cargo_metadata(pristine_manifest_path)?;
        let behavior = resolve_behavior(pristine_manifest_path)?;

        // Hosts are a subset of the targets, so the target triples cover every
        // platform needed below.
        let mut cfgs = BTreeMap::<String, Vec<Cfg>>::new();
        for triple in cargo_target_triples.keys() {
            cfgs.insert(triple.clone(), self.cfgs_for_triple(triple)?);
        }
        let platform_cfgs: Vec<(String, Vec<Cfg>)> = cfgs
            .iter()
            .map(|(triple, cfgs)| (triple.clone(), cfgs.clone()))
            .collect();

        ensure_dependencies_resolved(pristine_manifest_path, &metadata, &platform_cfgs)?;

        let graph = ResolveGraph::build(&metadata)?;
        let manifest_dir = pristine_manifest_path
            .parent()
            .expect("manifest paths always have a parent directory")
            .as_std_path();
        let gctx = GlobalContext::new(Shell::new(), manifest_dir.into(), manifest_dir.into());
        let mut ws = Workspace::new(&gctx, graph.members.clone());
        ws.set_resolve_behavior(behavior);
        let package_set = PackageSet::new(graph.packages.clone());

        // A pair resolves in well under a millisecond per hundred packages, so
        // the pairs are resolved one after another.
        let mut per_triple = PerTripleMetadata::new();
        for (cargo_host, host_plats) in &cargo_host_triples {
            for (cargo_target, target_plats) in &cargo_target_triples {
                let resolution = resolve_pair(
                    &graph,
                    &ws,
                    &package_set,
                    &cfgs,
                    behavior,
                    cargo_host,
                    cargo_target,
                )?;
                for target_plat in target_plats {
                    merge_tree_data(&mut per_triple, target_plat, &resolution.target_tree_data);
                }
                for host_plat in host_plats {
                    merge_tree_data(&mut per_triple, host_plat, &resolution.host_tree_data);
                }
            }
        }
        Ok(collapse_to_selects(per_triple))
    }

    /// Runs `cargo metadata --all-features --locked`.
    ///
    /// `--all-features` is required: the `resolve` section omits optional
    /// dependencies nothing enables by default, and the feature resolver needs
    /// the complete graph to narrow.
    fn cargo_metadata(&self, manifest_path: &Utf8Path) -> Result<Metadata> {
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
        serde_json::from_str(&json)
            .with_context(|| format!("Failed to parse the metadata of '{manifest_path}'"))
    }

    /// The `rustc --print=cfg` output of a Cargo triple, parsed.
    ///
    /// The recorded table keeps the resolution independent of the rustc at
    /// hand. A triple it does not know, such as a custom target, falls back to
    /// asking rustc.
    fn cfgs_for_triple(&self, triple: &str) -> Result<Vec<Cfg>> {
        let cfg_text = match RustcCfgs::recorded().cfg_text(triple) {
            Some(cfg_text) => cfg_text,
            None => {
                warn!(
                    "The platform `{triple}` has no recorded `rustc --print=cfg` output; asking \
                     the current rustc, which makes the resolution depend on its version"
                );
                print_cfg(self.cargo_bin.rustc_path(), triple)?.join("\n")
            }
        };
        parse_cfgs(&cfg_text)
    }
}

/// Parses `rustc --print=cfg` output into the form `cargo_platform` evaluates
/// `[target.'cfg(...)']` dependency tables against.
pub(crate) fn parse_cfgs(cfg_text: &str) -> Result<Vec<Cfg>> {
    cfg_text
        .lines()
        .map(str::trim)
        .filter(|line| !line.is_empty())
        .map(|line| {
            line.parse::<Cfg>()
                .with_context(|| format!("parsing cfg `{line}`"))
        })
        .collect()
}

/// Fails if a package depends, unconditionally, on a package which `cargo metadata`
/// left out.
///
/// `cargo metadata` drops a dependency on a package without a library target
/// (`warning: ignoring invalid dependency ... which is missing a lib target`) and
/// everything reachable only through it. `cargo build` ignores such a dependency
/// the same way, so the features it would have enabled are never applied. That is
/// easy to mistake for a resolution bug, so it is reported here.
///
/// `Cargo.lock` holds the complete package set, so anything in it missing from the
/// metadata was dropped this way. An optional dependency nothing enables, or one
/// behind a `cfg(...)` no configured platform satisfies, is never built by Cargo
/// and is not reported.
fn ensure_dependencies_resolved(
    manifest_path: &Utf8Path,
    metadata: &Metadata,
    platform_cfgs: &[(String, Vec<Cfg>)],
) -> Result<()> {
    let lockfile_path = manifest_path
        .parent()
        .expect("manifest paths always have a parent directory")
        .join("Cargo.lock");
    let lockfile = cargo_lock::Lockfile::load(&lockfile_path)
        .with_context(|| format!("Failed to load lockfile '{lockfile_path}'"))?;

    let unresolved = unresolved_dependencies(metadata, &lockfile, platform_cfgs);
    if unresolved.is_empty() {
        return Ok(());
    }

    bail!(
        "Dependencies on packages which `cargo metadata` did not resolve: [{}]. Cargo \
         omits dependencies without a library target, so such a crate has to be \
         resolved another way, such as a `crate.spec` of its own.",
        unresolved.join(", "),
    )
}

/// Every `package -> dependency` edge whose dependency is in the lockfile but not in
/// `metadata`, rendered as `name version -> name version`.
///
/// Optional dependencies are skipped (see [ensure_dependencies_resolved]), as are
/// dev-dependencies of packages outside the workspace and dependencies whose
/// `cfg(...)` matches none of `platform_cfgs`, which Cargo never builds.
fn unresolved_dependencies(
    metadata: &Metadata,
    lockfile: &cargo_lock::Lockfile,
    platform_cfgs: &[(String, Vec<Cfg>)],
) -> Vec<String> {
    let resolved: BTreeSet<String> = metadata
        .packages
        .iter()
        .map(|package| format!("{} {}", package.name, package.version))
        .collect();
    let missing: Vec<&cargo_lock::Package> = lockfile
        .packages
        .iter()
        .filter(|package| !resolved.contains(&format!("{} {}", package.name, package.version)))
        .collect();
    if missing.is_empty() {
        return Vec::new();
    }

    let mut unresolved = Vec::new();
    for package in &metadata.packages {
        let is_workspace_member = metadata.workspace_members.contains(&package.id);
        for dependency in &package.dependencies {
            if dependency.optional
                || (dependency.kind == DependencyKind::Development && !is_workspace_member)
            {
                continue;
            }
            let enabled_somewhere = dependency.target.as_ref().is_none_or(|target| {
                platform_cfgs
                    .iter()
                    .any(|(triple, cfgs)| target.matches(triple, cfgs))
            });
            if !enabled_somewhere {
                continue;
            }
            for dropped in &missing {
                if dropped.name.as_str() == dependency.name
                    && dependency.req.matches(&dropped.version)
                {
                    unresolved.push(format!(
                        "{} {} -> {} {}",
                        package.name, package.version, dropped.name, dropped.version
                    ));
                }
            }
        }
    }
    unresolved.sort();
    unresolved.dedup();
    unresolved
}

/// The resolution of a single (host, target) pair, split by which side each crate
/// is built for.
struct PairResolution {
    target_tree_data: BTreeMap<CrateId, CargoTreeEntry>,
    host_tree_data: BTreeMap<CrateId, CargoTreeEntry>,
}

/// Runs Cargo's feature resolver for one (host, target) pair.
fn resolve_pair(
    graph: &ResolveGraph,
    ws: &Workspace<'_>,
    package_set: &PackageSet<'_>,
    cfgs: &BTreeMap<String, Vec<Cfg>>,
    behavior: ResolveBehavior,
    cargo_host: &str,
    cargo_target: &str,
) -> Result<PairResolution> {
    trace!("Resolving features for host `{cargo_host}` targeting `{cargo_target}`");

    let compile_target = CompileTarget::new(cargo_target, false)?;
    let requested = [CompileKind::Target(compile_target)];
    let mut target_data = RustcTargetData::new(cargo_host, cfgs[cargo_host].clone());
    target_data.add_target(compile_target, cfgs[cargo_target].clone());

    let resolved = FeatureResolver::resolve(
        ws,
        &mut target_data,
        &graph.resolve,
        package_set,
        &CliFeatures::new_all(false),
        &[],
        &requested,
        // Dev-dependencies of workspace members are rendered for their tests.
        FeatureOpts::new_behavior(behavior, HasDevUnits::Yes),
    )
    .with_context(|| {
        format!("Failed to resolve features for host `{cargo_host}` targeting `{cargo_target}`")
    })?;

    let (target_tree_data, host_tree_data) =
        split_sides(&resolved, graph, package_set, &target_data, &requested);
    Ok(PairResolution {
        target_tree_data,
        host_tree_data,
    })
}

/// The dependency graph `cargo metadata` reports, as Cargo's `Resolve`.
struct ResolveGraph {
    resolve: Resolve,
    /// Every package, with the targets the feature resolver asks about.
    packages: Vec<Package>,
    /// The workspace members among them.
    members: Vec<Package>,
}

impl ResolveGraph {
    fn build(metadata: &Metadata) -> Result<Self> {
        let resolve_section = metadata
            .resolve
            .as_ref()
            .context("`cargo metadata` output has no `resolve` section")?;

        let mut ids: HashMap<&cargo_metadata::PackageId, PackageId> = HashMap::new();
        let mut summaries: FxHashMap<PackageId, Summary> = FxHashMap::default();
        let mut packages = Vec::new();
        for package in &metadata.packages {
            let id = package_id(package)?;
            let summary = summary(package, id)?;
            ids.insert(&package.id, id);
            summaries.insert(id, summary.clone());
            packages.push(Package::new(
                summary,
                package.manifest_path.as_std_path(),
                targets(package),
            ));
        }

        let mut graph: Graph<PackageId, FxHashSet<Dependency>> = Graph::new();
        let mut features: FxHashMap<PackageId, Vec<InternedString>> = FxHashMap::default();
        for node in &resolve_section.nodes {
            let parent = *ids
                .get(&node.id)
                .with_context(|| format!("unknown resolve node {}", node.id))?;
            graph.add(parent);
            features.insert(
                parent,
                node.features
                    .iter()
                    .map(|f| InternedString::new(f))
                    .collect(),
            );
            let parent_summary = &summaries[&parent];
            for node_dep in &node.deps {
                let child = *ids
                    .get(&node_dep.pkg)
                    .with_context(|| format!("unknown resolve dependency {}", node_dep.pkg))?;
                // Cargo's edge set is every declaration of `parent` that resolved to
                // `child`; `dep_kinds` lists exactly those, one `(kind, target)` each.
                let edge = graph.link(parent, child);
                for decl in parent_summary.dependencies() {
                    if decl.package_name() != child.name() {
                        continue;
                    }
                    let decl_target = decl.platform().map(ToString::to_string);
                    let listed = node_dep.dep_kinds.iter().any(|dk| {
                        dep_kind(dk.kind) == decl.kind()
                            && dk.target.as_ref().map(ToString::to_string) == decl_target
                    });
                    if listed {
                        edge.insert(decl.clone());
                    }
                }
                if edge.is_empty() {
                    bail!(
                        "no declaration of `{}` matches its resolved dependency `{}`",
                        parent,
                        child
                    );
                }
            }
        }

        let member_ids: HashSet<PackageId> = metadata
            .workspace_members
            .iter()
            .map(|m| {
                ids.get(m)
                    .copied()
                    .with_context(|| format!("unknown workspace member {m}"))
            })
            .collect::<Result<_>>()?;
        let members = packages
            .iter()
            .filter(|package| member_ids.contains(&package.package_id()))
            .cloned()
            .collect();

        let resolve = Resolve::new(
            graph,
            FxHashMap::default(),
            features,
            FxHashMap::default(),
            TomlLockfileMetadata::default(),
            Vec::new(),
            ResolveVersion::max_stable(),
            summaries,
        );
        Ok(Self {
            resolve,
            packages,
            members,
        })
    }
}

fn package_id(package: &cargo_metadata::Package) -> Result<PackageId> {
    let source = match &package.source {
        Some(source) => SourceId::from_url(&source.repr)?,
        None => SourceId::for_path(
            package
                .manifest_path
                .parent()
                .context("manifest path has no parent")?
                .as_std_path(),
        )?,
    };
    Ok(PackageId::new(
        InternedString::new(&package.name),
        package.version.clone(),
        source,
    ))
}

/// The targets of a package, as far as the feature resolver tells them apart:
/// a library, a proc-macro, or anything else.
fn targets(package: &cargo_metadata::Package) -> Vec<Target> {
    package
        .targets
        .iter()
        .map(|target| {
            let proc_macro = target.kind.contains(&TargetKind::ProcMacro);
            let is_lib = proc_macro
                || target.kind.iter().any(|kind| {
                    matches!(
                        kind,
                        TargetKind::Lib
                            | TargetKind::RLib
                            | TargetKind::DyLib
                            | TargetKind::CDyLib
                            | TargetKind::StaticLib
                    )
                });
            if is_lib {
                Target::lib(target.name.as_str(), proc_macro)
            } else {
                Target::other(target.name.as_str(), false)
            }
        })
        .collect()
}

fn dependency(dep: &cargo_metadata::Dependency) -> Result<Dependency> {
    let source = match (&dep.source, &dep.path) {
        (Some(source), _) => SourceId::from_url(&source.repr)?,
        (None, Some(path)) => SourceId::for_path(path.as_std_path())?,
        (None, None) => bail!("dependency `{}` has neither a source nor a path", dep.name),
    };
    let mut out = Dependency::parse(dep.name.as_str(), Some(&dep.req.to_string()), source)?;
    if let Some(rename) = &dep.rename {
        out.set_explicit_name_in_toml(rename.as_str());
    }
    if dep.registry.is_some() && !source.is_crates_io() {
        out.set_registry_id(source);
    }
    let platform = match &dep.target {
        Some(target) => Some(
            target
                .to_string()
                .parse::<Platform>()
                .with_context(|| format!("parsing target `{target}`"))?,
        ),
        None => None,
    };
    out.set_optional(dep.optional)
        .set_default_features(dep.uses_default_features)
        .set_features(dep.features.iter().map(String::as_str))
        .set_platform(platform)
        .set_kind(dep_kind(dep.kind));
    Ok(out)
}

fn dep_kind(kind: DependencyKind) -> DepKind {
    match kind {
        DependencyKind::Development => DepKind::Development,
        DependencyKind::Build => DepKind::Build,
        _ => DepKind::Normal,
    }
}

fn summary(package: &cargo_metadata::Package, id: PackageId) -> Result<Summary> {
    let deps = package
        .dependencies
        .iter()
        .map(dependency)
        .collect::<Result<Vec<_>>>()
        .with_context(|| format!("dependencies of {}", package.id))?;
    let features: BTreeMap<InternedString, Vec<InternedString>> = package
        .features
        .iter()
        .map(|(k, v)| {
            (
                InternedString::new(k),
                v.iter().map(|s| InternedString::new(s)).collect(),
            )
        })
        .collect();
    let rust_version = package
        .rust_version
        .as_ref()
        .map(|v| v.to_string().parse::<RustVersion>())
        .transpose()?;
    Summary::new(id, deps, &features, package.links.as_deref(), rust_version)
        .with_context(|| format!("summary of {}", package.id))
}

fn crate_id(id: PackageId) -> CrateId {
    CrateId::new(id.name().to_string(), id.version().clone())
}

/// Whether a package has a proc-macro target.
fn has_proc_macro(package_set: &PackageSet<'_>, id: PackageId) -> bool {
    package_set
        .get_one(id)
        .map(Package::proc_macro)
        .unwrap_or(false)
}

/// The feature resolver's own platform rule for a dependency.
fn platform_activated(
    dep: &Dependency,
    fk: FeaturesFor,
    target_data: &RustcTargetData<'_>,
    requested: &[CompileKind],
) -> bool {
    match (dep.is_build(), fk) {
        (true, _) | (_, FeaturesFor::HostDep) => {
            target_data.dep_platform_activated(dep, CompileKind::Host)
        }
        (_, FeaturesFor::NormalOrDev) => requested
            .iter()
            .any(|kind| target_data.dep_platform_activated(dep, *kind)),
        (_, FeaturesFor::ArtifactDep(target)) => {
            target_data.dep_platform_activated(dep, CompileKind::Target(target))
        }
    }
}

/// Walks the graph from the workspace members the way `cargo tree` does.
///
/// Features come from the side a crate is built for and a dependency edge
/// belongs to the side its parent is built for. Only crates reachable through
/// platform-active edges are reported, which matters under resolver v1, where
/// the feature resolver activates packages on every platform.
fn split_sides(
    resolved: &ResolvedFeatures,
    graph: &ResolveGraph,
    package_set: &PackageSet<'_>,
    target_data: &RustcTargetData<'_>,
    requested: &[CompileKind],
) -> (
    BTreeMap<CrateId, CargoTreeEntry>,
    BTreeMap<CrateId, CargoTreeEntry>,
) {
    let mut target_side = BTreeMap::<CrateId, CargoTreeEntry>::new();
    let mut host_side = BTreeMap::<CrateId, CargoTreeEntry>::new();
    let mut seen = HashSet::<(PackageId, bool)>::new();
    let mut queue: Vec<(PackageId, bool)> = graph
        .members
        .iter()
        // As `cargo tree` does: a member with a proc-macro target is a host root.
        .map(|member| {
            let id = member.package_id();
            (id, has_proc_macro(package_set, id))
        })
        .collect();
    while let Some((pkg, for_host)) = queue.pop() {
        if !seen.insert((pkg, for_host)) {
            continue;
        }
        let fk = FeaturesFor::from_for_host(for_host);
        let side = if for_host {
            &mut host_side
        } else {
            &mut target_side
        };
        let entry = side.entry(crate_id(pkg)).or_default();
        if let Some(features) = resolved.activated_features_unverified(pkg, fk) {
            entry
                .features
                .extend(features.iter().map(|f| f.to_string()));
        }
        for (dep_id, deps) in graph.resolve.deps(pkg) {
            for dep in deps {
                if dep.platform().is_some() && !platform_activated(dep, fk, target_data, requested)
                {
                    continue;
                }
                if dep.is_optional() && !resolved.is_dep_activated(pkg, fk, dep.name_in_toml()) {
                    continue;
                }
                entry.deps.insert(crate_id(dep_id));
                // As `cargo tree` does: build dependencies and packages with a
                // proc-macro target are built for the host.
                let child_for_host =
                    for_host || dep.is_build() || has_proc_macro(package_set, dep_id);
                queue.push((dep_id, child_for_host));
            }
        }
    }
    (target_side, host_side)
}

/// Reads the resolver version out of the workspace manifest.
///
/// Cargo picks it up from the manifest it is pointed at, so the resolver has to
/// be told. The v1 resolver unions features across every platform and ignores
/// target-specific dependency filtering, so a wrong version leaks target-gated
/// optional dependencies onto every platform.
fn resolve_behavior(manifest_path: &Utf8Path) -> Result<ResolveBehavior> {
    resolve_behavior_of(manifest_path.as_std_path())
}

fn resolve_behavior_of(manifest_path: &Path) -> Result<ResolveBehavior> {
    let manifest = cargo_toml::Manifest::from_path(manifest_path).with_context(|| {
        format!(
            "Failed to parse Cargo.toml file at {}",
            manifest_path.display()
        )
    })?;

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
            cargo_toml::Resolver::V1 => ResolveBehavior::V1,
            cargo_toml::Resolver::V2 => ResolveBehavior::V2,
            // `cargo_toml::Resolver` is `#[non_exhaustive]`. Anything newer is treated
            // as the newest resolver known here, since v1 resolves features far more
            // coarsely.
            _ => ResolveBehavior::V3,
        });
    }

    // With no explicit `resolver`, Cargo derives the default from the edition of the
    // package at the workspace root. A virtual manifest has no such package and stays
    // on the v1 resolver whatever editions its members declare; Cargo warns about it.
    //
    // https://doc.rust-lang.org/cargo/reference/resolver.html#resolver-versions
    let edition = manifest
        .package
        .as_ref()
        .map(|package| package.edition())
        .unwrap_or(cargo_toml::Edition::E2015);

    Ok(match edition {
        cargo_toml::Edition::E2015 | cargo_toml::Edition::E2018 => ResolveBehavior::V1,
        cargo_toml::Edition::E2021 => ResolveBehavior::V2,
        // `cargo_toml::Edition` is `#[non_exhaustive]`; editions past 2024 keep the
        // newest resolver known here.
        _ => ResolveBehavior::V3,
    })
}

#[cfg(test)]
mod test {
    use super::*;

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
        target_os="linux"
        target_pointer_width="64"
        target_vendor="unknown"
        unix
    "#};

    /// The recorded cfgs have to evaluate `cfg(...)` predicates exactly as Cargo
    /// does, since that is what decides whether a target-gated dependency is
    /// pulled in.
    #[test]
    fn recorded_cfgs_evaluate_predicates_as_cargo_does() {
        let cfgs = parse_cfgs(X86_64_LINUX_GNU_CFG).unwrap();
        for (spec, expected) in [
            (r#"cfg(target_os = "linux")"#, true),
            (r#"cfg(unix)"#, true),
            (r#"cfg(windows)"#, false),
            (r#"cfg(target_arch = "x86_64")"#, true),
            (r#"cfg(target_arch = "aarch64")"#, false),
            (r#"cfg(target_feature = "sse2")"#, true),
            (r#"cfg(target_feature = "avx512f")"#, false),
            // Unrecognized bare flags (`rustix_use_libc`, `miri`, ...) must evaluate
            // to false. Unknown would pull every dependency gated behind one onto
            // every platform.
            (r#"cfg(rustix_use_libc)"#, false),
            (r#"cfg(not(rustix_use_libc))"#, true),
        ] {
            let platform: Platform = spec.parse().unwrap();
            assert_eq!(
                expected,
                platform.matches("x86_64-unknown-linux-gnu", &cfgs),
                "unexpected evaluation of `{spec}`"
            );
        }
    }

    /// `cargo metadata` output for `test_data/metadata/no_deps`, a workspace with a
    /// single package and nothing else.
    const NO_DEPS_METADATA: &str = include_str!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test_data/metadata/no_deps/metadata.json"
    ));

    /// A lockfile for `no_deps` which also lists `shellharden`, as it would if the
    /// package declared a dependency on it: a binary-only package stays in the
    /// lockfile while `cargo metadata` leaves it out.
    const NO_DEPS_WITH_SHELLHARDEN_LOCKFILE: &str = indoc::indoc! {r#"
        version = 3

        [[package]]
        name = "no-deps"
        version = "0.1.0"
        dependencies = [
         "shellharden",
        ]

        [[package]]
        name = "shellharden"
        version = "4.3.2"
        source = "registry+https://github.com/rust-lang/crates.io-index"
        checksum = "0000000000000000000000000000000000000000000000000000000000000000"
    "#};

    /// The `no_deps` metadata with a dependency on `shellharden` declared by its
    /// package, which `cargo metadata` would have dropped from `resolve`.
    fn no_deps_metadata_depending_on_shellharden(
        optional: bool,
        target: Option<&str>,
    ) -> cargo_metadata::Metadata {
        let mut metadata: serde_json::Value = serde_json::from_str(NO_DEPS_METADATA).unwrap();
        metadata["packages"][0]["dependencies"]
            .as_array_mut()
            .unwrap()
            .push(serde_json::json!({
                "name": "shellharden",
                "source": "registry+https://github.com/rust-lang/crates.io-index",
                "req": "=4.3.2",
                "kind": null,
                "rename": null,
                "optional": optional,
                "uses_default_features": true,
                "features": [],
                "target": target,
                "registry": null,
            }));
        serde_json::from_value(metadata).unwrap()
    }

    /// The cfgs of a single linux platform, as `generate` would collect them.
    fn linux_platform_cfgs() -> Vec<(String, Vec<Cfg>)> {
        vec![(
            "x86_64-unknown-linux-gnu".to_owned(),
            parse_cfgs(X86_64_LINUX_GNU_CFG).unwrap(),
        )]
    }

    #[test]
    fn lockfile_packages_all_resolved() {
        let metadata: cargo_metadata::Metadata = serde_json::from_str(NO_DEPS_METADATA).unwrap();
        let lockfile: cargo_lock::Lockfile = indoc::indoc! {r#"
            version = 3

            [[package]]
            name = "no-deps"
            version = "0.1.0"
        "#}
        .parse()
        .unwrap();

        assert!(unresolved_dependencies(&metadata, &lockfile, &linux_platform_cfgs()).is_empty());
    }

    #[test]
    fn unconditional_dependency_on_a_dropped_package_is_reported() {
        let metadata = no_deps_metadata_depending_on_shellharden(false, None);
        let lockfile: cargo_lock::Lockfile = NO_DEPS_WITH_SHELLHARDEN_LOCKFILE.parse().unwrap();

        assert_eq!(
            vec!["no-deps 0.1.0 -> shellharden 4.3.2".to_owned()],
            unresolved_dependencies(&metadata, &lockfile, &linux_platform_cfgs()),
        );
    }

    /// An optional dependency nothing enables is never built, so a lockfile entry
    /// for it is not a discrepancy.
    #[test]
    fn optional_dependency_on_a_dropped_package_is_ignored() {
        let metadata = no_deps_metadata_depending_on_shellharden(true, None);
        let lockfile: cargo_lock::Lockfile = NO_DEPS_WITH_SHELLHARDEN_LOCKFILE.parse().unwrap();

        assert!(unresolved_dependencies(&metadata, &lockfile, &linux_platform_cfgs()).is_empty());
    }

    /// `cxx` declares `cxxbridge-cmd` under `[target."cfg(any())".build-dependencies]`
    /// purely to pin its version; no platform ever satisfies it.
    #[test]
    fn dependency_gated_on_an_unsatisfied_cfg_is_ignored() {
        let lockfile: cargo_lock::Lockfile = NO_DEPS_WITH_SHELLHARDEN_LOCKFILE.parse().unwrap();

        let never = no_deps_metadata_depending_on_shellharden(false, Some("cfg(any())"));
        assert!(unresolved_dependencies(&never, &lockfile, &linux_platform_cfgs()).is_empty());

        let windows_only = no_deps_metadata_depending_on_shellharden(false, Some("cfg(windows)"));
        assert!(
            unresolved_dependencies(&windows_only, &lockfile, &linux_platform_cfgs()).is_empty()
        );

        let unix_only = no_deps_metadata_depending_on_shellharden(false, Some("cfg(unix)"));
        assert_eq!(
            vec!["no-deps 0.1.0 -> shellharden 4.3.2".to_owned()],
            unresolved_dependencies(&unix_only, &lockfile, &linux_platform_cfgs()),
        );
    }

    /// Writes `contents` to a `Cargo.toml` in a fresh temp dir and resolves its
    /// resolver version.
    fn resolve_behavior_of_manifest(name: &str, contents: &str) -> ResolveBehavior {
        let (_guard, dir) = crate::test::test_tempdir("resolve_behavior");
        let path = dir.join(name).join("Cargo.toml");
        std::fs::create_dir_all(path.parent().unwrap()).unwrap();
        std::fs::write(&path, contents).unwrap();
        resolve_behavior_of(&path).unwrap()
    }

    #[test]
    fn resolver_version_is_read_from_the_manifest() {
        for (resolver, expected) in [
            ("1", ResolveBehavior::V1),
            ("2", ResolveBehavior::V2),
            ("3", ResolveBehavior::V3),
        ] {
            let manifest = format!(
                "[package]\nname = \"pkg\"\nversion = \"0.1.0\"\nedition = \"2015\"\nresolver = \"{resolver}\"\n"
            );
            assert_eq!(expected, resolve_behavior_of_manifest("pkg", &manifest));

            let workspace = format!("[workspace]\nmembers = []\nresolver = \"{resolver}\"\n");
            assert_eq!(expected, resolve_behavior_of_manifest("ws", &workspace));
        }
    }

    /// Cargo infers the resolver from the edition of the root package when no
    /// `resolver` is declared. A v1 default would pull target-gated optional
    /// dependencies onto every platform.
    #[test]
    fn resolver_version_defaults_to_the_edition_default() {
        for (edition, expected) in [
            ("2015", ResolveBehavior::V1),
            ("2018", ResolveBehavior::V1),
            ("2021", ResolveBehavior::V2),
            ("2024", ResolveBehavior::V3),
        ] {
            let manifest = format!(
                "[package]\nname = \"pkg\"\nversion = \"0.1.0\"\nedition = \"{edition}\"\n"
            );
            assert_eq!(
                expected,
                resolve_behavior_of_manifest("pkg", &manifest),
                "edition {edition}"
            );
        }
    }

    /// A virtual manifest has no root package to take an edition from, so Cargo
    /// leaves it on the v1 resolver.
    #[test]
    fn resolver_version_of_a_virtual_manifest_defaults_to_v1() {
        assert_eq!(
            ResolveBehavior::V1,
            resolve_behavior_of_manifest("ws", "[workspace]\nmembers = []\n")
        );
    }
}
