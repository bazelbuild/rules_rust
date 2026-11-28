"""A `host_tools` repository that fails when it is fetched."""

def _no_host_tools_impl(_repository_ctx):
    fail(
        "`crate_universe` fetched the `host_tools` of a non-root module. " +
        "Its hub renders from a lockfile and needs neither cargo nor rustc.",
    )

no_host_tools = repository_rule(
    doc = "Fails when fetched, to show that `host_tools` is not needed.",
    implementation = _no_host_tools_impl,
)
