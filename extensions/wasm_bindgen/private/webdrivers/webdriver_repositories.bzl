"""Depednencies for `wasm_bindgen_test` rules"""

load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

def _build_file_repository_impl(repository_ctx):
    repository_ctx.file("WORKSPACE.bazel", """workspace(name = "{}")""".format(
        repository_ctx.name,
    ))

    repository_ctx.file("BUILD.bazel", repository_ctx.read(repository_ctx.path(repository_ctx.attr.build_file)))

build_file_repository = repository_rule(
    doc = "A repository rule for generating external repositories with a specific build file.",
    implementation = _build_file_repository_impl,
    attrs = {
        "build_file": attr.label(
            doc = "The file to use as the BUILD file for this repository.",
            mandatory = True,
            allow_files = True,
        ),
    },
)

_WEBDRIVER_BUILD_CONTENT = """\
filegroup(
    name = "{name}",
    srcs = ["{tool}"],
    data = glob(
        include = [
            "**",
        ],
        exclude = [
            "*.bazel",
            "BUILD",
            "WORKSPACE",
        ],
    ),
    visibility = ["//visibility:public"],
)
"""

def _webdriver_repository_impl(repository_ctx):
    result = repository_ctx.download_and_extract(
        repository_ctx.attr.urls,
        stripPrefix = repository_ctx.attr.strip_prefix,
        integrity = repository_ctx.attr.integrity,
    )

    repository_ctx.file("WORKSPACE.bazel", """workspace(name = "{}")""".format(
        repository_ctx.attr.original_name,
    ))

    repository_ctx.file("BUILD.bazel", _WEBDRIVER_BUILD_CONTENT.format(
        name = repository_ctx.attr.original_name,
        tool = repository_ctx.attr.tool,
    ))

    return {
        "integrity": result.integrity,
        "name": repository_ctx.name,
        "original_name": repository_ctx.attr.original_name,
        "strip_prefix": repository_ctx.attr.strip_prefix,
        "tool": repository_ctx.attr.tool,
        "urls": repository_ctx.attr.urls,
    }

webdriver_repository = repository_rule(
    doc = "A repository rule for downloading webdriver tools.",
    implementation = _webdriver_repository_impl,
    attrs = {
        "integrity": attr.string(
            doc = """Expected checksum in Subresource Integrity format of the file downloaded.""",
        ),
        # TODO: This can be removed in Bazel 8 and it's use moved to `repository_ctx.original_name`.
        "original_name": attr.string(
            doc = "The original name of the repository.",
        ),
        "strip_prefix": attr.string(
            doc = """A directory prefix to strip from the extracted files.""",
        ),
        "tool": attr.string(
            doc = "The name of the webdriver tool being downloaded.",
            mandatory = True,
        ),
        "urls": attr.string_list(
            doc = "A list of URLs to a file that will be made available to Bazel.",
            mandatory = True,
        ),
    },
)

def firefox_deps():
    """Download firefix/geckodriver dependencies

    Returns:
        A list of repositories crated
    """
    # https://ftp.mozilla.org/pub/firefox/releases/129.0/

    geckodriver_version = "0.35.0"

    direct_deps = []
    for platform, integrity in {
        "linux-aarch64": "sha256-kdHkRmRtjuhYMJcORIBlK3JfGefsvvo//TlHvHviOkc=",
        "linux64": "sha256-rCbpuo87jOD79zObnJAgGS9tz8vwSivNKvgN/muyQmA=",
        "macos": "sha256-zP9gaFH9hNMKhk5LvANTVSOkA4v5qeeHowgXqHdvraE=",
        "macos-aarch64": "sha256-K4XNwwaSsz0nP18Zmj3Q9kc9JXeNlmncVwQmCzm99Xg=",
        "win64": "sha256-5t4e5JqtKUMfe4/zZvEEhtAI3VzY3elMsB1+nj0z2Yg=",
    }.items():
        archive = "tar.gz"
        tool = "geckodriver"
        if "win" in platform:
            archive = "zip"
            tool = "geckodriver.exe"

        name = "geckodriver_{}".format(platform.replace("-", "_"))
        direct_deps.append(struct(repo = name))
        maybe(
            webdriver_repository,
            name = name,
            original_name = name,
            urls = ["https://github.com/mozilla/geckodriver/releases/download/v{version}/geckodriver-v{version}-{platform}.{archive}".format(
                version = geckodriver_version,
                platform = platform,
                archive = archive,
            )],
            integrity = integrity,
            tool = tool,
        )

    direct_deps.append(struct(repo = "geckodriver"))
    maybe(
        build_file_repository,
        name = "geckodriver",
        build_file = Label("//private/webdrivers:BUILD.geckodriver.bazel"),
    )

    return direct_deps

