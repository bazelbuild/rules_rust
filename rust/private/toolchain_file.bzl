"""Read a rustup toolchain file into the terms of the `rust` module extension.

A `rust-toolchain.toml` (or the legacy one-line `rust-toolchain`) is how a
Rust project pins its toolchain for rustup:

```toml
[toolchain]
channel = "1.99.0"
components = ["rustc-dev", "llvm-tools"]
targets = ["wasm32-unknown-unknown"]
```

The `rust.toolchain` tag accepts such a file through `file`. Its
`channel` stands in for the version of the same channel in `versions` and
its `targets` are added to `extra_target_triples`. `components` and
`profile` tell rustup what to install; `rules_rust` fetches what its rules
need (`rustc`, `cargo`, `clippy`, `rustfmt`, `rust-src`, `rust-analyzer`)
as it is needed, so both are read and ignored. `rustc-dev` and `llvm-tools`
are the exception and keep their own switch, `dev_components`. `path` is
not supported.

That is the whole of the file: it has no say in optimisation levels, rustc
flags or editions, which Cargo reads from `Cargo.toml` and
`.cargo/config.toml` and rustup never sees.

Channels which name no exact release (`stable`, `beta`, `nightly`, `1.99`)
are resolved the way rustup resolves them, from the channel manifest, once:
the release found is recorded as a `channels` fact in the consumer's
`MODULE.bazel.lock` and reused by later evaluations, as rustup keeps the
release it installed until `rustup update`. Removing the entry from the
lockfile moves to the current release of the channel.
"""

load(":channel_manifest.bzl", "manifest_urls", "split_version")

# The key of the facts dict the resolved channels are recorded under.
TOOLCHAIN_CHANNEL_FACTS_KEY = "channels"

_TOOLCHAIN_FILE_KEYS = ["channel", "components", "targets", "profile", "path"]

def _strip_comment(line):
    """Drop a `#` comment, outside of strings, and surrounding whitespace."""
    in_string = False
    for i in range(len(line)):
        c = line[i]
        if c == "\"":
            in_string = not in_string
        elif c == "#" and not in_string:
            return line[:i].strip()
    return line.strip()

def _toml_string(value, key, name):
    value = value.strip()
    if len(value) < 2 or value[0] != "\"" or value[-1] != "\"":
        fail("{}: `{}` must be a quoted string, got `{}`".format(name, key, value))
    return value[1:-1]

def _toml_string_array(value, key, name):
    value = value.strip()
    if len(value) < 2 or value[0] != "[" or value[-1] != "]":
        fail("{}: `{}` must be an array of strings, got `{}`".format(name, key, value))
    return [
        _toml_string(item, key, name)
        for item in value[1:-1].split(",")
        if item.strip()
    ]

def parse_toolchain_file(content, name = "rust-toolchain.toml"):
    """Parse a rustup toolchain file.

    The TOML understood is what rustup documents for the file: one
    `[toolchain]` table of strings and arrays of strings, arrays possibly
    spanning lines. A file without a `[toolchain]` table is the legacy
    format, a channel on a line of its own.

    Starlark has no TOML parser yet, hence the hand-written one; a `toml`
    module analogous to `json` is proposed in
    https://github.com/bazelbuild/bazel/pull/27659 and would replace it.

    Args:
        content (str): The file's content.
        name (str): How to name the file in errors.

    Returns:
        struct: With `channel` (str) and `targets` (list[str]).
    """
    lines = [_strip_comment(line) for line in content.split("\n")]
    lines = [line for line in lines if line]
    if not lines:
        fail("{}: the toolchain file is empty".format(name))

    if not lines[0].startswith("["):
        if len(lines) > 1:
            fail("{}: a legacy toolchain file holds a single channel name, got {} lines".format(name, len(lines)))
        return struct(channel = lines[0], targets = [])

    values = {}
    in_toolchain = False
    pending_key = None
    pending_value = ""
    for line in lines:
        if pending_key:
            pending_value += line
            if not line.endswith("]"):
                continue
            values[pending_key] = _toml_string_array(pending_value, pending_key, name)
            pending_key = None
            continue
        if line.startswith("["):
            if line != "[toolchain]":
                fail("{}: unexpected table `{}`; only `[toolchain]` is supported".format(name, line))
            in_toolchain = True
            continue
        if not in_toolchain:
            fail("{}: `{}` appears before the `[toolchain]` table".format(name, line))
        key, sep, value = line.partition("=")
        key = key.strip()
        if not sep or not key:
            fail("{}: cannot parse `{}`".format(name, line))
        if key not in _TOOLCHAIN_FILE_KEYS:
            fail("{}: unknown key `{}`; rustup toolchain files take {}".format(name, key, ", ".join(["`{}`".format(k) for k in _TOOLCHAIN_FILE_KEYS])))
        if key in values:
            fail("{}: `{}` is set twice".format(name, key))
        value = value.strip()
        if key in ("components", "targets"):
            if value.startswith("[") and not value.endswith("]"):
                pending_key = key
                pending_value = value
                continue
            values[key] = _toml_string_array(value, key, name)
        else:
            values[key] = _toml_string(value, key, name)
    if pending_key:
        fail("{}: `{}` is not closed".format(name, pending_key))

    if "path" in values:
        fail("{}: `path` names a local toolchain, which `rules_rust` cannot register; use `channel`".format(name))
    if "channel" not in values:
        fail("{}: the `[toolchain]` table has no `channel`".format(name))

    return struct(
        channel = values["channel"],
        targets = values.get("targets", []),
    )

