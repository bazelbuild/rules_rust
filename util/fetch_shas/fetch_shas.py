#!/usr/bin/env python3.11
"""A script for generating the `//rust:known_shas.bzl` and `//rust:nightly_versions.bzl` files."""

import argparse
import json
import logging
import os
import re
import shutil
import subprocess
import tempfile
import tomllib
from pathlib import Path
from typing import Any, Dict, List, Sequence, Tuple

KNOWN_SHAS_TEMPLATE = """\
\"\"\"A module containing a mapping of Rust tools to checksums

This is a generated file -- see //util/fetch_shas

The table covers the last five minor releases of Rust plus the minimum version
`rules_rust` supports, and the nightlies published since the oldest of those
five recent releases, for every target those releases publish a standard
library for (`//util/fetch_shas:fetch_shas_TARGETS.txt`). Other versions, and
targets published since, are resolved from their channel manifests by the
`rust` module extension and recorded as facts in the consumer's
`MODULE.bazel.lock`; see `//rust/private:channel_manifest.bzl`.
\"\"\"

FILE_KEY_TO_SHA = {}
"""

NIGHTLY_VERSIONS_TEMPLATE = """\
\"\"\"A module containing a mapping of nightly iso dates to Rust versions.

This is a generated file -- see //util/fetch_shas
\"\"\"

# Each entry marks the first tracked nightly date where the Rust
# version changed. To resolve a given iso_date, find the latest
# entry whose date is <= the target date.
NIGHTLY_VERSION_TRANSITIONS = {{
{}
}}
"""


def download_manifest_data(
    stable_versions: Sequence[str], nightly_versions: Sequence[str], output_dir: Path
) -> Dict[str, Sequence[Dict[str, Any]]]:
    """Download and deserialize `channel-rust-*.toml` files for the requested versions

    Args:
        stable_versions: A list of Rust versions. E.g. `1.81.0`
        nightly_versions: A list of nightly iso dates. E.g. `2024-09-05`
        output_dir: The location where the intermediate files should be written.

    Returns:
        A mapping of channel name (`stable`, `nightly`) to deserialized data.
    """

    output_dir.mkdir(exist_ok=True, parents=True)
    curl_config = output_dir / "curl_config.txt"
    curl_config_lines = [
        "--fail",
        "--parallel",
        "--silent",
        "--create-dirs",
    ]

    stable_files = {}
    for version in stable_versions:
        output = output_dir / f"channel-rust-{version}.toml"
        curl_config_lines.extend(
            [
                f"--output {output}",
                f"--url https://static.rust-lang.org/dist/channel-rust-{version}.toml",
            ]
        )
        stable_files[version] = output
    nightly_files = {}
    for version in nightly_versions:
        output = output_dir / version / "channel-rust-nightly.toml"
        curl_config_lines.extend(
            [
                f"--output {output}",
                f"--url https://static.rust-lang.org/dist/{version}/channel-rust-nightly.toml",
            ]
        )
        nightly_files[version] = output

    curl_config.write_text("\n".join(curl_config_lines), encoding="utf-8")

    logging.info("Downloading data...")
    subprocess.run(
        [
            "curl",
            "--config",
            curl_config,
        ],
        check=True,
    )
    logging.info("Done.")

    logging.info(
        "Deserializing %s tomls...",
        len(list(stable_files.keys()) + list(nightly_files.keys())),
    )
    for collection in (stable_files, nightly_files):
        for version, file in collection.items():
            data = file.read_text(encoding="utf-8")
            assert data
            try:
                collection[version] = tomllib.loads(data)
            except:
                logging.error("Failed to parse toml: %s\n%s", file, data)
                raise

    logging.info("Done.")
    return {
        "stable": stable_files,
        "nightly": nightly_files,
    }


