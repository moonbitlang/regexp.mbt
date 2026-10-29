#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p data
while read -r checksum name; do
  curl --fail --location --retry 3 --silent --show-error \
    "https://www.unicode.org/Public/16.0.0/ucd/$name" -o "data/$name"
done < ucd.sha256
(cd data && shasum -a 256 -c ../ucd.sha256)
