"""mdBook rules"""

MdBookInfo = provider(
    doc = "Information about a `mdbook` target.",
    fields = {
        "config": "File: The `book.toml` file.",
        "plugins": "Depset[File]: TODO",
        "srcs": "Depset[File]: TODO",
    },
)

def _flatten_path(file):
    """Flattens a file's path for staging.

    We want to flatten the directory structure so that files from
    different packages sit together. We do this by stripping the
    file's repository and package prefixes.

    Example:
    file:    test/flattening/content/src/SUMMARY.md
    package: test/flattening/content
    result:  src/SUMMARY.md
    """
    path = file.short_path
    if path.startswith("../"):
        # External repositories: strip '../repo_name/'
        parts = path.split("/")
        path = "/".join(parts[2:])

    package = file.owner.package
    if package and path.startswith(package + "/"):
        path = path[len(package) + 1:]

    return path

def _map_inputs(file):
    dest = _flatten_path(file)
    return "{}={}".format(file.path, dest)

def _mdbook_impl(ctx):
    output = ctx.actions.declare_directory(ctx.label.name)

    toolchain = ctx.toolchains["@rules_rust_mdbook//:toolchain_type"]

    plugin_paths = depset([
        "${{pwd}}/{}".format(file.dirname)
        for file in depset(ctx.files.plugins, transitive = [toolchain.plugins]).to_list()
    ])
    is_windows = toolchain.mdbook.basename.endswith(".exe")
    path_sep = ";" if is_windows else ":"
    plugin_path = path_sep.join(plugin_paths.to_list())

    inputs = depset([ctx.file.book] + ctx.files.srcs)

    inputs_map_args = ctx.actions.args()
    inputs_map_args.use_param_file("%s", use_always = True)
    inputs_map_args.add_all(inputs, map_each = _map_inputs)

    args = ctx.actions.args()

    # This arg is used for `--dest-dir` within the action.
    args.add(output.path)
    args.add(toolchain.mdbook)
    args.add("build")

    book_dest = _flatten_path(ctx.file.book)
    book_dirname = ""
    if "/" in book_dest:
        parts = book_dest.split("/")
        book_dirname = "/" + "/".join(parts[:-1])
    args.add("${{pwd}}{}".format(book_dirname))

    ctx.actions.run(
        mnemonic = "MdBookBuild",
        executable = ctx.executable._process_wrapper,
        tools = depset(ctx.files.plugins, transitive = [toolchain.all_files]),
        outputs = [output],
        arguments = [inputs_map_args, args],
        env = {"MDBOOK_PLUGIN_PATH": plugin_path},
        inputs = inputs,
        toolchain = "@rules_rust_mdbook//:toolchain_type",
    )

    return [
        DefaultInfo(
            files = depset([output]),
        ),
        MdBookInfo(
            srcs = depset(ctx.files.srcs),
            config = ctx.file.book,
            plugins = depset(ctx.files.plugins),
        ),
    ]

mdbook = rule(
    implementation = _mdbook_impl,
    doc = """Rules to create book from markdown files using `mdbook`.

This rule flattens all input files into a single directory structure
before running `mdbook`. This is necessary because `mdbook` expects
all source files, themes, and configuration to sit in a standard
relative layout on disk.

By flattening inputs, this rule allows you to pull the `book.toml`
from one Bazel package (or external repository) and the sources from
another, and have them sit as siblings during execution. This means
your `book.toml` can use standard relative paths (like `src = "src"`)
regardless of Bazel's internal directory structure.
""",
    attrs = {
        "book": attr.label(
            doc = "The `book.toml` file.",
            allow_single_file = ["book.toml"],
            mandatory = True,
        ),
        "plugins": attr.label_list(
            doc = (
                "Executables to inject into `PATH` for use in " +
                "[preprocessor commands](https://rust-lang.github.io/mdBook/format/configuration/preprocessors.html#provide-your-own-command)."
            ),
            allow_files = True,
            cfg = "exec",
        ),
        "srcs": attr.label_list(
            doc = """All inputs to the book.

These files will be flattened into a single directory structure alongside the
`book.toml` file. Package and external repository prefixes are stripped.
""",
            allow_files = True,
        ),
        "_process_wrapper": attr.label(
            cfg = "exec",
            executable = True,
            default = Label("//private:process_wrapper"),
        ),
    },
    toolchains = ["@rules_rust_mdbook//:toolchain_type"],
)

