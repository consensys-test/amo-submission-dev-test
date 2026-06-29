#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXT="${ROOT}/extension"
DIST="${ROOT}/dist"
MANIFEST="${EXT}/manifest.json"

VERSION="$(node -p "JSON.parse(require('node:fs').readFileSync('${MANIFEST}','utf8')).version")"
XPI="metamask-firefox-${VERSION}.zip"

rm -rf "${DIST}"
mkdir -p "${DIST}"

(
  cd "${EXT}"
  zip -qr "${DIST}/${XPI}" manifest.json background.js
)

printf 'version=%s\n' "${VERSION}"
printf 'xpi=%s\n' "${DIST}/${XPI}"
