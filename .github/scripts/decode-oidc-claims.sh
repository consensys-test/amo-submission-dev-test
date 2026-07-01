#!/usr/bin/env bash
# Decode GitHub Actions OIDC JWT payload (claims only; no signature verification).
# Usage: decode-oidc-claims.sh <label> [audience]
# Requires ACTIONS_ID_TOKEN_REQUEST_URL and ACTIONS_ID_TOKEN_REQUEST_TOKEN in env.

set -euo pipefail

LABEL="${1:?label required (e.g. CALLER or CALLEE)}"
AUDIENCE="${2:-sts.amazonaws.com}"

if [[ -z "${ACTIONS_ID_TOKEN_REQUEST_URL:-}" || -z "${ACTIONS_ID_TOKEN_REQUEST_TOKEN:-}" ]]; then
  echo "::error::OIDC token request env vars not set (need id-token: write permission)"
  exit 1
fi

REQUEST_URL="${ACTIONS_ID_TOKEN_REQUEST_URL}"
if [[ "${REQUEST_URL}" != *"audience="* ]]; then
  if [[ "${REQUEST_URL}" == *"?"* ]]; then
    REQUEST_URL="${REQUEST_URL}&audience=${AUDIENCE}"
  else
    REQUEST_URL="${REQUEST_URL}?audience=${AUDIENCE}"
  fi
fi

RAW=$(curl -sS \
  -H "Authorization: bearer ${ACTIONS_ID_TOKEN_REQUEST_TOKEN}" \
  "${REQUEST_URL}")

JWT=$(echo "${RAW}" | jq -r '.value // empty')
if [[ -z "${JWT}" ]]; then
  echo "::error::Failed to obtain OIDC token"
  echo "${RAW}"
  exit 1
fi

PAYLOAD_B64=$(echo "${JWT}" | cut -d. -f2)
# JWT base64url → standard base64 with padding
PADDED="${PAYLOAD_B64}$(printf '%*s' $(( (4 - ${#PAYLOAD_B64} % 4) % 4 )) '' | tr ' ' '=')"
CLAIMS=$(echo "${PADDED}" | tr '_-' '/+' | base64 -d 2>/dev/null || true)
if [[ -z "${CLAIMS}" ]]; then
  echo "::error::Failed to decode JWT payload"
  exit 1
fi

echo ""
echo "========== OIDC claims (${LABEL}) =========="
echo "${CLAIMS}" | jq .

echo ""
echo "--- Key claims for orchestrator / workflow_call analysis (${LABEL}) ---"
echo "${CLAIMS}" | jq '{
  sub,
  aud,
  ref,
  sha,
  repository,
  event_name,
  workflow,
  workflow_ref,
  job_workflow_ref,
  job_workflow_sha,
  actor,
  actor_id,
  environment
}'

# Safe summary for step summary (no full token)
{
  echo "### OIDC claims — ${LABEL}"
  echo ""
  echo '```json'
  echo "${CLAIMS}" | jq '{
    sub,
    aud,
    ref,
    event_name,
    workflow,
    workflow_ref,
    job_workflow_ref,
    actor,
    actor_id,
    environment
  }'
  echo '```'
} >> "${GITHUB_STEP_SUMMARY}"
