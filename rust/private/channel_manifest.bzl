"""Resolve the sha256 of Rust distribution archives from channel manifests.

`//rust/private:known_shas.bzl` only records the last few Rust releases. When
a module asks for a version or a platform outside that table, the `rust`
module extension downloads the release's channel manifest
(`channel-rust-<version>.toml`), reads the hashes of every archive the
requested platforms could need, and records them as facts in the consumer's
`MODULE.bazel.lock`. Later evaluations read the facts instead of downloading,
and the repository rules receive the hashes through their `sha256s` attribute
so every download is checked and reproducible.

On Bazel versions without facts nothing is downloaded here; the repository
rules read the manifest themselves for any archive they have no hash for
(`manifest_sha256` in `repository_utils.bzl`), so downloads stay verified
there too, at the cost of a manifest download per repository and of the
repository being reported as not reproducible.
"""

load("//rust/private:known_shas.bzl", "FILE_KEY_TO_SHA")

# The key of the facts dict the `rust` extensions record.
CHANNEL_MANIFEST_FACTS_KEY = "channel_manifests"

def split_version(version):
    """Split a version as written in `versions` into a version and an iso date.

    Args:
        version (str): `1.94.0`, `nightly/2026-08-20` or `beta/2026-08-20`.

    Returns:
        tuple[str, str]: The version (`1.94.0`, `nightly`, `beta`) and the iso date or `None`.
    """
    if version.startswith(("nightly", "beta")):
        channel, _, iso_date = version.partition("/")
        return channel, iso_date or None
    return version, None

def archive_extension(urls):
    """The archive extension the URL templates download, `.tar.xz` unless they say `.tar.gz`.

    Args:
        urls (list[str]): URL templates as passed to the repository rules; empty means the default.

    Returns:
        str: `.tar.xz` or `.tar.gz`.
    """
    if urls:
        for ext in (".tar.xz", ".tar.gz"):
            if urls[0].endswith(ext):
                return ext
    return ".tar.xz"

def _builtin_covers(version, iso_date, target, ext):
    """Whether `known_shas.bzl` already describes `version` for `target`.

    Every target in a release has a `rust-std` archive, so its hash stands in
    for the release as a whole. The key is built the way `produce_tool_suburl`
    builds it, without parsing the triple, so targets `rules_rust` cannot
    describe are looked up all the same.
    """
    key = "rust-std-{}-{}{}".format(version, target, ext)
    if iso_date:
        key = "{}/{}".format(iso_date, key)
    return key in FILE_KEY_TO_SHA

def manifest_urls(urls, version, iso_date):
    """The URLs of a release's channel manifest, one per mirror in `urls`.

    Args:
        urls (list[str]): URL templates as passed to the repository rules; the manifest lives
            where the archives do, so each template's prefix up to `{}` is kept.
        version (str): `1.99.0`, `nightly` or `beta`.
        iso_date (str): The iso date of a nightly or beta release, else `None`.

    Returns:
        list[str]: `.../channel-rust-1.99.0.toml` or `.../2026-08-20/channel-rust-nightly.toml`.
    """
    if iso_date:
        path = "{}/channel-rust-{}.toml".format(iso_date, version)
    else:
        path = "channel-rust-{}.toml".format(version)
    return [template.split("{}")[0] + path for template in urls if "{}" in template]

def parse_manifest(content, targets, iso_date, ext):
    """Read the archive hashes for `targets` out of a channel manifest.

    Archives are keyed the way `lookup_tool_sha256` looks them up: the archive
    file name, prefixed with the iso date for nightly and beta releases. Taking
    the name from the manifest's own `url` fields means renamed packages
    (`clippy-preview` is published as `clippy-...`) need no special casing.

    Args:
        content (str): The manifest.
        targets (list[str]): The target triples to keep. Target-independent
            archives such as `rust-src` are always kept.
        iso_date (str): The iso date of a nightly or beta release, else `None`.
        ext (str): The archive extension to keep, `.tar.xz` or `.tar.gz`.

    Returns:
        dict[str, str]: Archive key to sha256.
    """
    wanted = {target: True for target in targets}
    result = {}
    in_wanted = False
    pending_url = None
    for line in content.split("\n"):
        if line.startswith("["):
            in_wanted = False
            pending_url = None
            marker = ".target."
            if line.startswith("[pkg.") and marker in line:
                target = line[line.index(marker) + len(marker):].rstrip("]").strip("\"")
                in_wanted = target == "*" or target in wanted
            continue
        if not in_wanted:
            continue
        if line.startswith(("url = ", "xz_url = ")):
            pending_url = line.split("= ", 1)[1].strip().strip("\"")
        elif line.startswith(("hash = ", "xz_hash = ")) and pending_url:
            if pending_url.endswith(ext):
                basename = pending_url.rsplit("/", 1)[-1]
                key = "{}/{}".format(iso_date, basename) if iso_date else basename
                result[key] = line.split("= ", 1)[1].strip().strip("\"")
            pending_url = None
    return result

def sha256_request(*, version, targets):
    """A request for the archives of one version, as passed to `resolve_sha256s`.

    Args:
        version (str): A version as written in `versions`: `1.99.0`, `nightly/2026-08-20`.
            An empty version is ignored by `resolve_sha256s`.
        targets (list[str]): The target triples wanted at that version.

    Returns:
        struct: With `version` and `targets`.
    """
    return struct(version = version, targets = list(targets))

def resolve_sha256s(module_ctx, *, requests, urls, sha256s, facts):
    """Collect the sha256s the repositories for `requests` will download.

    Args:
        module_ctx (module_ctx): The extension's context.
        requests (list[struct]): `sha256_request`s: a version as written in
            `versions` and the target triples wanted at that version,
            exec platforms included.
        urls (list[str]): The archive url templates, used to find the manifests.
        sha256s (dict[str, str]): Hashes the module supplied; these win.
        facts (dict): The `channel_manifests` facts, read from
            `module_ctx.facts` by the caller and updated in place with anything
            learned here. Pass `None` on Bazel versions without facts, in which
            case nothing is downloaded.

    Returns:
        dict[str, str]: `sha256s` extended with the hashes found.
    """
    if facts == None:
        return dict(sha256s)

    ext = archive_extension(urls)

    by_version = {}
    for request in requests:
        if not request.version:
            continue
        by_version.setdefault(request.version, {})
        for target in request.targets:
            by_version[request.version][target] = True

    resolved = {}
    for version_key, targets in by_version.items():
        version, iso_date = split_version(version_key)
        recorded = facts.get(version_key, {})
        recorded_targets = {target: True for target in recorded.get("targets", [])}
        recorded_sha256s = dict(recorded.get("sha256s", {}))

        missing = [
            target
            for target in targets
            if target not in recorded_targets and not _builtin_covers(version, iso_date, target, ext)
        ]
        if missing:
            output = "channel_manifests/{}.toml".format(version_key.replace("/", "-"))
            download = module_ctx.download(
                url = manifest_urls(urls, version, iso_date),
                output = output,
                allow_fail = True,
            )
            if download.success:
                content = module_ctx.read(output)
                recorded_sha256s.update(parse_manifest(content, missing, iso_date, ext))
                recorded_targets.update({target: True for target in missing})
            else:
                # buildifier: disable=print
                print("rules_rust: no channel manifest found for Rust {}; its archives are hashed as they are downloaded".format(version_key))

        if recorded_targets:
            facts[version_key] = {
                "sha256s": recorded_sha256s,
                "targets": sorted(recorded_targets.keys()),
            }
            resolved.update(recorded_sha256s)

    resolved.update(sha256s)
    return resolved
