#load("@rules_composer//:extensions.bzl", "composer")
#composer.install()
#composer.run('jsonlint')

load("@rules_composer//:composer.bzl", "composer_test")

composer_test(
    name = "lintjson",
    binary = "@composer//:bin/jsonlint",
    size = "small",
    args = glob(["**/*.json"])
)
