# Regional availability (af-south-1) and the Ireland rule

Rule: if a service is not available in af-south-1, it runs from eu-west-1 (the DR Region) through an `ireland` provider alias, with the check date and sources recorded. No other Region is used.

Checked on 2026-11-26 against the AWS General Reference endpoint pages. Both Regions are listed for every service below, so nothing runs from Ireland and no alias is defined.

| Service | af-south-1 | eu-west-1 | Source |
|---|---|---|---|
| Amazon EKS | Yes | Yes | https://docs.aws.amazon.com/general/latest/gr/eks.html |
| AWS Network Firewall | Yes | Yes | https://docs.aws.amazon.com/general/latest/gr/network-firewall.html |
| AWS Systems Manager (Session Manager) | Yes | Yes | https://docs.aws.amazon.com/general/latest/gr/ssm.html |
| Amazon DynamoDB and DynamoDB Streams | Yes | Yes | https://docs.aws.amazon.com/general/latest/gr/ddb.html |
| Amazon SQS | Yes | Yes | https://docs.aws.amazon.com/general/latest/gr/sqs-service.html |
| Amazon ECR | Yes | Yes | https://docs.aws.amazon.com/general/latest/gr/ecr.html |
| AWS Lambda | Yes | Yes | https://docs.aws.amazon.com/general/latest/gr/lambda-service.html |
| Amazon EventBridge | Yes | Yes | https://docs.aws.amazon.com/general/latest/gr/ev.html |
| Amazon SNS | Yes | Yes | https://docs.aws.amazon.com/general/latest/gr/sns.html |
| Amazon CloudWatch | Yes | Yes | https://docs.aws.amazon.com/general/latest/gr/cw_region.html |

Landing Zone services this repository only consumes (GuardDuty, Security Hub, Config, CloudTrail, Access Analyzer, KMS) are owned and checked by the Landing Zone.

Re-check this table before adding a service. If one fails the check, put only that resource on `provider = aws.ireland`, use the Landing Zone `eu_west_1` network outputs, label it "deployed from eu-west-1" in the README and diagrams, and record data residency, latency and cost in an ADR.
