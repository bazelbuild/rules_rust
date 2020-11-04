import argparse

from util.dir_zipper import dir_zipper_lib


def main():
    parser = argparse.ArgumentParser(
        description="Create a zip archive from some files, stripping "
        "a common directory prefix from the name of each archive entry."
    )
    parser.add_argument(
        "--zipper",
        help="path to @bazel_tools//tools/zip:zipper",
        required=True,
    )
    parser.add_argument(
        "--output", help="write a zip file to this path", required=True,
    )
    parser.add_argument(
        "--root-dir",
        help="strip this directory from each entry",
        required=True,
    )
    parser.add_argument(
        "files",
        help="add these files to the archive",
        nargs="*",
        metavar="FILE",
    )
    args = parser.parse_args()
    dir_zipper_lib.create_zip(
        args.zipper, args.output, args.root_dir, args.files
    )


if __name__ == "__main__":
    main()
