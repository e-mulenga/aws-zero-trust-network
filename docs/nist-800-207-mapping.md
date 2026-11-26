# NIST SP 800-207 and CISA maturity mapping

Zero trust here means no implicit trust from network location: every request is authenticated, authorised and inspected.

## The seven tenets

| # | Tenet | Implementation |
|---|---|---|
| 1 | All data sources and services are resources | Per-service IRSA roles; per-table DynamoDB access; per-tier security groups |
| 2 | All communication is secured regardless of location | TLS; private subnets; gateway and interface endpoints; Network Firewall default drop |
| 3 | Access is granted per session | Break-glass engineer role with a one-hour session and fresh MFA; Session Manager sessions recorded |
| 4 | Access follows dynamic policy | IAM conditions on `aws:SourceVpce` / `aws:SourceVpc`, `aws:MultiFactorAuthAge`, `aws:RequestedRegion` |
| 5 | Asset integrity is monitored | Landing Zone Config, GuardDuty, Security Hub; Access Analyzer (consumed) |
| 6 | Authentication and authorisation are strict | Explicit denies win over allows; permission boundary blocks escalation |
| 7 | Posture information is collected | Landing Zone CloudTrail; firewall alert and flow logs; Security Hub findings |

## Pillars

| Pillar | Control in this repository | Owner |
|---|---|---|
| Identity | IRSA roles with explicit deny, engineer role with MFA and boundary, Identity Center | This repo and Landing Zone |
| Devices | Session Manager only, no SSH, nodes without public IPs | This repo |
| Network | Network Firewall, private EKS API, endpoints, tier security groups | This repo on the Landing Zone VPC |
| Workload | Istio mTLS, shared ECR, per-service roles | This repo |
| Data | DynamoDB PITR and SSE, SQS DLQs, key strategy | This repo and Landing Zone keys |
| Visibility | Firewall findings in Security Hub, Landing Zone CloudTrail, GuardDuty, Config | Landing Zone and this repo |
| Automation | Terraform, CI scanning, Lambda finding import | This repo |

## CISA maturity (self-assessment)

| Pillar | Level | Next step |
|---|---|---|
| Identity | Advanced | Phishing-resistant MFA through Identity Center |
| Devices | Advanced | Compliance scoring and quarantine |
| Networks | Advanced | Verified Access, per-zone firewall endpoints |
| Applications | Advanced | Build attestation (SLSA) |
| Data | Initial to Advanced | Macie classification |
| Visibility | Advanced | Automated correlation and remediation |
| Automation | Advanced | Incident-response orchestration |

Compliance themes served: PCI-DSS (access control, segmentation, MFA), POPIA and GDPR (minimisation, encryption, access logging), SOC 2 and ISO 27001 (logical access, monitoring).
