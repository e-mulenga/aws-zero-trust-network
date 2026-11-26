# Issues resolved in the merge

Scope: combine `aws-zero-trust-network` (EKS payment platform with network controls) and `zero_trust_aws` (NIST-aligned account controls) into one repository that consumes the Landing Zone.

| # | Issue | Resolution |
|---|---|---|
| 1 | Two repositories described the same subject with overlapping modules | One repository, `aws-zero-trust-network`; unique controls of the second kept (engineer role, boundary, tier security groups, NIST mapping) |
| 2 | The second repository created its own VPC, KMS key, CloudTrail, GuardDuty, Security Hub, Config and Access Analyzer | Removed; consumed from the Landing Zone |
| 3 | Its engineer role trusted any principal (`*`) when the list was empty | Role is created only when principals are supplied |
| 4 | Its Region deny allowed only us-east-1 | Allows af-south-1 and eu-west-1 only |
| 5 | Its provider pin was `~> 5.0` and Terraform 1.5; no `provider.tf` split | AWS provider >= 6.27 and < 7.0, Terraform >= 1.10, `provider.tf` in every stack |
| 6 | Stacks mixed AWS provider 5.80 and 6.0; EKS module 20.x | One pin; EKS module 21.x with renamed inputs |
| 7 | `backend.tf` beside `provider.tf`; nested `infra/baseline/` | Backend in `provider.tf`; stacks at `infra/{cluster,data,zerotrust}` |
| 8 | `stage` environment and a hard CMK requirement in non-dev | `dev`, `test`, `prod`; `require_cmk` input, true in prod |
| 9 | State key `zero-trust-network/<env>/<stack>` | `aws-zero-trust-network/<env>/<stack>` |
| 10 | Docs and CI referred to another IaC tool | Terraform only |
| 11 | Docs listed stale Landing Zone gaps (Security Hub disabled, state location missing) | Updated to the current outputs; `access_analyzer_arn` and `terraform_state` consumed |
| 12 | No tests, no business case | `tests/test_posture.py`, business case, this file |
| 13 | A personal email address was the default alarm recipient in the second repository | Removed; recipients are supplied at apply time |
