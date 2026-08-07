# amo-submission-dev-test

Public release artifacts for UAT `amo-submission:dev` smoke tests.

## OIDC claim probe (INFRA-3735)

Workflows to print GitHub Actions OIDC JWT claims for **caller vs callee** when using `workflow_call` (mirrors MetaMask orchestrator → store upload pattern).

| Workflow | Trigger | What it prints |
| --- | --- | --- |
| `oidc-dump-orchestrator.yml` | `workflow_dispatch` | **CALLER** claims in job 1, then invokes callee |
| `oidc-dump-callee.yml` | `workflow_call` or direct `workflow_dispatch` | **CALLEE** claims |

### Run

1. Actions → **OIDC dump — orchestrator (caller)** → Run workflow (default `caller-and-callee`).
2. Compare **CALLER** vs **CALLEE** job logs / summaries for `workflow_ref`, `job_workflow_ref`, `ref`, `event_name`, `actor`.

Direct callee-only run: **OIDC dump — callee (reusable)** → Run workflow.

### Claims to compare (MetaMask store upload trust)

| Claim | Expected when orchestrator calls upload workflow |
| --- | --- |
| `ref` | Caller branch (`refs/heads/main` or `release/*`) |
| `event_name` | Caller event (`workflow_dispatch`) |
| `actor` / `actor_id` | Caller actor (Runway bot in prod) |
| `workflow_ref` | **Verify** — caller vs callee path |
| `job_workflow_ref` | **Verify** — should be callee upload workflow path |

Results inform CWS WIF CEL (`workflow_ref`) vs AMO IAM (`job_workflow_ref`) updates.

## L1 fixture orchestrator (INFRA-3735 harness)

Mirrors MetaMask `runway-extension-release-and-submit.yml` without CWS/AMO:

| Workflow | Role |
| --- | --- |
| `runway-extension-release-and-submit.yml` | Phase 0 validate → Phase 1 publish → Phase 2 verify |
| `publish-release-from-release-head.yml` | Attest + `.sigstore.json` + SHA256SUMS + GitHub Release (`workflow_call`) |
| `verify-release-attestations.yml` | Download release, `sha256sum -c`, require Sigstore asset, `gh attestation verify` |

Calling jobs grant the attestation permission ceiling (`write` for publish, `read` for verify). No AWS/GCP. Mutations are tags/releases in this repo only.

### Run

```bash
git checkout -b release/1.0.11 origin/main   # manifest version must match
git push -u origin HEAD
gh workflow run runway-extension-release-and-submit.yml --ref release/1.0.11
# Re-dispatch: Phase 1 auto-skips when release exists at the same SHA
```

## Attested fixture release (INFRA-3786)

Publishes a minimal Firefox zip with a Sigstore build-provenance bundle so UAT
`amo-submission` can exercise `ATTESTATION_REQUIRED=true` without a MetaMask
extension release cut.

The workflow path is intentionally
`.github/workflows/publish-release-from-release-head.yml` and must run from a
`release/*` branch — matching the Lambda defaults for
`ATTESTATION_SIGNER_WORKFLOW` and `ATTESTATION_SIGNER_REF_PATTERN`.

### Publish

```bash
# After the workflow is on main:
git checkout -b release/1.0.8 origin/main
git push -u origin HEAD
gh workflow run publish-release-from-release-head.yml --ref release/1.0.8
```

### Verify (CWS-style)

```bash
gh release download v1.0.8 --repo consensys-test/amo-submission-dev-test
gh attestation verify metamask-firefox-1.0.8.zip \
  --repo consensys-test/amo-submission-dev-test \
  --signer-workflow consensys-test/amo-submission-dev-test/.github/workflows/publish-release-from-release-head.yml
```

### Verify (AMO-style)

Confirm `metamask-firefox-1.0.8.zip.sigstore.json` is on the release, then invoke
UAT `amo-submission:dev` with `version=1.0.8` (after the hardened Lambda from
INFRA-3786 is deployed).

## AMO reviewer artifacts (UAT, INFRA-3735)

Publish also packages + uploads reviewer source/notes to the UAT bucket via a
**hand-rolled** OIDC role (`amo-reviewer-publisher-fixture`) — not the
Terraform `amo-reviewer-publisher` role. No GitHub secrets.

| | |
| --- | --- |
| Action | `.github/actions/publish-amo-reviewer-artifacts/` |
| Script | `.github/scripts/publish-firefox-reviewer-artifacts.sh` |
| IAM notes | [docs/fixture-reviewer-publisher-iam.md](docs/fixture-reviewer-publisher-iam.md) |
| Keys | `reviewer-source/{version}/metamask-firefox-{version}[-flask.0]-{source.zip\|amo-approval-notes.txt}` |

**Included (mirrors MetaMask layout / firefox-bundle-script notes):** source zip with
`metamask-extension-{version}/` + stub `bundle.sh`, reviewer instructions text,
flask + main variants, S3 upload via OIDC.

**Skipped (would need secrets or MetaMask prod assets):** private
`firefox-bundle-script` clone, `compare_builds.sh`, real per-version `bundle.sh`
fetch, MetaMask release notes API scrape.

### Proven run

- Fixture orchestrator: [31218229073](https://github.com/consensys-test/amo-submission-dev-test/actions/runs/31218229073)
- Release: [v1.0.12](https://github.com/consensys-test/amo-submission-dev-test/releases/tag/v1.0.12)
- MetaMask AMO-dev download/attachment: [31218369579](https://github.com/MetaMask/metamask-extension/actions/runs/31218369579)

UAT `dev` used Lambda version 19 with `AMO_REVIEWER_REQUIRED=true`. The first
submission returned `attestation_verified=true`, `source_attached=true`,
`approval_notes_attached=true`, and `release_notes_attached=true`.

