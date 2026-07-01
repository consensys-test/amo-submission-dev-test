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
