# FinOps and KMS analysis

Dev/Test use AWS-managed keys, Prod uses CMK where governance requires, following the LZ key_strategy.

| Item | Dev / Test | Prod |
|---|---|---|
| Keys | AWS-managed / service-owned | Landing Zone CMKs (`shared_kms_keys`) when `require_cmk = true` |
| KMS fixed cost | none | per CMK per month plus request charges (owned by the Landing Zone) |
| Network Firewall | 1 endpoint | 1 per zone recommended |
| Interface endpoints | 1 zone | 2 zones |
| Budget | `monthly_budget_usd` per environment | Same |

The Landing Zone `key_strategy` is `aws-managed` and every `shared_kms_keys` ARN is null, so dev and test run on AWS-managed keys. The stack never creates a key.

| Resource | Encryption |
|---|---|
| EKS secrets | Envelope encryption with the Landing Zone key when exported, otherwise AWS-managed |
| DynamoDB, SQS | AWS-owned/managed SSE, or the Landing Zone `rds` slot when a CMK is in use |
| Session Manager recordings (S3) | SSE-S3, or the Landing Zone `s3` slot when a CMK is in use |
| In transit | TLS; AWS API calls stay on gateway and interface endpoints |

Cost levers, largest first: the Network Firewall endpoint, the interface endpoints, then EKS (control plane and two t3.medium nodes). The Landing Zone has no NAT, so there is no NAT hourly or per-GB charge. Check current Region prices on the AWS pricing pages before budgeting. Tags `Environment`, `Owner`, `CostCenter` come from `landing_zone.tf`.
