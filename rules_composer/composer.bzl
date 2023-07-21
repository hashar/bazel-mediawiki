# Bazel rules for dependencies added via composer

common_attrs = {
    "attrs": {
        "require": attr.label_list(allow_files=False),
        "require_dev": attr.label_list(allow_files=False),
    }
}

def _composer_binary_impl(ctx):
    output_file = ctx.actions.declare_file(ctx.label.name + ".output")
    runfiles = ctx.runfiles(files = ctx.attr.binary)

    ctx.actions.run(
        executable = ctx.attr.binary,
        arguments = [ctx.actions.args()],
        outputs = [output_file],
    )

    return [
        DefaultInfo(
            files = depset([output_file]),
            runfiles = runfiles
        )
    ]

    # Default output https://bazel.build/extending/rules#default_outputs
    #return [
    #    DefaultInfo(files = depset([output_file])
    #]
    # Copy pasted from some where
    #return [DefaultInfo(
    #    executable = ctx.attr.binary,
    #)]

composer_binary = rule(
    implementation = _composer_binary_impl,
    executable = True,
    attrs = {
        "binary": attr.label(mandatory=True, allow_single_file=True),
        "require": attr.label_list(allow_files=False),
        "require_dev": attr.label_list(allow_files=False),
    }
)

def _composer_package_impl(ctx):
    pass

composer_package = rule(
    implementation = _composer_package_impl,
    **common_attrs,
)

def _composer_test_impl(ctx):
    pass

composer_test = rule(
    implementation = _composer_test_impl,
    test=True,
    **common_attrs,
)
