#!/usr/bin/env bash
# Fixture twin of MetaMask publish-firefox-reviewer-artifacts.sh (INFRA-3735).
#
# Mirrors package|upload + S3 key layout for UAT Lambda download, without:
#   - FIREFOX_BUNDLE_SCRIPT_TOKEN / private clone of MetaMask/firefox-bundle-script
#   - Real MetaMask compare_builds / bundle.sh fetch (needs private tags + prod zips)
#
# package — build source.zip + reviewer notes in the same filenames the Lambda expects
#           (layout follows firefox-bundle-script create_submission_package.sh notes).
# upload  — s3 cp via OIDC (AMO_REVIEWER_BUCKET + AWS creds).
#
# Environment:
#   RELEASE_TAG               — e.g. v1.0.12 (required)
#   AMO_REVIEWER_PACKAGE_ROOT — default $RUNNER_TEMP/amo-reviewer-artifacts
#   AMO_REVIEWER_BUCKET       — required for upload
#   AWS_DEFAULT_REGION        — default us-east-2
#
# UAT platform (hand-rolled fixture role — NOT Terraform):
#   bucket: uat-va-mmc-extension-submission-amo-reviewer-source
#   role:   arn:aws:iam::722264665990:role/amo-reviewer-publisher-fixture

set -euo pipefail

MODE="${1:-}"
if [[ "${MODE}" != "package" && "${MODE}" != "upload" ]]; then
  echo "::error::Usage: $0 package|upload"
  exit 1
fi

if [[ -z "${RELEASE_TAG:-}" ]]; then
  echo "::error::RELEASE_TAG is required"
  exit 1
fi

raw_version="${RELEASE_TAG#v}"
if [[ -z "${raw_version}" || "${raw_version}" == "${RELEASE_TAG}" ]]; then
  echo "::error::RELEASE_TAG must look like vX.Y.Z (got '${RELEASE_TAG}')"
  exit 1
fi

AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-2}"
PACKAGE_ROOT="${AMO_REVIEWER_PACKAGE_ROOT:-${RUNNER_TEMP:-/tmp}/amo-reviewer-artifacts}"
PACKAGE_DIR="${PACKAGE_ROOT}/${raw_version}"
S3_PREFIX="reviewer-source/${raw_version}"
REPO_ROOT="${GITHUB_WORKSPACE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
EXT_DIR="${REPO_ROOT}/extension"

resolve_last_listed_version() {
  local previous
  previous="$(git -C "${REPO_ROOT}" tag -l 'v*' --sort=-v:refname 2>/dev/null \
    | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' \
    | grep -v "^v${raw_version}$" \
    | head -1 \
    | sed 's/^v//' || true)"
  if [[ -z "${previous}" ]]; then
    echo "${raw_version}"
  else
    echo "${previous}"
  fi
}

write_reviewer_instructions() {
  # Same text shape as firefox-bundle-script/scripts/create_submission_package.sh
  local version="$1"
  local notes_dest="$2"
  local flask_args="${3:-}"
  local production_build_file="metamask-firefox-${version}.zip"
  if [[ -n "${flask_args}" ]]; then
    production_build_file="metamask-firefox-${version}.zip"
  fi

  cat > "${notes_dest}" << EOF
INSTRUCTIONS FOR FIREFOX REVIEWERS
===================================

Prerequisites:
* macOS or Linux operating system
* At least 4GB of available RAM

FIXTURE HARNESS NOTE (INFRA-3735):
This package is from consensys-test/amo-submission-dev-test for UAT
amo-submission:dev smoke. It is NOT a MetaMask production reviewer package.
compare_builds / private firefox-bundle-script clone are skipped (no secrets).

To reproduce the build that we submitted:

1. Extract the metamask-extension-${version} source code file that we submitted
2. Change directories to the metamask-extension-${version} directory
3. Make the bundle.sh script executable
4. Run ./bundle.sh ${flask_args}
5. Get the build file out of the build directory

Here are the commands you can run to execute those steps:

unzip metamask-extension-${version}.zip
cd metamask-extension-${version}/
chmod +x ./bundle.sh
./bundle.sh ${flask_args}
cd builds

RESULT:
-------
The ${production_build_file} file in the build directory is the reproduced build.
This should match the ${production_build_file} production build we submitted.

EOF
}

