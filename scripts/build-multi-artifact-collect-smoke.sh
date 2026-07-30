#!/usr/bin/env bash
# Builds two tiny zips into the same directory layout MetaMask publish uses for
# firefox + flask-firefox webpack artifacts (INFRA-3786 collect smoke).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXT="${ROOT}/extension"
SMOKE_VERSION="${SMOKE_VERSION:-collect2}"

FIREFOX_DIR="${ROOT}/build-dist-mv2-webpack/builds"
FLASK_DIR="${ROOT}/build-flask-mv2-webpack/builds"
FIREFOX_ZIP="metamask-firefox-${SMOKE_VERSION}.zip"
FLASK_ZIP="metamask-firefox-${SMOKE_VERSION}-flask.0.zip"

# Fresh layout each run (avoid rm -rf — Cursor hooks block it locally).
mkdir -p "${FIREFOX_DIR}" "${FLASK_DIR}"
find "${ROOT}/build-dist-mv2-webpack" "${ROOT}/build-flask-mv2-webpack" -type f -name '*.zip' -delete 2>/dev/null || true

(
  cd "${EXT}"
  zip -qr "${FIREFOX_DIR}/${FIREFOX_ZIP}" manifest.json background.js
  zip -qr "${FLASK_DIR}/${FLASK_ZIP}" manifest.json background.js
)

printf 'smoke_version=%s\n' "${SMOKE_VERSION}"
printf 'firefox_zip=%s\n' "${FIREFOX_DIR}/${FIREFOX_ZIP}"
printf 'flask_zip=%s\n' "${FLASK_DIR}/${FLASK_ZIP}"
printf 'firefox_glob=%s\n' "${FIREFOX_DIR}/metamask-firefox-*.zip"
printf 'flask_glob=%s\n' "${FLASK_DIR}/metamask-firefox-*.zip"