def extract_nightly_version_transitions(
    manifest_data: Dict[str, Dict[str, Any]],
) -> List[Tuple[str, str]]:
    """Extract a transition table mapping nightly iso dates to Rust versions.

    Only includes entries where the version changed from the previous entry,
    keeping the table compact.

    Args:
        manifest_data: The parsed manifest data from download_manifest_data.

    Returns:
        A sorted list of (iso_date, version) tuples at transition points.
    """
    nightly_info = manifest_data.get("nightly", {})
    date_to_version = {}

    for iso_date, info in nightly_info.items():
        rustc_pkg = info.get("pkg", {}).get("rustc", {})
        rustc_version_str = rustc_pkg.get("version", "")
        if not rustc_version_str:
            logging.warning("No rustc version found for nightly %s", iso_date)
            continue

        match = re.match(r"^(\d+\.\d+\.\d+)", rustc_version_str)
        if not match:
            logging.warning(
                "Could not parse version from %r for nightly %s",
                rustc_version_str,
                iso_date,
            )
            continue

        date_to_version[iso_date] = match.group(1)

    sorted_dates = sorted(date_to_version.keys())
    transitions = []
    prev_version = None
    for date in sorted_dates:
        version = date_to_version[date]
        if version != prev_version:
            transitions.append((date, version))
            prev_version = version

    return transitions


def load_data(file: Path) -> Sequence[str]:
    """Load a `fetch_shas_*.txt` file

    Args:
        file: The file to load

    Returns:
        A list of the file's contents.
    """
    data = []
    for line in file.read_text(encoding="utf-8").splitlines():
        text = line.strip()
        if not text:
            continue
        data.append(text)

    return sorted(set(data))


def workspace_directory() -> Path:
    """The root of the `rules_rust` checkout, under `bazel run` or plain Python."""
    if "BUILD_WORKSPACE_DIRECTORY" in os.environ:
        return Path(os.environ["BUILD_WORKSPACE_DIRECTORY"])
    return Path(__file__).resolve().parent.parent.parent


def parse_args() -> argparse.Namespace:
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--targets",
        type=Path,
        default=workspace_directory() / "util/fetch_shas/fetch_shas_TARGETS.txt",
        help="A file listing the platform triples to record, one per line.",
    )
    parser.add_argument(
        "--update-targets",
        action="store_true",
        help=(
            "Add every target the manifests publish a standard library for to "
            "`--targets`, keeping the targets already listed, and record all of them."
        ),
    )
    return parser.parse_args()


def published_targets(manifest_data: Dict[str, Dict[str, Any]]) -> List[str]:
    """Every target any of the manifests publishes a `rust-std` for."""
    targets = set()
    for versioned_info in manifest_data.values():
        for info in versioned_info.values():
            std = info["pkg"].get("rust-std", {}).get("target", {})
            targets.update(
                target
                for target, target_data in std.items()
                if target != "*" and target_data.get("available")
            )
    return sorted(targets)