def _is_version(text, parts):
    """Whether `text` is `parts` dot-separated numbers."""
    pieces = text.split(".")
    if len(pieces) not in parts:
        return False
    for piece in pieces:
        if not piece or not piece.isdigit():
            return False
    return True

def _is_iso_date(pieces):
    """Whether three hyphen-separated pieces spell `YYYY-MM-DD`."""
    if len(pieces) != 3:
        return False
    for piece, width in zip(pieces, (4, 2, 2)):
        if len(piece) != width or not piece.isdigit():
            return False
    return True

def parse_channel(channel, name = "rust-toolchain.toml"):
    """Read a rustup channel name.

    rustup channels are `<channel>[-<date>][-<host>]` where `<channel>` is
    `stable`, `beta`, `nightly`, `1.99` or `1.99.0`. A host suffix selects a
    host toolchain for rustup and has no meaning here. Custom toolchain
    names are rejected the same way.

    Args:
        channel (str): The channel as written in the toolchain file.
        name (str): How to name the file in errors.

    Returns:
        struct: With `channel` (`stable`, `beta`, `nightly`, `1.99` or
            `1.99.0`), `iso_date` (str or `None`) and `version`, the version
            as `versions` writes it when the channel names an exact release
            (`1.99.0`, `nightly/2026-08-20`), else `None`.
    """
    pieces = channel.strip().split("-")
    head = pieces[0]
    date_pieces = pieces[1:]
    if head not in ("stable", "beta", "nightly") and not _is_version(head, (2, 3)):
        fail("{}: cannot read channel `{}`; expected `stable`, `beta`, `nightly`, `1.99`, `1.99.0` or one of those followed by `-YYYY-MM-DD`".format(name, channel))
    if date_pieces and not _is_iso_date(date_pieces):
        fail("{}: cannot read channel `{}`; a prerelease, host suffix or custom toolchain name has no meaning for `rules_rust`".format(name, channel))
    iso_date = "-".join(date_pieces) if date_pieces else None

    version = None
    if head in ("beta", "nightly") and iso_date:
        version = "{}/{}".format(head, iso_date)
    elif _is_version(head, (3,)) and not iso_date:
        version = head
    return struct(channel = head, iso_date = iso_date, version = version)

def parse_manifest_release(content, channel, name):
    """The release a channel manifest describes, as `versions` writes it.

    Args:
        content (str): The channel manifest.
        channel (str): `stable`, `beta`, `nightly` or `1.99`.
        name (str): What to name the manifest in errors.

    Returns:
        str: `1.99.0` for a release, `nightly/2026-08-20` or `beta/2026-08-20` otherwise.
    """
    date = None
    version = None
    section = None
    for line in content.split("\n"):
        line = line.strip()
        if line.startswith("["):
            section = line
            continue
        if section == None and line.startswith("date = "):
            date = line.split("= ", 1)[1].strip().strip("\"")
        elif section == "[pkg.rust]" and line.startswith("version = "):
            # `1.99.0 (abcdef012 2026-10-21)`, `1.99.0-beta.3 (...)`, `1.100.0-nightly (...)`.
            version = line.split("= ", 1)[1].strip().strip("\"").split(" ")[0]
    if channel in ("beta", "nightly"):
        if not date:
            fail("{}: the channel manifest has no `date`".format(name))
        return "{}/{}".format(channel, date)
    if not version or not _is_version(version, (3,)):
        fail("{}: the channel manifest names no release in `[pkg.rust]`, got `{}`".format(name, version))
    return version

