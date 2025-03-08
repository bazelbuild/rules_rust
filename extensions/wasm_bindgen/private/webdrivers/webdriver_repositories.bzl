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

_FIREFOX_WRAPPER_TEMPLATE_UNIX = """\
#!/usr/bin/env bash

set -euo pipefail

exec {firefox} $@
"""

_FIREFOX_WRAPPER_TEMPLATE_WINDOWS = """\
@ECHO OFF

{firefox} %*

:: Capture the exit code of firefox.exe
SET exit_code=!errorlevel!

:: Exit with the same exit code
EXIT /b %exit_code%
"""

_FIREFOX_NOT_FOUND_TEMPLATE_UNIX = """\
#!/usr/bin/env bash

set -euo pipefail

>&2 echo "No firefox binary provided. Please export 'FIREFOX_BINARY' and try building again"
exit 1
"""

_FIREFOX_NOT_FOUND_TEMPLATE_WINDOWS = """\
@ECHO OFF

echo No firefox binary provided. Please export 'FIREFOX_BINARY' and try building again.
exit 1
"""

_FIREFOX_BUILD_CONTENT_UNIX = """\
exports_files(["firefox"])
"""

_FIREFOX_BUILD_CONTENT_WINDOWS = """\
exports_files(["firefox.bat"])

alias(
    name = "firefox",
    actual = "firefox.bat",
    visibility = ["//visibility:public"],
)
"""

def _local_firefox_repository_impl(repository_ctx):
    repository_ctx.file("WORKSPACE.bazel", """workspace(name = "{}")""".format(
        repository_ctx.name,
    ))

    is_windows = False
    if "FIREFOX_BINARY" not in repository_ctx.os.environ:
        script_contents = _FIREFOX_NOT_FOUND_TEMPLATE_UNIX
        if "win" in repository_ctx.os.name:
            is_windows = True
            script_contents = _FIREFOX_NOT_FOUND_TEMPLATE_WINDOWS
    else:
        firefox_bin = repository_ctx.os.environ["FIREFOX_BINARY"]
        template = _FIREFOX_WRAPPER_TEMPLATE_UNIX
        if firefox_bin.endswith((".exe", ".bat")):
            is_windows = True
            template = _FIREFOX_WRAPPER_TEMPLATE_WINDOWS
        script_contents = template.format(
            firefox = firefox_bin,
        )

    repository_ctx.file(
        "firefox{}".format(".bat" if is_windows else ""),
        script_contents,
        executable = True,
    )

    repository_ctx.file("BUILD.bazel", _FIREFOX_BUILD_CONTENT_WINDOWS if is_windows else _FIREFOX_BUILD_CONTENT_UNIX)

local_firefox_repository = repository_rule(
    doc = """\
A repository rule for wrapping the path to a host installed firefox binary

Note that firefox binaries can be found here: https://ftp.mozilla.org/pub/firefox/releases/

However, for platforms like MacOS and Windows, the storage formats are not something that can be extracted
in a repository rule.
""",
    implementation = _local_firefox_repository_impl,
    environ = ["FIREFOX_BINARY"],
)

def firefox_deps():
    """Download firefix/geckodriver dependencies

    Returns:
        A list of repositories crated
    """

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

    direct_deps.append(struct(repo = "firefox"))
    maybe(
        local_firefox_repository,
        name = "firefox",
    )

    return direct_deps

