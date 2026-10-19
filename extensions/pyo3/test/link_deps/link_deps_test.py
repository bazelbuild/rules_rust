"""Regression test: `pyo3_extension` accepts `link_deps`."""

import unittest
from test.link_deps import link_deps


class LinkDepsTest(unittest.TestCase):
    """Test Class."""

    def test_answer(self) -> None:
        """The C symbol provided via `link_deps` is linked in."""

        self.assertEqual(42, link_deps.answer())


if __name__ == "__main__":
    unittest.main()
