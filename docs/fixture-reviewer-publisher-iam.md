# Fixture AMO reviewer publisher IAM (UAT, manual)

Hand-rolled role for `consensys-test/amo-submission-dev-test` reviewer S3
upload smoke. **Not** managed by `va-mmc-extension-submission-infra` Terraform
(does not modify `amo-reviewer-publisher`).

| | |
| --- | --- |
| Account | `722264665990` (mmc-uat) |
| Role | `amo-reviewer-publisher-fixture` |
| ARN | `arn:aws:iam::722264665990:role/amo-reviewer-publisher-fixture` |
| Bucket | `uat-va-mmc-extension-submission-amo-reviewer-source` (TF-managed; write via identity policy only) |
| Prefix | `reviewer-source/*` |

## Trust

- `aud` = `sts.amazonaws.com`
- `sub` like `repo:consensys-test/amo-submission-dev-test:ref:refs/heads/release/*`
- `job_workflow_ref` like `…/publish-release-from-release-head.yml@refs/heads/release/*`
- `ref` like `refs/heads/release/*`

No GitHub Environment pin (fixture has none).

## Teardown

```bash
export AWS_PROFILE=mmc-uat
aws iam delete-role-policy \
  --role-name amo-reviewer-publisher-fixture \
  --policy-name put-fixture-reviewer-source-artifacts
aws iam delete-role --role-name amo-reviewer-publisher-fixture
```

## Related

Smoke evidence (S3 keys, AMO-dev attach, Lambda v18→v19): [smoke-results.md](./smoke-results.md).
