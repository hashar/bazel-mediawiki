PhpLibraryInfo = provider(
    doc = "Holds information about a Composer package",
    fields = {
        "require": "A depset of requires",
        "require_dev": "A depset of development requirements",
    }
)

def _get_composer_path(ctx):
    composer = ctx.which("composer")
    if composer == None:
        fail("No composer executable can be found in PATH")
    return composer

# Composer 2.3.3 src/Composer/Repository/PlatformRepository.php
#
# {^(?:php(?:-64bit|-ipv6|-zts|-debug)?|hhvm|(?:ext|lib)-[a-z0-9](?:[_.-]?[a-z0-9]+)*|composer(?:-(?:plugin|runtime)-api)?)$}
def _filter_platform_packages(requires):
    return [
        r for r in requires
        if r not in [
            'php', 'php-64bit', 'php-ipv6', 'php-zts', 'php-debug', 'hhvm',
            'composer', 'composer-plugin-api', 'composer-runtime-api',
        ]
        and not r.startswith((
            'ext-',
            'lib-'
        ))
    ]

def _format_composer_package(name, require=[], require_dev=[]):
    if not require and not require_dev:
        return "composer_package(name=\"%s\")\n" % name

    indent = ' ' * len('composer_package(')

    out = "composer_package(name=\"%s\"" % name
    # FIXME avoid copy pasted code
    if require:
        out += ",\n"
        out += indent + "require=[\n"
        for r in require:
            out +=  indent + "  \"%s\",\n" % r
        out += indent + "]"
    if require_dev:
        out += ",\n"
        out += indent + "require_dev=[\n"
        for r in require_dev:
            out +=  indent + "  \"%s\",\n" % r
        out += indent + "]\n"
    out += ")\n"

    return out


