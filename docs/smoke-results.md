# Smoke results (UAT harness)

Evidence for fixture-repo + MetaMask AMO-dev exercises against UAT
`amo-submission:dev`. Personal gecko listing only — not MetaMask production.

## Lambda `dev` alias: v18 → v19

Manual UAT config publish (not Terraform). Same signed artifact as v18.

| Field | v18 | v19 |
| --- | --- | --- |
| `CodeSha256` | `QqndxmBcwYQzZF0ShwkX+mwJj4mO7iZ5a2YotWOnTcA=` | **identical** |
| Runtime / handler / role / memory / timeout | `nodejs24.x` / `index.handler` / `amo-submission-execution` / 512 / 300 | **identical** |
| Env keys | 7 keys (includes `AMO_REVIEWER_BUCKET`) | **same 7 + `AMO_REVIEWER_REQUIRED`** |
| `AMO_REVIEWER_REQUIRED` | unset | `true` |
| Version description | empty | `UAT reviewer source attachment smoke: AMO_REVIEWER_REQUIRED=true (INFRA-3735)` |

**Conclusion:** v19 is a one-env-var republish of v18 code. Rollback: point `dev` alias back to `18`.

## L2b — reviewer S3 upload → Lambda download (2026-08-07)

| Step | Result | Evidence |
| --- | --- | --- |
| Fixture OIDC assume | Assumed `amo-reviewer-publisher-fixture` (hand-rolled; not TF `amo-reviewer-publisher`) | [orchestrator 31218229073](https://github.com/consensys-test/amo-submission-dev-test/actions/runs/31218229073) Phase 1 |
| Package + S3 put | Four objects under `reviewer-source/1.0.12/` (main + flask source + notes), SSE-AES256 | same run; bucket `uat-va-mmc-extension-submission-amo-reviewer-source` |
| GitHub Release + attest | `v1.0.12` zip + `.sigstore.json` + SHA256SUMS; Phase 2 verify green | [release](https://github.com/consensys-test/amo-submission-dev-test/releases/tag/v1.0.12) |
| AMO-dev invoke | First submit `idempotent=false` | [MetaMask run 31218369579](https://github.com/MetaMask/metamask-extension/actions/runs/31218369579) |
| Lambda attach | `attestation_verified=true`, `source_attached=true`, `approval_notes_attached=true`, `release_notes_attached=true` | CloudWatch `/aws/lambda/amo-submission` request `a874ba59-…` |

### S3 keys written

```
reviewer-source/1.0.12/metamask-firefox-1.0.12-source.zip
reviewer-source/1.0.12/metamask-firefox-1.0.12-amo-approval-notes.txt
reviewer-source/1.0.12/metamask-firefox-1.0.12-flask.0-source.zip
reviewer-source/1.0.12/metamask-firefox-1.0.12-flask.0-amo-approval-notes.txt
```

### What this proves / does not prove

**Proves:** nested `workflow_call` OIDC for fixture publisher role; UAT S3 put layout Lambda expects; Lambda GetObject + AMO source/notes attach with `AMO_REVIEWER_REQUIRED=true` on `:dev`.

**Does not prove:** private `firefox-bundle-script` / `compare_builds` packaging; Terraform-managed `amo-reviewer-publisher` trust; PRD flask/production submit.

## Related earlier runs

| Layer | Version | Run |
| --- | --- | --- |
| L1 orchestrator | `1.0.11` | [31216005245](https://github.com/consensys-test/amo-submission-dev-test/actions/runs/31216005245) |
| L2 AMO-dev (no reviewer attach) | `1.0.11` | [31216087713](https://github.com/MetaMask/metamask-extension/actions/runs/31216087713) (`source_attached=false`) |