write_submission_notes() {
  # Public GitHub API only — no token. Fixture tags, not MetaMask releases.
  # Shape mirrors firefox-bundle-script generate_submission_notes.sh.
  local version="$1"
  local last_listed="$2"
  local notes_path="$3"
  local repo="${GITHUB_REPOSITORY:-consensys-test/amo-submission-dev-test}"

  {
    echo "## Version-v${version}"
    echo ""
    echo "https://github.com/${repo}/releases/tag/v${version}"
    echo ""
    if [[ "${last_listed}" != "${version}" ]]; then
      echo "## Previous listed: v${last_listed}"
      echo ""
      echo "https://github.com/${repo}/releases/tag/v${last_listed}"
      echo ""
    fi
  } > "${notes_path}"
}

package_variant() {
  local variant="$1"
  local last_listed="$2"
  local version_label source_dest notes_dest flask_args source_dir_name

  if [[ "${variant}" == "flask" ]]; then
    version_label="${raw_version}-flask.0"
    flask_args="--flask"
  else
    version_label="${raw_version}"
    flask_args=""
  fi

  source_dest="${PACKAGE_DIR}/metamask-firefox-${version_label}-source.zip"
  notes_dest="${PACKAGE_DIR}/metamask-firefox-${version_label}-amo-approval-notes.txt"
  source_dir_name="metamask-extension-${version_label}"

  local work
  work="$(mktemp -d)"
  mkdir -p "${work}/${source_dir_name}" "${PACKAGE_DIR}"

  # Source tree ≈ fixture extension + stub bundle.sh (create_submission_package layout).
  cp -R "${EXT_DIR}/." "${work}/${source_dir_name}/"
  cat > "${work}/${source_dir_name}/bundle.sh" << 'BUNDLE'
#!/usr/bin/env bash
# Fixture stub — real MetaMask bundle.sh lives on private firefox-bundle-script tags.
set -euo pipefail
echo "fixture bundle.sh: no-op (INFRA-3735 UAT harness)"
mkdir -p builds
BUNDLE

  chmod +x "${work}/${source_dir_name}/bundle.sh"

  (
    cd "${work}"
    zip -qr "${source_dest}" "${source_dir_name}"
  )

  write_reviewer_instructions "${version_label}" "${notes_dest}" "${flask_args}"

  # Side artifact for local debugging (Lambda only needs approval notes + source zip).
  write_submission_notes "${raw_version}" "${last_listed}" \
    "${PACKAGE_DIR}/firefox_submission_notes_v${version_label}.txt"

  echo "Packaged ${variant}:"
  echo "  ${source_dest}"
  echo "  ${notes_dest}"
  rm -rf "${work}"
}

run_package() {
  if [[ ! -d "${EXT_DIR}" ]]; then
    echo "::error::Missing extension dir at ${EXT_DIR}"
    exit 1
  fi

  mkdir -p "${PACKAGE_DIR}"
  local last_listed
  last_listed="$(resolve_last_listed_version)"
  echo "Using last listed version: ${last_listed}"

  package_variant main "${last_listed}"
  package_variant flask "${last_listed}"
}

run_upload() {
  if [[ -z "${AMO_REVIEWER_BUCKET:-}" ]]; then
    echo "::error::AMO_REVIEWER_BUCKET is required for upload"
    exit 1
  fi

  local required=(
    "${PACKAGE_DIR}/metamask-firefox-${raw_version}-source.zip"
    "${PACKAGE_DIR}/metamask-firefox-${raw_version}-amo-approval-notes.txt"
    "${PACKAGE_DIR}/metamask-firefox-${raw_version}-flask.0-source.zip"
    "${PACKAGE_DIR}/metamask-firefox-${raw_version}-flask.0-amo-approval-notes.txt"
  )

  local artifact
  for artifact in "${required[@]}"; do
    if [[ ! -f "${artifact}" ]]; then
      echo "::error::Package file not found: ${artifact}. Run package step first."
      exit 1
    fi
  done

  for artifact in "${required[@]}"; do
    local key
    key="${S3_PREFIX}/$(basename "${artifact}")"
    echo "Uploading to s3://${AMO_REVIEWER_BUCKET}/${key}"
    aws s3 cp "${artifact}" "s3://${AMO_REVIEWER_BUCKET}/${key}" --region "${AWS_DEFAULT_REGION}"
  done

  echo "Reviewer artifacts uploaded to s3://${AMO_REVIEWER_BUCKET}/${S3_PREFIX}/"
}

case "${MODE}" in
  package) run_package ;;
  upload) run_upload ;;
esac
