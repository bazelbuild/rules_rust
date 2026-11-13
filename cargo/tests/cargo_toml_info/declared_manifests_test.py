"""Lint extraction uses only the declared package and workspace manifests."""

import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from python.runfiles import runfiles

WORKSPACE = """\
[workspace]
members = ["missing-member"]

[workspace.package]
version = "0.1.0"
readme = "missing-readme.md"

[workspace.lints.rust]
unused = { level = "deny", priority = -1 }
unsafe_code = "forbid"

[workspace.lints.clippy]
all = "warn"
"""

PACKAGE = """\
[package]
name = "example"
version.workspace = true
readme.workspace = true
edition = "2021"

[lints]
workspace = true
"""


class DeclaredManifestsTest(unittest.TestCase):
    def test_root_and_member_inherit_lints_without_workspace_sources(self):
        lookup = runfiles.Create()
        self.assertIsNotNone(lookup)
        executable = lookup.Rlocation(EXTRACTOR)
        self.assertIsNotNone(executable)

        with tempfile.TemporaryDirectory(
            dir=os.environ.get("TEST_TMPDIR")
        ) as directory:
            root = Path(directory)
            workspace = root / "Cargo.toml"
            workspace.write_text(WORKSPACE + "\n" + PACKAGE)
            member = root / "member" / "Cargo.toml"
            member.parent.mkdir()
            member.write_text(PACKAGE)

            for package in (workspace, member):
                with self.subTest(package=package):
                    outputs = [
                        root / f"{package.parent.name}.{group}.lints"
                        for group in ("rustc", "clippy", "rustdoc")
                    ]
                    result = subprocess.run(
                        [
                            executable,
                            f"--manifest_toml={package.relative_to(root)}",
                            f"--workspace_toml={workspace.relative_to(root)}",
                            "lints",
                            *(str(path) for path in outputs),
                        ],
                        cwd=root,
                        capture_output=True,
                        text=True,
                        check=False,
                    )
                    self.assertEqual(0, result.returncode, result.stderr)
                    self.assertEqual(
                        ["--deny=unused", "--forbid=unsafe_code"],
                        outputs[0].read_text().splitlines(),
                    )
                    self.assertEqual(
                        ["--warn=clippy::all"], outputs[1].read_text().splitlines()
                    )
                    self.assertEqual("", outputs[2].read_text())


if __name__ == "__main__":
    EXTRACTOR = sys.argv.pop(1)
    unittest.main()
