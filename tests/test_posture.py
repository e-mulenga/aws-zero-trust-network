"""Static posture checks for the repository (no AWS access, no Terraform needed)."""
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parent.parent
STACKS = ["cluster", "data", "zerotrust"]
SKIP_DIRS = {"node_modules", "__pycache__", ".git", "proof", "tests"}


def text_files():
    for p in ROOT.rglob("*"):
        if p.is_file() and not (set(p.relative_to(ROOT).parts) & SKIP_DIRS):
            if p.suffix in {".tf", ".md", ".sh", ".py", ".yml", ".yaml", ".example", ".tftpl", ".js", ".jsx", ".json"} and p.name != "package-lock.json":
                yield p


def read(p):
    with open(p, encoding="utf-8") as fh:
        return fh.read()


class Posture(unittest.TestCase):
    def test_each_stack_has_provider_file_and_no_versions_file(self):
        for s in STACKS:
            self.assertTrue((ROOT / "infra" / s / "provider.tf").exists(), s)
            self.assertFalse((ROOT / "infra" / s / "versions.tf").exists(), s)
            self.assertFalse((ROOT / "infra" / s / "backend.tf").exists(), s)

    def test_landing_zone_files_are_identical(self):
        texts = {read(ROOT / "infra" / s / "landing_zone.tf") for s in STACKS}
        self.assertEqual(len(texts), 1)

    def test_provider_pins(self):
        for s in STACKS:
            t = read(ROOT / "infra" / s / "provider.tf")
            self.assertIn('version = ">= 6.27.0, < 7.0"', t)
            self.assertIn('required_version = ">= 1.10.0"', t)
            self.assertIn('backend "s3" {}', t)

    def test_contract_version_two(self):
        t = read(ROOT / "infra/zerotrust/landing_zone.tf")
        self.assertIn('default     = "2"', t)
        self.assertIn("contract_schema_version", t)

    def test_only_approved_regions(self):
        for p in ROOT.glob("infra/**/*.tf"):
            for m in re.findall(r'"((?:us|eu|ap|sa|ca|me|af)-[a-z]+-\d)"', read(p)):
                self.assertIn(m, {"af-south-1", "eu-west-1"}, p)

    def test_landing_zone_resources_not_recreated(self):
        banned = ["aws_vpc\"", "aws_nat_gateway", "aws_kms_key", "aws_guardduty_detector\"", "aws_securityhub_account",
                  "aws_cloudtrail\"", "aws_config_configuration_recorder", "aws_accessanalyzer_analyzer",
                  "aws_ecr_repository", "aws_internet_gateway\""]
        for p in ROOT.glob("infra/**/*.tf"):
            t = read(p)
            for b in banned:
                self.assertNotIn(f'resource "{b}' if b.endswith('"') else f'resource "{b}"', t, f"{b} in {p}")

    def test_engineer_role_requires_mfa_and_never_trusts_everyone(self):
        t = read(ROOT / "infra/zerotrust/engineer_access.tf")
        self.assertIn("aws:MultiFactorAuthPresent", t)
        self.assertIn("aws:MultiFactorAuthAge", t)
        self.assertIn("aws:RequestedRegion", t)
        self.assertNotIn('"*"]', t.split("data \"aws_iam_policy_document\" \"engineer_trust\"")[1].split("resource")[0])

    def test_tier_rules_reference_security_groups_not_cidrs(self):
        t = read(ROOT / "infra/zerotrust/tier_segmentation.tf")
        self.assertNotIn("cidr_ipv4", t)
        self.assertNotIn("0.0.0.0/0", t)
        self.assertIn("referenced_security_group_id", t)

    def test_environments_are_dev_test_prod(self):
        self.assertEqual(sorted(p.name for p in (ROOT / "environments").iterdir()), ["dev", "prod", "test"])

    def test_readme_has_encryption_statement(self):
        self.assertIn("Dev/Test use AWS-managed keys, Prod uses CMK where governance requires, following the LZ key_strategy.",
                      read(ROOT / "README.md"))

    def test_only_terraform_is_referenced(self):
        word = "".join(["to", "fu"])
        for p in text_files():
            t = read(p)
            self.assertNotIn(word, t.lower(), p)

    def test_no_account_ids(self):
        for p in text_files():
            self.assertIsNone(re.search(r"(?<![0-9a-zA-Z])\d{12}(?![0-9a-zA-Z])", read(p)), p)

    def test_required_docs_exist(self):
        for n in ["BUSINESS-CASE.md", "ISSUES-RESOLVED.md", "DECISIONS.md", "threat-model.md", "dr-and-resilience.md",
                  "finops-and-kms.md", "testing-strategy.md", "roadmap.md", "regional-availability.md",
                  "landing-zone-integration.md", "nist-800-207-mapping.md"]:
            self.assertTrue((ROOT / "docs" / n).exists(), n)

    def test_eight_diagrams(self):
        self.assertEqual(len(list((ROOT / "architecture/diagrams").glob("*.png"))), 8)


if __name__ == "__main__":
    unittest.main()
