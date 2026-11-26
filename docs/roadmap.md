# Roadmap

1. Landing Zone owner exports CMKs (including an `eks` slot), route table IDs, IGW ID and flow logs; prod then runs with `require_cmk = true`.
2. One firewall endpoint per zone; endpoint policies on the gateway and interface endpoints.
3. WAF in front of the Istio ingress; Inspector for image scanning.
4. AWS Verified Access for application-layer zero trust.
5. IAM Identity Center with phishing-resistant MFA (WebAuthn/FIDO2) replacing the break-glass role for routine access.
6. Automated remediation of Security Hub findings (Lambda or Step Functions).
7. Pilot-light DR rehearsal in eu-west-1 with measured RTO.