def _rlocationpath(file, workspace_name):
    if file.short_path.startswith("../"):
        return file.short_path[len("../"):]

    return "{}/{}".format(workspace_name, file.short_path)

def _mdbook_server_impl(ctx):
    toolchain = ctx.toolchains["@rules_rust_mdbook//:toolchain_type"]
    book_info = ctx.attr.book[MdBookInfo]

    args = ctx.actions.args()

    args.add("--mdbook={}".format(_rlocationpath(toolchain.mdbook, ctx.workspace_name)))
    args.add("--config={}".format(_rlocationpath(book_info.config, ctx.workspace_name)))
    args.add("--hostname={}".format(ctx.attr.hostname))
    args.add("--port={}".format(ctx.attr.port))

    workspace_name = ctx.workspace_name

    # Detect if we need to flatten files. We need flattening if any
    # input comes from a different repository than the book.toml.
    is_split = False
    config_repo = book_info.config.owner.workspace_name
    for f in book_info.srcs.to_list():
        if f.owner.workspace_name != config_repo:
            is_split = True
            break

    if is_split:
        def _src_map(file):
            return "--src={}={}".format(_rlocationpath(file, workspace_name), _flatten_path(file))

        args.add_all(book_info.srcs, map_each = _src_map, allow_closure = True)

    def _runfile_map(file):
        return "--plugin={}".format(_rlocationpath(file, workspace_name))

    args.add_all(depset(transitive = [book_info.plugins, toolchain.plugins]), map_each = _runfile_map, allow_closure = True)

    args_file = ctx.actions.declare_file("{}.mdbook_serve_args.txt".format(ctx.label.name))
    ctx.actions.write(
        output = args_file,
        content = args,
    )

    is_windows = toolchain.mdbook.basename.endswith(".exe")
    executable = ctx.actions.declare_file("{}{}".format(
        ctx.label.name,
        ".exe" if is_windows else "",
    ))

    ctx.actions.symlink(
        output = executable,
        target_file = ctx.executable._server,
        is_executable = True,
    )

    return [
        DefaultInfo(
            executable = executable,
            files = depset([executable]),
            runfiles = ctx.runfiles(
                files = [
                    book_info.config,
                    args_file,
                    ctx.executable._server,
                ],
                transitive_files = depset(transitive = [
                    book_info.srcs,
                    book_info.plugins,
                    toolchain.all_files,
                ]),
            ),
        ),
        RunEnvironmentInfo(
            environment = {
                "RULES_MDBOOK_SERVE_ARGS_FILE": _rlocationpath(args_file, ctx.workspace_name),
            },
        ),
    ]

mdbook_server = rule(
    implementation = _mdbook_server_impl,
    doc = "Spawn an mdbook server for a given `mdbook` target.",
    attrs = {
        "book": attr.label(
            doc = "The `mdbook` target to serve.",
            providers = [MdBookInfo],
            mandatory = True,
        ),
        "hostname": attr.string(
            doc = "The default hostname to use (Can be overridden on the command line).",
            default = "localhost",
        ),
        "port": attr.string(
            doc = "The default port to use (Can be overridden on the command line).",
            default = "3000",
        ),
        "_server": attr.label(
            doc = "TODO",
            cfg = "target",
            executable = True,
            default = Label("//private:server"),
        ),
    },
    toolchains = ["@rules_rust_mdbook//:toolchain_type"],
    executable = True,
)
