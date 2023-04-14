# Bazel rules for dependencies added via composer

common_attrs = {
    attrs={
        "require": attr.label_list(allow_files=False),
        "require_dev": attr.label_list(allow_files=False),
    },

def _composer_binary_impl(ctx):
    pass

composer_binary = rule(
    implementation = _composer_binary_impl,
    **common_attrs,
    executable = True,
)

def _composer_library_impl(ctx):
    pass

composer_library = rule(
    implementation = _composer_library_impl,
    **common_attrs,
)

def _composer_test_impl(ctx):
    pass

composer_test = rule(
    implementation = _composer_test_impl,
    **common_attrs,
    test=True,
)
