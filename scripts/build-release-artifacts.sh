#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXT="${ROOT}/extension"
DIST="${ROOT}/dist"
MANIFEST="${EXT}/manifest.json"

VERSION="$(node -p "JSON.parse(require('node:fs').readFileSync('${MANIFEST}','utf8')).version")"
XPI="metamask-firefox-${VERSION}.zip"
SOURCE="metamask-firefox-${VERSION}-source.zip"

rm -rf "${DIST}"
mkdir -p "${DIST}/source"

(
  cd "${EXT}"
  zip -qr "${DIST}/${XPI}" manifest.json background.js
)

cp "${EXT}/manifest.json" "${EXT}/background.js" "${EXT}/build.sh" "${DIST}/source/"
chmod +x "${DIST}/source/build.sh"
(
  cd "${DIST}/source"
  zip -qr "${DIST}/${SOURCE}" .
)

printf 'version=%s\n' "${VERSION}"
printf 'dist=%s\n' "${DIST}"
