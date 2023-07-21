Proof of concept to ultimately run MediaWiki core tests with Bazel.

Maybe check "Bzlmod Lock File" proposal:
https://docs.google.com/document/d/1HPeH_L-lRK54g8A27gv0q7cbk18nwJ-jOq_14XEiZdc/edit?pli=1

Upstream docs
=============

https://bazel.build/extending/concepts explains Bazel three phases:
* LOADING: evaluate BUILD files to instantiate rules and evalute macros.
* ANALYSIS: implementation of rules executed and actions instantiated.
* EXECUTION: execute actions

https://bazel.build/extending/rules

https://bazel.build/extending/macros
Instantiate rules during LOADING phase.

Things ™
========

Install composer dependencies:
```
bazel fetch @composer//:all
```
The result is somewhere under `$(bazel info output_base)/external`

List the composer dependencies as Bazel targets:
```
bazel query @composer//:all
```

Notes
=====

Misc
~~~~
- Composer hooks are not run, it should be invoked somehow
- there is no autoloader generated
- --override_repository=composer=path/to/mediawiki/vendor

Cache downloaded zip files
~~~~~~~~~~~~~~~~~~~~~~~~~~

See https://github.com/bazelbuild/rules_jvm_external and coursier.bzl.

The artifacts are downloaded from the URL defined in `composer.lock`. We need a
custom lock file with sha256sum to let Bazel store them in the CAS cache.

We need a pin mechanism:
- download files
- compute their sha256
- write a pin file of some sort (composer_install.json) which has the original
  URL and the sha256.
Currently they are downloaded in the repository and get nuked on any change
forcing a redownload.

Bin
~~~

Each of the vendor bin scripts should be a `php_binary`?

License
=======

Copyright © 2023, Antoine "hashar" Musso <hashar@free.fr>

Usage license is undeterminated but will later be choosen between either:
- GPL2 or later (like MediaWiki)
- Apache License 2 (like Quibble and Bazel)