# A snippet from https://googlechromelabs.github.io/chrome-for-testing/known-good-versions-with-downloads.json
# but modified to included `integrity`
CHROME_DATA = {
    "downloads": {
        "chrome": [
            {
                "integrity": "sha256-q4Uk4tNmfHtfnfah5350Ip6bYg516vrGWm/XaMjNgIM=",
                "platform": "linux64",
                "url": "https://storage.googleapis.com/chrome-for-testing-public/133.0.6943.98/linux64/chrome-linux64.zip",
            },
            {
                "integrity": "sha256-wvtlYx54c4AfkJSK/7g86v9N3tFP8f+69+MLSzlVUEQ=",
                "platform": "mac-arm64",
                "url": "https://storage.googleapis.com/chrome-for-testing-public/133.0.6943.98/mac-arm64/chrome-mac-arm64.zip",
            },
            {
                "integrity": "sha256-prydIMvCZ9to+1BQj/VkOJwcpfqLHgVXMfS4hW/PL7c=",
                "platform": "mac-x64",
                "url": "https://storage.googleapis.com/chrome-for-testing-public/133.0.6943.98/mac-x64/chrome-mac-x64.zip",
            },
            {
                "integrity": "sha256-37Q6RVISw+r5I8FbkjVrxr30kv5Sd9Dsb9/Ixy03tBs=",
                "platform": "win32",
                "url": "https://storage.googleapis.com/chrome-for-testing-public/133.0.6943.98/win32/chrome-win32.zip",
            },
            {
                "integrity": "sha256-KJH0AsLlNJaEAEfdC1VfBBpEJQQD77p3EutCiXaQaDc=",
                "platform": "win64",
                "url": "https://storage.googleapis.com/chrome-for-testing-public/133.0.6943.98/win64/chrome-win64.zip",
            },
        ],
        "chrome-headless-shell": [
            {
                "integrity": "sha256-OOqEwG18NW8nMOlY3ym/PQym3m+lrlk5rTO/t8EFNAU=",
                "platform": "linux64",
                "url": "https://storage.googleapis.com/chrome-for-testing-public/133.0.6943.98/linux64/chrome-headless-shell-linux64.zip",
            },
            {
                "integrity": "sha256-v4uIa7JtAnhg9jC5/eKssgETVvqSrZscDxw0Tk8YF3g=",
                "platform": "mac-arm64",
                "url": "https://storage.googleapis.com/chrome-for-testing-public/133.0.6943.98/mac-arm64/chrome-headless-shell-mac-arm64.zip",
            },
            {
                "integrity": "sha256-opLAAw8+s7M7Rx2rO6IVvSXFbVif/bi2tkhRYBFOAC8=",
                "platform": "mac-x64",
                "url": "https://storage.googleapis.com/chrome-for-testing-public/133.0.6943.98/mac-x64/chrome-headless-shell-mac-x64.zip",
            },
            {
                "integrity": "sha256-KGDYGor90qgEbWYCzeG+YqWWIxZCB66MAoAduHuZhMs=",
                "platform": "win32",
                "url": "https://storage.googleapis.com/chrome-for-testing-public/133.0.6943.98/win32/chrome-headless-shell-win32.zip",
            },
            {
                "integrity": "sha256-+MUS84cWY7ZLGPyPeYBauu3VT+vf1BkuOQ+tVbkj6wg=",
                "platform": "win64",
                "url": "https://storage.googleapis.com/chrome-for-testing-public/133.0.6943.98/win64/chrome-headless-shell-win64.zip",
            },
        ],
        "chromedriver": [
            {
                "integrity": "sha256-cQPneSI/DU+el6WDcI5YmtdmIkdeE0b9s7IjaU1YJF0=",
                "platform": "linux64",
                "url": "https://storage.googleapis.com/chrome-for-testing-public/133.0.6943.98/linux64/chromedriver-linux64.zip",
            },
            {
                "integrity": "sha256-yZMZYAb33J/pQBqsdho0pB+HsxFxNPoyD+HCfTS+7YQ=",
                "platform": "mac-arm64",
                "url": "https://storage.googleapis.com/chrome-for-testing-public/133.0.6943.98/mac-arm64/chromedriver-mac-arm64.zip",
            },
            {
                "integrity": "sha256-8CamWPjcWk4ZmgkyCD96VtSesa4K/FZe8Uvo22jZ3HU=",
                "platform": "mac-x64",
                "url": "https://storage.googleapis.com/chrome-for-testing-public/133.0.6943.98/mac-x64/chromedriver-mac-x64.zip",
            },
            {
                "integrity": "sha256-d16YIHEFP/F25Am+nnGSmW6/+uZnG8uWbyyRSQNruIQ=",
                "platform": "win32",
                "url": "https://storage.googleapis.com/chrome-for-testing-public/133.0.6943.98/win32/chromedriver-win32.zip",
            },
            {
                "integrity": "sha256-TAqzYdZNqv0Qkx0KaTPhY+nZ3v+37uLvpUO5C0+wd88=",
                "platform": "win64",
                "url": "https://storage.googleapis.com/chrome-for-testing-public/133.0.6943.98/win64/chromedriver-win64.zip",
            },
        ],
    },
    "revision": "1402768",
    "version": "133.0.6943.98",
}

