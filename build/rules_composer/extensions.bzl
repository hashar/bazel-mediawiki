def _get_composer_path(ctx):
    composer = ctx.which("composer")
    if composer == None:
        fail("No composer executable can be found in PATH")
    return composer

def _composer_install_impl(repository_ctx):

    repository_ctx.report_progress("Symlinking composer files..")
    repository_ctx.symlink(Label("@@//:composer.json"), "composer.json")
    repository_ctx.symlink(Label("@@//:composer.lock"), "composer.lock")

    repository_ctx.report_progress("Running composer install..")
    result = repository_ctx.execute(
        [
            _get_composer_path(repository_ctx),
            '--ansi', 'install',
            '--no-progress', '--prefer-dist'
        ],
        quiet = False,
        environment = {
            'COMPOSER_HOME': 'composer_home',
        },
    )
    if result.return_code != 0:
        fail(result.stderr)

    composer_lock = json.decode(
        repository_ctx.read(
            repository_ctx.path("composer.lock")
        )
    )

    #deps = ([package["name"] for package in composer_lock["packages"]])
    #return [DefaultInfo(files = depset([deps]))]

composer_install = repository_rule(
    attrs = {},
    implementation = _composer_install_impl,
    # TODO should probably pass environ XDG_CACHE_HOME / COMPOSER_HOME from host
)

def _composer_impl(module_ctx):
    for mod in module_ctx.modules:
        for install in mod.tags.install:
            composer_install(name = "composer_deps")
        for run in mod.tags.run:
            module_ctx.execute(
                [_get_composer_path(module_ctx)],
                environment = {
                    'COMPOSER_HOME': module_ctx.path('composer_home')
                },
            )


_run = tag_class(
    attrs={
        "binary": attr.string(mandatory=True),
        "args": attr.string_list(),
    },
    doc="Executes a vendored binary/script",
)
_install = tag_class(
    attrs={},
    doc="Install project dependencies",
)

composer = module_extension(
    implementation = _composer_impl,
    tag_classes = {
        "run": _run,
        "install": _install,
    }
)
