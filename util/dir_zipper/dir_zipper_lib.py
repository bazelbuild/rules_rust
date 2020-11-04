import os
import subprocess


def create_zip(zipper, output, root_dir, files):
    """Create a zip archive, stripping a dir prefix from each archive name.

    Args:
      zipper: Path to @bazel_tools//tools/zip:zipper.
      output: Path to zip file to create: e.g., "/tmp/out.zip".
      root_dir: Directory to strip from each archive name, with no
        trailing slash: e.g., "/tmp/myfiles".
      files: List of files to include in the archive, all under
        `root_dir`: e.g., ["/tmp/myfiles/a", "/tmp/myfiles/b/c"].
    """
    strip_prefix = root_dir + os.path.sep
    args = []
    args.append("c")
    args.append(output)
    for f in files:
        if not f.startswith(root_dir):
            raise ValueError("non-descendant: %r not under %r" % (f, root_dir))
        rel = f[len(strip_prefix) :]
        spec = "%s=%s" % (rel, f)
        args.append(spec)
    subprocess.run([zipper, *args]).check_returncode()
