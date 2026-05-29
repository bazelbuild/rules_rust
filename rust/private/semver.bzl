"""Semver"""

def semver(version):
    """Constructs a struct containing separated sections of a semantic version value.

    Parses per [Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html):
    `MAJOR.MINOR.PATCH[-PRE-RELEASE][+BUILD-METADATA]`.

    Args:
        version (str): The semver value.

    Returns:
        struct:
            - major (int): The semver's major component. E.g. `1` from `1.2.3`.
            - minor (int): The semver's minor component. E.g. `2` from `1.2.3`.
            - patch (int): The semver's patch component. E.g. `3` from `1.2.3`.
            - pre (optional str): The semver's pre-release identifier. E.g. `rc4`
              from `1.2.3-rc4`, `beta.1` from `1.0.0-beta.1+exp.sha`. `None` when
              no `-` is present.
            - build (optional str): The semver's build metadata identifier. E.g.
              `exp.sha.5114f85` from `1.0.0-beta+exp.sha.5114f85`. `None` when no
              `+` is present.
            - str (str): The full string value of the semver.
    """

    # Build metadata is everything after the first `+`. Per the spec, `+` cannot
    # appear inside MAJOR.MINOR.PATCH or the pre-release identifier, so this is
    # always a clean split.
    core, plus, build = version.partition("+")
    if not plus:
        build = None

    # Pre-release is everything after the first `-` in the core. Multiple dashes
    # are allowed in the pre-release identifier itself (e.g. `1.2.3-alpha-test`),
    # so we only split on the first one.
    main, dash, pre = core.partition("-")
    if not dash:
        pre = None

    parts = main.split(".")
    if len(parts) != 3:
        fail("Unexpected number of parts for semver value: {}".format(version))

    return struct(
        major = int(parts[0]),
        minor = int(parts[1]),
        patch = int(parts[2]),
        pre = pre,
        build = build,
        str = version,
    )
