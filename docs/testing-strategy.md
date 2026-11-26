# Testing strategy

| Level | What | Where |
|---|---|---|
| Static | `terraform fmt -check`, `terraform validate` per stack (no backend, no credentials) | `.github/workflows/ci.yml` |
| Unit and posture | Landing Zone resources not recreated, three identical `landing_zone.tf`, provider pins, Region allow-list, no account IDs, SG rules reference security groups, engineer role requires MFA | `tests/test_posture.py` |
| Scripts | `bash -n` on every shell script | CI |
| Security scan | tfsec, Checkov, Trivy, Gitleaks, Bandit | `.github/workflows/security.yml` |
| Plan-time contract | Landing Zone contract guard, CIDR overlap check | every plan |
| Scenarios | `scripts/demo_*.sh`, `scripts/posture_snapshot.sh` (outputs masked into `proof/`) | per environment |
| Dashboard | `console/e2e/flow.mjs` | local |

Run locally: `python3 -I -m unittest discover -s tests`.
