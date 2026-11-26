# Business case: zero trust network for a payment platform

## Problem
Payment workloads are usually reachable from the internet through several public ports and trust anything inside the network. One stolen token or open port exposes the platform.

## Solution
A five-service payment platform on EKS in the Landing Zone VPC, with a single inspected entry point (Network Firewall, default drop), a private Kubernetes API, administration only through recorded Session Manager sessions, service roles that stop working outside the VPC, MFA-gated break-glass access, and firewall alerts in Security Hub.

## Value

| Outcome | Measure |
|---|---|
| Smaller attack surface | Open public ports reduced from five to one (proof/) |
| Private control plane | EKS API private only |
| Stolen credentials contained | IRSA explicit deny outside the VPC |
| Audit evidence | Session recordings, CloudTrail, Security Hub findings |
| Reuse | Landing Zone network, ECR, keys, detectors |

## Cost
Largest drivers are the firewall endpoint, interface endpoints and EKS (docs/finops-and-kms.md). Dev and Test use AWS-managed keys. No NAT gateway.

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| Routing changes to Landing Zone route tables | Off by default (`inspect_public_subnets`), Landing Zone owner approval |
| Single firewall endpoint | Per-zone endpoints for prod (roadmap) |
| Mirrored images trusted at mirror time | Shared ECR scanning in CI |