def _composer_install_impl(repository_ctx):
    repository_ctx.report_progress("Importing project composer files..")
    repository_ctx.symlink(Label("@@//:composer.json"), "imported_composer.json")
    repository_ctx.symlink(Label("@@//:composer.lock"), "imported_composer.lock")

    vendor_path = repository_ctx.path('vendor')

    #repository_ctx.report_progress("Running composer install..")
    #result = repository_ctx.execute(
    #    [
    #        _get_composer_path(repository_ctx),
    #        '--ansi',
    #        'install',
    #            '--prefer-dist',
    #            '--profile',
    #            '--no-interaction',
    #            '--no-progress',
    #    ],
    #    quiet = False,
    #    environment = {
    #        'COMPOSER_HOME': 'composer_home',
    #    },
    #)
    #
    #if result.return_code != 0:
    #    fail(result.stderr)

    composer_json = json.decode(
        repository_ctx.read(
            repository_ctx.path(
                repository_ctx.attr.composer_json
            )
        )
    )
    composer_lock = json.decode(
        repository_ctx.read(
                repository_ctx.attr.composer_lock
        )
    )

    repository_ctx.report_progress("Installing dependencies..")
    packages = composer_lock["packages"] + composer_lock["packages-dev"]
    for package in packages:
        # FIXME Bazel does not cache the downloads (probably due to lack of sha256 / integrity)
        repository_ctx.report_progress("%s (%s)" % (package["name"], package["dist"]["type"]))
        extract_path = repository_ctx.path('extracted').get_child(package["name"])
        repository_ctx.download_and_extract(
            package["dist"]["url"],
            output = extract_path,
            type = package["dist"]["type"],
        )

        # Github artifacts have a leading directory made of the name of the
        # repository and either a tag or the short commit sha1. The later does
        # not have a fixed size since there can be short sha1 collision on
        # large repositories.
        # We instead move files along, expecting the artifact to have a single
        # root directory.
        repository_ctx.report_progress("Moving extracted content under vendor")
        extract_content = extract_path.readdir()
        if len(extract_content) != 1:
            fail("Extracted composer package %s has multiple entries: %s" % (
                package["name"], extract_content))

        vendor_org_path = vendor_path.get_child(extract_path.dirname.basename)
        repository_ctx.execute(["mkdir", "-p", vendor_org_path])
        repository_ctx.execute([
            "mv",
            extract_content[0],
            vendor_org_path.get_child(extract_path.basename)
        ])

    repository_ctx.report_progress("Processing composer dependencies..")

    # Packages names requested developers
    require = _filter_platform_packages(composer_json.get("require", {}).keys())
    require_dev = _filter_platform_packages(composer_json.get("require-dev", {}).keys())

    # Locked packages names including their transitive dependencies
    locked = {l["name"]: l for l in composer_lock["packages"]
              if _filter_platform_packages([l["name"]])}
    locked_dev = {l["name"]: l for l in composer_lock["packages-dev"]
                  if _filter_platform_packages([l["name"]])}

    libs = ''
    binaries = ''
    seen = {}
    for requirement in require + require_dev:
        is_dev = requirement in require_dev
        key = 'packages-dev' if is_dev else 'packages'

        # FIXME mark dev as such somehow handle them?
        transitive_reqs = _filter_platform_packages(
            locked.get(requirement, {})
                  .get("require", {}).keys())
        for transitive_req in transitive_reqs:
            if transitive_req in seen:
                continue
            libs += _format_composer_package(transitive_req)
            seen[transitive_req] = True

        if requirement not in seen:
            libs += _format_composer_package(requirement, require=transitive_reqs)
            seen[requirement] = True

    repository_ctx.report_progress("Installing packages binaries")
    for package in composer_lock["packages"] + composer_lock["packages-dev"]:
        for binary in package.get("bin", []):
            bin_src = vendor_path.get_child(package['name'], binary)

            repository_ctx.file(
                vendor_path.get_child(binary),
                content = repository_ctx.read(bin_src),
                executable = True,
            )
            # TODO add dep/require?
            # TODO should we move the logic above inside _composer_binary_impl??
            binary_label = Label(bin_src.basename)
            binaries += 'composer_binary(name="%s", binary=":vendor/%s")\n' % (binary, binary)
            # FIXME add require

    #deps = ([package["name"] for package in composer_lock["packages"]])
    #return [DefaultInfo(files = depset([deps]))]

    repository_ctx.report_progress("Generating BUILD files..")
    # FIXME use a flat file, and repository_ctx.template
    # https://bazel.build/rules/lib/builtins/repository_ctx#template
    repository_ctx.file("BUILD.bazel",
"""\
package(default_visibility = ["//visibility:public"])
load("@rules_composer//:composer.bzl", "composer_binary", "composer_package")

exports_files(["{composer_json}", "{composer_lock}"])
#exports_files(glob(["bin/*"]))

{libs}

{binaries}

{deps_target}
""".format(
    composer_json = "imported_composer.json",
    composer_lock = "imported_composer_lock",
    libs = libs,
    binaries = binaries,
    deps_target = _format_composer_package("deps", require=require, require_dev=require_dev)
    ),
        executable = False,
    )

    return [DefaultInfo(
        files = depset(
            direct=require,
            transitive=[depset(
                [t for t in locked.keys() if t not in require]
            )]
        )
    )]

composer_install = repository_rule(
    implementation = _composer_install_impl,
    attrs={
        "composer_json": attr.label(default="@@//:composer.json"),
        "composer_lock": attr.label(default="@@//:composer.lock"),
    }
    # TODO we might later want to pass environ XDG_CACHE_HOME / COMPOSER_HOME
    # from host to retrieve artifacts from the local shared cache.
    # environ=['COMPOSER_HOME', 'XDG_CACHE_HOME']
)

def _composer_impl(module_ctx):
    for mod in module_ctx.modules:
        for install in mod.tags.install:
            composer_install(name = "composer")
        for run in mod.tags.run:
            module_ctx.report_progress("composer run")
            #composer_home = module_ctx.path('composer_home')
            #module_ctx.execute(['/usr/bin/mkdir', '-p', composer_home])
            module_ctx.execute(
                [_get_composer_path(module_ctx)],
                environment = {
                    'COMPOSER_HOME': 'composer_home',
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
