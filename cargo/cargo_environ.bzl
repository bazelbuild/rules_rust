"""Helper functions for generating the environment for cargo executions."""

load("//cargo/private:cargo_utils.bzl", "cargo_home_path")

CARGO_BAZEL_ISOLATED = "CARGO_BAZEL_ISOLATED"

def cargo_environ(repository_ctx):
    """Define Cargo environment varables for use with `cargo-bazel`

    Args:
        repository_ctx (repository_ctx): The rules context object

    Returns:
        dict: A set of environment variables for `cargo-bazel` executions
    """
    env = dict()

    if CARGO_BAZEL_ISOLATED in repository_ctx.os.environ:
        if repository_ctx.os.environ[CARGO_BAZEL_ISOLATED].lower() in ["true", "1", "yes", "on"]:
            env.update({
                "CARGO_HOME": str(cargo_home_path(repository_ctx)),
            })
    elif repository_ctx.attr.isolated:
        env.update({
            "CARGO_HOME": str(cargo_home_path(repository_ctx)),
        })

    return env
