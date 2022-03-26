"""Common utilities useful for unifying the behavior of different parts of `cargo-bazel`."""

# buildifier: disable=bzl-visibility
load(
    "//cargo/private:cargo_utils.bzl",
    _get_host_triple = "get_host_triple",
    _rust_get_rust_tools = "get_rust_tools",
)

get_host_triple = _get_host_triple

_EXECUTE_ERROR_MESSAGE = """\
Command {args} failed with exit code {exit_code}.
STDOUT ------------------------------------------------------------------------
{stdout}
STDERR ------------------------------------------------------------------------
{stderr}
"""

def execute(repository_ctx, args, env = {}):
    """A heler macro for executing some arguments and displaying nicely formatted errors

    Args:
        repository_ctx (repository_ctx): The rule's context object.
        args (list): A list of strings which act as `argv` for execution.
        env (dict, optional): Environment variables to set in the execution environment.

    Returns:
        struct: The results of `repository_ctx.execute`
    """
    result = repository_ctx.execute(
        args,
        environment = env,
        quiet = repository_ctx.attr.quiet,
    )

    if result.return_code:
        fail(_EXECUTE_ERROR_MESSAGE.format(
            args = args,
            exit_code = result.return_code,
            stdout = result.stdout,
            stderr = result.stderr,
        ))

    return result

def get_rust_tools(repository_ctx, host_triple):
    """Retrieve a cargo and rustc binary based on the host triple.

    Args:
        repository_ctx (repository_ctx): The rule's context object.
        host_triple (struct): A `@rules_rust//rust:triple.bzl%triple` object.

    Returns:
        struct: A struct containing the expected rust tools
    """

    return _rust_get_rust_tools(
        cargo_template = repository_ctx.attr.rust_toolchain_cargo_template,
        rustc_template = repository_ctx.attr.rust_toolchain_rustc_template,
        host_triple = host_triple,
        version = repository_ctx.attr.rust_version,
        repository_ctx = repository_ctx,
    )

