"""The `package_metadata` module's rules, re-exported for generated crate BUILD files."""

load("@package_metadata//licenses/rules:license.bzl", _license = "license")
load("@package_metadata//rules:package_metadata.bzl", _package_metadata = "package_metadata")

license = _license
package_metadata = _package_metadata
