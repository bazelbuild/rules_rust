def _build_script_impl(ctx):
    toolchain = ctx.toolchains["@io_bazel_rules_rust//rust:toolchain"]
    out_dir = ctx.actions.declare_directory(ctx.label.name + "_out_dir_outputs")
    env = {
        "CARGO_MANIFEST_DIR": ctx.build_file_path.rsplit("/", 1)[0],
        "RUSTC": toolchain.rustc.path,
        "TARGET": toolchain.triplet,
        "RUST_BACKTRACE": "1",
        "OUT_DIR": out_dir.path,
        "BINARY_PATH": ctx.executable.script.path,
    } + {
        "CARGO_FEATURE_" + f.upper().replace("-", "_"): "1"
        for f in ctx.attr.crate_features
    }
    ctx.actions.run_shell(
        command = "%s >/dev/null" % ctx.executable.script.path,
        outputs = [out_dir],
        inputs = ctx.files.srcs + [ctx.executable.script],
        mnemonic = "CargoBuildScript",
        env = env,
    )
    ctx.actions.run_shell(
        command = "tar czf '%s' -C '%s' ." % (ctx.outputs.out.path, out_dir.path),
        inputs = [out_dir],
        outputs = [ctx.outputs.out],
    )

cargo_build_script_run = rule(
    _build_script_impl,
    attrs = {
        "script": attr.label(executable = True, cfg = "host"),
        "crate_features": attr.string_list(),
        "srcs": attr.label_list(allow_files = True),
    },
    outputs = {"out": "%{name}.tar.gz"},
    toolchains = ["@io_bazel_rules_rust//rust:toolchain"],
)

def _impl(rctx):
    kwargs = {
        "name": rctx.attr.crate_name,
        "version": rctx.attr.crate_version,
    }
    rctx.download_and_extract(
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/{name}/{name}-{version}.crate".format(**kwargs),
        sha256 = rctx.attr.sha256,
        type = "tar.gz",
        stripPrefix = "{name}-{version}".format(**kwargs),
    )
    args = [
        str(rctx.path(rctx.attr._tool)),
        "--output=BUILD.bazel",
    ] + [
        "%s=%s" % (k, v)
        for k, v in rctx.attr.locked_deps.items()
    ] + [
        "--flag=" + f
        for f in rctx.attr.flags
    ]
    if rctx.attr.data:
        args.append("--data=" + rctx.attr.data)
    result = rctx.execute(args)
    if result.stderr:
        print(result.stderr)

crate_repository = repository_rule(
    _impl,
    attrs = {
        "crate_name": attr.string(mandatory = True),
        "crate_version": attr.string(mandatory = True),
        "locked_deps": attr.string_dict(),
        "flags": attr.string_list(),
        "data": attr.string(),
        "sha256": attr.string(),
        "_tool": attr.label(default = "//rust:cargo_manifest_to_build.py"),
    },
)

def _split(s):
    result = []
    for l in s.split("."):
        result.extend(l.split("/"))
    return result

def _dns_to_workspace(repository):
    return "_".join(reversed(_split(repository)))

def cargo_crate(name, version, **kwargs):
    crate_repository(
        name = "io_crates_%s__%s" % (
            name.replace("-", "_"),
            version.replace(".", "_"),
        ),
        crate_version = version,
        crate_name = name,
        **kwargs
    )
