import json
import os
import codecs
import unittest

# Largely borrowed from rules_license:
# https://github.com/bazelbuild/rules_license/blob/main/examples/vndor/constant_gen/verify_licenses_test.py

APACHE_2_LICENSE_TARGET = "@rules_license~//licenses/spdx:Apache-2.0"
MIT_LICENSE_TARGET = "@rules_license~//licenses/spdx:MIT"


def load_licenses_info(info_path):
    """Loads the licenses_info() JSON format."""
    with codecs.open(info_path, encoding="utf-8") as licenses_file:
        return json.loads(licenses_file.read())


class LicenseCheckTest(unittest.TestCase):
    def test_license_info(self):
        self.check_license("license_info.json", "//:all_crate_deps")

    def test_license_info_from_spec(self):
        self.check_license("license_info_from_spec.json", "//:all_crate_deps_from_spec")

    # Load the generated report and ensure that the data is as expected.
    # Note: anyhow@v1.0.79 is licensed under both Apache-2.0 and MIT, so we expect both to be present
    # If this dependency is ever changed, you may need to update this test to reflect that
    def check_license(self, file_name, top_level_target):
        info = load_licenses_info(os.path.join(os.path.dirname(__file__), file_name))
        self.assertEqual(len(info), 1)
        all_crate_deps = info[0]
        self.assertEqual(all_crate_deps["top_level_target"], top_level_target)
        self.assertEqual(len(all_crate_deps["dependencies"]), 3)

        licenses = all_crate_deps["licenses"]

        self.assertEqual(len(licenses), 1)

        apache_found = False
        mit_found = False
        other_found = False
        other_license_found = ""
        for license_item in licenses:
            for kind in license_item["license_kinds"]:
                if kind["target"] == APACHE_2_LICENSE_TARGET:
                    apache_found = True
                    continue
                if kind["target"] == MIT_LICENSE_TARGET:
                    mit_found = True
                    continue
                else:
                    other_found = True
                    other_license_found = kind["target"]
                    continue
        self.assertFalse(
            other_found, "Unexpected license found: (%s)." % other_license_found
        )
        self.assertTrue(apache_found, "Apache-2.0 license not found.")
        self.assertTrue(mit_found, "MIT license not found.")


if __name__ == "__main__":
    unittest.main(verbosity=3)
