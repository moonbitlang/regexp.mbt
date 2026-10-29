# Unicode table generator

This native MoonBit program regenerates the regexp library's case-folding,
general-category, and property-alias tables from Unicode 16.0.0. The local
workspace uses the regexp source in the parent directory.

From this directory:

```sh
bash download.sh
moon update
moon check --target native --deny-warn
moon run --target native src -- data ../internal/unicode
moon -C .. fmt
```

`download.sh` fetches the three files from the official Unicode 16.0.0 UCD and
verifies their SHA-256 hashes against `ucd.sha256` before generation. To use
already downloaded data or inspect output separately, pass an existing input
and output directory as the two arguments. The generator itself does no network
I/O. The optional `just run` recipe downloads, verifies, generates, and formats.

CI regenerates the tables and requires a clean diff, so toolchain migrations
cannot silently change Unicode behavior. For an intentional Unicode upgrade,
review the version, checksums, generated table changes, and library tests
together. The `prebuild` directory is excluded from the published library.
