#!/usr/bin/env bash
# Build dist/KodexBar-<version>.plasmoid from metadata.json and contents/.
set -euo pipefail

cd "$(dirname "$0")/.."

version=$(jq -er '.KPlugin.Version' metadata.json)
out="dist/KodexBar-${version}.plasmoid"

mkdir -p dist
rm -f "$out"
zip -rq "$out" metadata.json contents LICENSE

echo "$out"