def main() -> None:
    """The  main entrypoint."""
    args = parse_args()
    workspace_dir = workspace_directory()

    logging.basicConfig(
        level=(
            logging.INFO
            if "RULES_RUST_FETCH_SHAS_DEBUG" not in os.environ
            else logging.DEBUG
        ),
        format="%(asctime)s - %(levelname)s - %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )
    logging.info("Fetching known sha256 data...")

    tools = load_data(workspace_dir / "util/fetch_shas/fetch_shas_TOOLS.txt")
    host_tools = load_data(workspace_dir / "util/fetch_shas/fetch_shas_HOST_TOOLS.txt")
    targets = load_data(args.targets)
    logging.info("Recording %s platforms.", len(targets))
    stable_versions = load_data(
        workspace_dir / "util/fetch_shas/fetch_shas_VERSIONS.txt"
    )
    nightly_iso_dates = load_data(
        workspace_dir / "util/fetch_shas/fetch_shas_NIGHTLY_ISO_DATES.txt"
    )

    # Allow this directory to be optionally cleaned up.
    tmp_dir = Path(tempfile.mkdtemp(prefix="rules-rust-fetch-shas-"))
    logging.debug("Temp dir: %s", tmp_dir)
    try:
        manifest_data = download_manifest_data(
            stable_versions=stable_versions,
            nightly_versions=nightly_iso_dates,
            output_dir=tmp_dir,
        )

        published = published_targets(manifest_data)
        if args.update_targets:
            targets = sorted(set(targets) | set(published))
            args.targets.write_text("".join(f"{target}\n" for target in targets))
            logging.info("Wrote %s targets to %s", len(targets), args.targets)
        else:
            missing = sorted(set(published) - set(targets))
            if missing:
                logging.warning(
                    "%s published targets are not in %s; pass --update-targets to add them: %s",
                    len(missing),
                    args.targets,
                    " ".join(missing),
                )

        file_key_to_sha = {}

        # Nightlies are recorded from the oldest of the five most recent
        # minor releases on. The minimum supported version is older than
        # that window and does not extend it; hashes for older nightlies
        # come from facts, like any other version outside the table. The
        # transition table below still covers every nightly listed, so
        # older dates keep resolving to a version.
        release_dates: Dict[Tuple[int, int], str] = {}
        for version, info in manifest_data["stable"].items():
            major, minor = (int(part) for part in version.split(".")[:2])
            date = info["date"]
            if (major, minor) not in release_dates or date < release_dates[
                (major, minor)
            ]:
                release_dates[(major, minor)] = date
        recent_minors = sorted(release_dates)[-5:]
        sha_cutoff = min(release_dates[minor] for minor in recent_minors)
        logging.info("Recording nightly hashes from %s on.", sha_cutoff)

        logging.info("Parsing artifacts...")
        for channel, versioned_info in manifest_data.items():
            for version, info in versioned_info.items():
                if channel == "nightly" and version < sha_cutoff:
                    continue
                if channel == "stable":
                    tool_tpl = f"{{pkg}}-{version}-{{target}}.{{ext}}"
                    host_tool_tpl = f"{{pkg}}-{version}.{{ext}}"
                else:
                    tool_tpl = f"{version}/{{pkg}}-{channel}-{{target}}.{{ext}}"
                    host_tool_tpl = f"{version}/{{pkg}}-{channel}.{{ext}}"

                # Artifacts are commonly referred to with an internal (to the Rust org) name.
                # In order to correctly evaluate whether or not a particular `channel-rust-*.toml`
                # has an artifact, a mapping is made from what the internal Rust names are to
                # what they're advertised as externally (e.g. what users would use when trying
                # to download files directly).
                renames = {
                    "clippy-preview": "clippy",
                    "llvm-tools-preview": "llvm-tools",
                    "rustfmt-preview": "rustfmt",
                }
                if "renames" in info:
                    for pkg, rename in info["renames"].items():
                        if "to" in rename:
                            renames[rename["to"]] = pkg

                logging.debug("Renames (%s %s): %s", channel, version, renames)
                for pkg, pkg_data in info["pkg"].items():
                    pkg_name = renames.get(pkg, pkg)
                    if pkg_name in tools:
                        tool_template = tool_tpl
                    elif pkg_name in host_tools:
                        tool_template = host_tool_tpl
                    else:
                        logging.debug("Skipping %s %s %s", channel, version, pkg_name)
                        continue

                    # Only the platforms in `--targets` are recorded, and only
                    # the `.tar.gz` archives `rules_rust` downloads by default;
                    # other platforms and mirrors serving `.tar.xz` resolve
                    # hashes through facts. Target-independent archives such
                    # as `rust-src` are listed under the target `*`.
                    for target, target_data in pkg_data["target"].items():
                        if target != "*" and target not in targets:
                            continue

                        # One variant of the template has an extra format string field.
                        # Replace is used to account for that.
                        template = tool_template.replace("{target}", target)

                        if "hash" in target_data:
                            file_key_to_sha[
                                template.format(pkg=pkg_name, ext="tar.gz")
                            ] = target_data["hash"]

        logging.info("Done. Identified %s artifacts.", len(file_key_to_sha))

        nightly_transitions = extract_nightly_version_transitions(manifest_data)
        logging.info(
            "Identified %s nightly version transitions.", len(nightly_transitions)
        )

    finally:
        if not "RULES_RUST_FETCH_SHAS_DEBUG" in os.environ:
            shutil.rmtree(tmp_dir)

    known_shas_file = workspace_dir / "rust/private/known_shas.bzl"
    known_shas_file.write_text(
        KNOWN_SHAS_TEMPLATE.format(
            json.dumps(file_key_to_sha, sort_keys=True, indent=4).replace(
                '"\n}', '",\n}'
            )
        )
    )
    logging.info("Done. Wrote %s", known_shas_file.relative_to(workspace_dir))

    nightly_versions_file = workspace_dir / "rust/private/nightly_versions.bzl"
    transitions_str = "\n".join(
        '    "{}": "{}",'.format(date, ver) for date, ver in nightly_transitions
    )
    nightly_versions_file.write_text(NIGHTLY_VERSIONS_TEMPLATE.format(transitions_str))
    logging.info("Done. Wrote %s", nightly_versions_file.relative_to(workspace_dir))


if __name__ == "__main__":
    main()
