import os
import shutil
import tempfile
import unittest
import zipfile

from util.dir_zipper import dir_zipper_lib

_ZIPPER = os.path.join(
    "external", "bazel_tools", "tools", "zip", "zipper", "zipper",
)


class DirZipperTest(unittest.TestCase):
    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.tmpdir)

    def test(self):
        root_dir = os.path.join(self.tmpdir, "prefix")
        os.mkdir(root_dir)
        files = [
            os.path.join(root_dir, *path)
            for path in [
                (".lock",),
                ("main.js",),
                ("mylib", "index.html"),
                ("src", "mylib", "lib.rs.html"),
            ]
        ]
        for filepath in files:
            os.makedirs(os.path.dirname(filepath), exist_ok=True)
            with open(filepath, "w") as outfile:
                outfile.write("%s!\n" % os.path.basename(filepath))

        output = os.path.join(self.tmpdir, "out.zip")
        dir_zipper_lib.create_zip(
            zipper=_ZIPPER, output=output, root_dir=root_dir, files=files
        )

        self.assertTrue(os.path.exists(output))
        with open(output, "rb") as fp:
            with zipfile.ZipFile(fp) as zp:
                self.assertEqual(
                    len(zp.namelist()),
                    4,
                    "expected 4 entries; got: %r" % (zp.namelist(),),
                )
                self.assertEqual(zp.read(".lock"), b".lock!\n")
                self.assertEqual(zp.read("main.js"), b"main.js!\n")
                self.assertEqual(
                    zp.read(os.path.join("mylib", "index.html")),
                    b"index.html!\n",
                )
                self.assertEqual(
                    zp.read(os.path.join("src", "mylib", "lib.rs.html")),
                    b"lib.rs.html!\n",
                )


if __name__ == "__main__":
    unittest.main()
