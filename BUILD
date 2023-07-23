#load("@rules_composer//:extensions.bzl", "composer")
#composer.install()
#composer.run('jsonlint')

sh_test(
    name = "lintjson",
    srcs = [
        "@composer//:jsonlint",
    ],
    size = "small",
    args = glob(["**/*.json"])
)