def chrome_deps():
    """Download chromedriver dependencies

    Returns:
        A list of repositories crated
    """

    direct_deps = []
    for data in CHROME_DATA["downloads"]["chromedriver"]:
        platform = data["platform"]
        name = "chromedriver_{}".format(platform.replace("-", "_"))
        direct_deps.append(struct(repo = name))
        tool = "chromedriver"
        if platform.startswith("win"):
            tool = "chromedriver.exe"
        maybe(
            webdriver_repository,
            name = name,
            original_name = name,
            urls = [data["url"]],
            strip_prefix = "chromedriver-{}".format(platform),
            integrity = data.get("integrity", ""),
            tool = tool,
        )

    for data in CHROME_DATA["downloads"]["chrome-headless-shell"]:
        platform = data["platform"]
        name = "chrome_headless_shell_{}".format(platform.replace("-", "_"))
        direct_deps.append(struct(repo = name))
        tool = "chrome-headless-shell"
        if platform.startswith("win"):
            tool = "chrome-headless-shell.exe"
        maybe(
            webdriver_repository,
            name = name,
            original_name = name,
            urls = [data["url"]],
            strip_prefix = "chrome-headless-shell-{}".format(platform),
            integrity = data.get("integrity", ""),
            tool = tool,
        )

    for data in CHROME_DATA["downloads"]["chrome"]:
        platform = data["platform"]
        name = "chrome_{}".format(platform.replace("-", "_"))
        direct_deps.append(struct(repo = name))

        if platform.startswith("win"):
            tool = "chrome.exe"
        elif platform.startswith("mac"):
            tool = "Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing"
        else:
            tool = "chrome"
        maybe(
            webdriver_repository,
            name = name,
            original_name = name,
            urls = [data["url"]],
            strip_prefix = "chrome-{}".format(platform),
            integrity = data.get("integrity", ""),
            tool = tool,
        )

    direct_deps.append(struct(repo = "chromedriver"))
    maybe(
        build_file_repository,
        name = "chromedriver",
        build_file = Label("//private/webdrivers:BUILD.chromedriver.bazel"),
    )

    direct_deps.append(struct(repo = "chrome_headless_shell"))
    maybe(
        build_file_repository,
        name = "chrome_headless_shell",
        build_file = Label("//private/webdrivers:BUILD.chrome_headless_shell.bazel"),
    )

    direct_deps.append(struct(repo = "chrome"))
    maybe(
        build_file_repository,
        name = "chrome",
        build_file = Label("//private/webdrivers:BUILD.chrome.bazel"),
    )

    return direct_deps

def webdriver_repositories():
    direct_deps = []
    direct_deps.extend(chrome_deps())
    direct_deps.extend(firefox_deps())

    return direct_deps
