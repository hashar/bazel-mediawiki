# Bazel rules for dependencies added via composer

def _composer_binary_impl(ctx):
    output_file = ctx.actions.declare_file(ctx.label.name + ".output")
    binary_file = ctx.attr.binary.files.to_list()[0]
    runfiles = ctx.runfiles(files = [binary_file])

    # Use `composer exec -- <binary> <args>`
    execf = ctx.actions.declare_file(binary_file.path)
    ctx.actions.symlink(
        output = execf,
        target_file = binary_file,
        is_executable = True,
    )

    ctx.actions.run(
        executable = execf,
        arguments = [ctx.actions.args()],
        outputs = [output_file],
    )

    return [
        DefaultInfo(
            files = depset([output_file]),
            executable = execf,
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
    attrs = {
        "require": attr.label_list(allow_files=False),
        "require_dev": attr.label_list(allow_files=False),
    }
)

def _composer_test_impl(ctx):
    return _composer_binary_impl(ctx)

composer_test = rule(
    implementation = _composer_test_impl,
    test=True,
    attrs = {
        "binary": attr.label(mandatory=True, allow_files=True),
        "require": attr.label_list(allow_files=False),
        "require_dev": attr.label_list(allow_files=False),
    }
)
