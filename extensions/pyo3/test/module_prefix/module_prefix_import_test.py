"""Tests that a pyo3 extension can be imported via a module prefix."""

import unittest

import foo.bar


class ModulePrefixImportTest(unittest.TestCase):
    def test_import_and_call(self) -> None:
        result = foo.bar.thing()
        self.assertEqual("hello from rust", result)


if __name__ == "__main__":
    unittest.main()
