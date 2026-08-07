#!/usr/bin/env bash
# Build the fixture Firefox zip for UAT amo-submission:dev.
#
# Optional env:
#   FIXTURE_PAD_MIB — uncompressed padding size in MiB (default 20).
#                     Uses /dev/urandom so the zip stays ~FIXTURE_PAD_MIB on disk
#                     (INFRA-3675 size / JWT poll timing smoke). Set 0 for tiny zip.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXT="${ROOT}/extension"
DIST="${ROOT}/dist"
MANIFEST="${EXT}/manifest.json"
PAD_MIB="${FIXTURE_PAD_MIB:-20}"

VERSION="$(node -p "JSON.parse(require('node:fs').readFileSync('${MANIFEST}','utf8')).version")"
XPI="metamask-firefox-${VERSION}.zip"
PAD_NAME="size-pad.bin"

rm -rf "${DIST}"
mkdir -p "${DIST}"

ZIP_ARGS=(manifest.json background.js)
if [[ "${PAD_MIB}" != "0" ]]; then
  # Random bytes resist zip deflate; keeps artifact ~PAD_MIB for Lambda timing tests.
  dd if=/dev/urandom of="${EXT}/${PAD_NAME}" bs=1M count="${PAD_MIB}" status=none
  ZIP_ARGS+=("${PAD_NAME}")
fi

(
  cd "${EXT}"
  zip -qr "${DIST}/${XPI}" "${ZIP_ARGS[@]}"
  rm -f "${PAD_NAME}"
)

printf 'version=%s\n' "${VERSION}"
printf 'xpi=%s\n' "${DIST}/${XPI}"
printf 'pad_mib=%s\n' "${PAD_MIB}"
ls -lh "${DIST}/${XPI}" >&2