# A snippet from https://googlechromelabs.github.io/chrome-for-testing/known-good-versions-with-downloads.json
# but modified to included `integrity`
CHROME_DATA = {
    "downloads": {
        "chrome": [
            {
                "integrity": "sha256-fm2efJlMZRGqLP7dgfMqhz6CKY/qVJrO6lfDZLLhA/k=",
                "platform": "linux64",
                "url": "https://storage.googleapis.com/chrome-for-testing-public/136.0.7055.0/linux64/chrome-linux64.zip",
            },
            {
                "integrity": "sha256-uROIJ56CjR6ZyjiwPCAB7n21aSoA3Wi6TluPnAch8YM=",
                "platform": "mac-arm64",
                "url": "https://storage.googleapis.com/chrome-for-testing-public/136.0.7055.0/mac-arm64/chrome-mac-arm64.zip",
            },
            {
                "integrity": "sha256-e9rzOOF8n43J5IpwvBQjnKyGc26QnBcTygpALtGDCK0=",
                "platform": "mac-x64",
                "url": "https://storage.googleapis.com/chrome-for-testing-public/136.0.7055.0/mac-x64/chrome-mac-x64.zip",
            },
            {
                "integrity": "sha256-tp67N9Iy0WPqRBqCPG66ow/TTEcBuSuS/XsJwms253Q=",
                "platform": "win32",
                "url": "https://storage.googleapis.com/chrome-for-testing-public/136.0.7055.0/win32/chrome-win32.zip",
            },
            {
                "integrity": "sha256-GhiJkB9FcXIxdIqWf2gsJh0jYLWzx2V2r3wWLRcwSSk=",
                "platform": "win64",
                "url": "https://storage.googleapis.com/chrome-for-testing-public/136.0.7055.0/win64/chrome-win64.zip",
            },
        ],
        "chrome-headless-shell": [
            {
                "integrity": "sha256-ZfahmT+jnxYV7e6e62Fj5W32FPJryOgAmhVDjNDp0Hk=",
                "platform": "linux64",
                "url": "https://storage.googleapis.com/chrome-for-testing-public/136.0.7055.0/linux64/chrome-headless-shell-linux64.zip",
            },
            {
                "integrity": "sha256-Rfdu/e4raKeTCvh5FgK4H6rrAG14KRWK4fAzoOrqUBQ=",
                "platform": "mac-arm64",
                "url": "https://storage.googleapis.com/chrome-for-testing-public/136.0.7055.0/mac-arm64/chrome-headless-shell-mac-arm64.zip",
            },
            {
                "integrity": "sha256-TWHvAfeYDKifKQD95rSantkCtpR3vLKraP41VnlGFmA=",
                "platform": "mac-x64",
                "url": "https://storage.googleapis.com/chrome-for-testing-public/136.0.7055.0/mac-x64/chrome-headless-shell-mac-x64.zip",
            },
            {
                "integrity": "sha256-KuWJUK12L+K4sQwRRecq0qrqz4CLDqPkN3c31vpMLXI=",
                "platform": "win32",
                "url": "https://storage.googleapis.com/chrome-for-testing-public/136.0.7055.0/win32/chrome-headless-shell-win32.zip",
            },
            {
                "integrity": "sha256-9ZoAYNyG2yu/QQLNqVjbBMjrj5WtaSm62Ydp8u4BXqk=",
                "platform": "win64",
                "url": "https://storage.googleapis.com/chrome-for-testing-public/136.0.7055.0/win64/chrome-headless-shell-win64.zip",
            },
        ],
        "chromedriver": [
            {
                "integrity": "sha256-FB1JYbgukDV7/PngapsD7b09XcqO5h01VFtTGPq6has=",
                "platform": "linux64",
                "url": "https://storage.googleapis.com/chrome-for-testing-public/136.0.7055.0/linux64/chromedriver-linux64.zip",
            },
            {
                "integrity": "sha256-ZATjVJV7PsswgvgdT7zQeeC6pgflX6qcrQmHxwY+/xE=",
                "platform": "mac-arm64",
                "url": "https://storage.googleapis.com/chrome-for-testing-public/136.0.7055.0/mac-arm64/chromedriver-mac-arm64.zip",
            },
            {
                "integrity": "sha256-8IsY85x99wA1VtRY5K1vB9hB0tJtzPgfNJaLYEUk7mw=",
                "platform": "mac-x64",
                "url": "https://storage.googleapis.com/chrome-for-testing-public/136.0.7055.0/mac-x64/chromedriver-mac-x64.zip",
            },
            {
                "integrity": "sha256-HYamG2SqvfrCLbxaQIc8CI5x1KnZ/XkJ0Y3RKwmFaDo=",
                "platform": "win32",
                "url": "https://storage.googleapis.com/chrome-for-testing-public/136.0.7055.0/win32/chromedriver-win32.zip",
            },
            {
                "integrity": "sha256-IxvDZCKGBTZkYDT/M7XQOfI/DaQxA9yYPJ0PB5XniVQ=",
                "platform": "win64",
                "url": "https://storage.googleapis.com/chrome-for-testing-public/136.0.7055.0/win64/chromedriver-win64.zip",
            },
        ],
    },
    "revision": "1429446",
    "version": "136.0.7055.0",
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