def resolve_channel(module_ctx, channel, *, urls, facts, name = "rust-toolchain.toml"):
    """The release a channel names, as `versions` writes it.

    Channels naming an exact release are translated. The others are read out
    of the channel manifest, unless `facts` already records them: the first
    resolution sticks, so a `MODULE.bazel.lock` pins what `stable` meant
    when it was written.

    Args:
        module_ctx (module_ctx): The extension's context.
        channel (str): The channel as written in the toolchain file.
        urls (list[str]): The archive url templates, used to find the manifests.
        facts (dict[str, str]): The `channels` facts of a previous evaluation,
            channel to resolved version; `None` without facts support.
        name (str): How to name the file in errors.

    Returns:
        struct: With `version`, the release as `versions` writes it, and
            `manifest`, the channel manifest's content when one was downloaded
            (it describes `version` and spares `resolve_sha256s` a download),
            else `None`.
    """
    parsed = parse_channel(channel, name)
    if parsed.version:
        return struct(version = parsed.version, manifest = None)

    if facts != None and channel in facts:
        return struct(version = facts[channel], manifest = None)

    output = "channel_manifests/{}.toml".format(channel)
    download = module_ctx.download(
        url = manifest_urls(urls, parsed.channel, parsed.iso_date),
        output = output,
        allow_fail = True,
    )
    if not download.success:
        fail("{}: cannot resolve channel `{}`: no channel manifest at {}; name an exact release such as `1.99.0` or `nightly-2026-08-20`".format(
            name,
            channel,
            " or ".join(manifest_urls(urls, parsed.channel, parsed.iso_date)),
        ))
    content = module_ctx.read(output)
    version = parse_manifest_release(content, parsed.channel, "{}: channel `{}`".format(name, channel))
    return struct(version = version, manifest = content)

def _release_channel(version):
    """Which of `stable`, `beta` or `nightly` a version in `versions` belongs to."""
    channel, _ = split_version(version)
    return channel if channel in ("beta", "nightly") else "stable"

def with_channel_version(versions, version):
    """`versions` with `version` in place of the entry of its channel.

    `versions` takes one version per channel; the toolchain file's release
    stands in for the one of the same channel and leaves the others alone,
    so the default nightly stays registered beside a pinned stable.

    Args:
        versions (list[str]): As written in `versions`.
        version (str): The toolchain file's release, as `versions` writes it.

    Returns:
        list[str]: `versions` with `version` in it.
    """
    channel = _release_channel(version)
    result = [existing for existing in versions if _release_channel(existing) != channel]
    return result + [version]

def toolchain_file_settings(module_ctx, toolchain_file, *, versions, extra_target_triples, urls, facts, channels):
    """The `rust.toolchain` settings a toolchain file asks for, merged with the tag's.

    Args:
        module_ctx (module_ctx): The extension's context.
        toolchain_file (Label): The toolchain file.
        versions (list[str]): The tag's `versions`.
        extra_target_triples (list[str]): The tag's `extra_target_triples`.
        urls (list[str]): The tag's `urls`.
        facts (dict[str, str]): The `channels` facts of a previous evaluation,
            or `None` without facts support.
        channels (dict[str, str]): Updated in place with the channel resolved
            here, to be recorded as the `channels` facts; `None` without facts
            support.

    Returns:
        struct: With `versions`, `extra_target_triples` and `manifests`, the
            channel manifests downloaded along the way by version, for
            `resolve_sha256s`.
    """
    name = str(toolchain_file)
    spec = parse_toolchain_file(module_ctx.read(toolchain_file), name)

    resolved = resolve_channel(module_ctx, spec.channel, urls = urls, facts = facts, name = name)
    if channels != None and resolved.version != parse_channel(spec.channel, name).version:
        channels[spec.channel] = resolved.version

    return struct(
        versions = with_channel_version(versions, resolved.version),
        extra_target_triples = list(extra_target_triples) + [
            target
            for target in spec.targets
            if target not in extra_target_triples
        ],
        manifests = {resolved.version: resolved.manifest} if resolved.manifest else {},
    )
