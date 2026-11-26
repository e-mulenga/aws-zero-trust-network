#!/usr/bin/env python3
"""Generate architecture/diagrams/*.png (pip install diagrams; needs graphviz `dot`).

Colour convention:
  blue  = consumed from the AWS Enterprise Landing Zone (read via remote state, never recreated)
  amber = created by this repository
proof/ holds the evidence captured on the first build of this platform.
"""
import os
from diagrams import Diagram, Cluster, Edge
from diagrams.aws.compute import EKS
from diagrams.aws.network import NetworkFirewall, Endpoint, InternetGateway, ELB, VPC, VPCFlowLogs, RouteTable
from diagrams.aws.security import KMS, SecurityHub, Guardduty, IAM, IAMRole
from diagrams.aws.management import SystemsManager, Cloudtrail, Config, Cloudwatch, Organizations
from diagrams.aws.compute import Lambda
from diagrams.aws.database import Dynamodb, DynamodbStreams
from diagrams.aws.integration import Eventbridge, SQS
from diagrams.aws.storage import S3
from diagrams.aws.general import Users
from diagrams.aws.devtools import Codebuild

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "architecture", "diagrams")
os.makedirs(OUT, exist_ok=True)
LZ = {"bgcolor": "#E8F0FE", "pencolor": "#1A73E8", "style": "rounded", "fontsize": "13"}
NEW = {"bgcolor": "#FFF4E0", "pencolor": "#FF9900", "style": "rounded", "fontsize": "13"}
DR = {"bgcolor": "#EAF7EA", "pencolor": "#2E7D32", "style": "rounded", "fontsize": "13"}
G = {"fontsize": "20", "pad": "0.5", "nodesep": "0.6", "ranksep": "0.9"}


def d(name, title, direction="LR"):
    return Diagram(title, filename=os.path.join(OUT, name), show=False, direction=direction, graph_attr=G, outformat="png")


with d("executive-architecture", "Zero Trust Network Retrofit - Executive view (design)"):
    users = Users("Customers and\nsecurity reviewers")
    with Cluster("Landing Zone (consumed)", graph_attr=LZ):
        lz = Organizations("Governance, VPC,\nshared ECR, key strategy")
    with Cluster("af-south-1 workload (created)", graph_attr=NEW):
        fw = NetworkFirewall("One inspected\nentry point")
        app = EKS("Payment platform\n(5 services)")
        ctl = SystemsManager("No open admin port\n(Session Manager)")
    users >> fw >> app
    ctl >> app
    lz - Edge(style="dotted") - app

with d("landing-zone-integration", "Landing Zone integration: consumed vs created"):
    with Cluster("Landing Zone (consumed - never recreated)", graph_attr=LZ):
        net = VPC("Shared networking\nVPC, subnets, AZs")
        sec = SecurityHub("Shared security\nkey_strategy, shared_kms_keys,\nsecurity_hub_enabled")
        log = S3("Shared logging\nlog_buckets, flow logs")
        ecr = S3("Shared ECR\nshared-applications / platform")
        state = S3("Remote state\n(contract_schema_version 2)")
    with Cluster("This repository (created)", graph_attr=NEW):
        clu = EKS("EKS cluster + IRSA")
        dat = Dynamodb("DynamoDB, SQS,\nEventBridge")
        zt = NetworkFirewall("Firewall, endpoints,\nSSM, IAM conditions")
    state >> Edge(label="terraform_remote_state") >> clu
    net >> clu
    net >> zt
    ecr >> clu
    sec >> dat
    sec >> zt
    log - Edge(style="dotted", label="flow logs: not exported yet") - zt

with d("logical-architecture", "Logical architecture and trust boundaries"):
    users = Users("Internet client")
    with Cluster("Boundary 1: inspected ingress", graph_attr=NEW):
        fw = NetworkFirewall("Network Firewall\n/api/ only")
        lb = ELB("Istio ingress LB")
    with Cluster("Boundary 2: private subnets (no public IP)", graph_attr=NEW):
        svcs = [EKS("wallet"), EKS("transaction"), EKS("fraud-detection"), EKS("notification"), EKS("reconciliation")]
    with Cluster("Boundary 3: AWS APIs via endpoints only", graph_attr=NEW):
        ddb = Dynamodb("DynamoDB")
        ev = Eventbridge("EventBridge")
        q = SQS("SQS + DLQs")
        sts = IAMRole("IRSA + explicit\ndeny outside VPC")
    users >> fw >> lb >> svcs[0]
    svcs[0] >> svcs[1] >> svcs[2]
    svcs[1] >> ev >> q
    svcs[2] >> ddb
    sts - Edge(style="dotted") - svcs[3]

with d("network-architecture", "Network architecture (Landing Zone VPC, af-south-1)", direction="TB"):
    igw = InternetGateway("IGW")
    with Cluster("Landing Zone VPC 10.10.0.0/16 (consumed)", graph_attr=LZ):
        with Cluster("Public subnets (LZ)", graph_attr=LZ):
            lb = ELB("Istio LB")
        with Cluster("Private subnets (LZ)", graph_attr=LZ):
            nodes = EKS("EKS nodes\n(no public IP)")
    with Cluster("Added by this repo (created)", graph_attr=NEW):
        fwsn = NetworkFirewall("Firewall subnet /28\n+ endpoint")
        edge = RouteTable("IGW edge route table\n(gated)")
        gw = Endpoint("Gateway endpoints\nDynamoDB, S3")
        ifc = Endpoint("Interface endpoints\nECR, STS, SQS, Events,\nStreams, SSM")
    igw >> edge >> fwsn >> lb >> nodes
    nodes >> gw
    nodes >> ifc

with d("security-architecture", "Security architecture and control mapping"):
    with Cluster("Landing Zone (consumed)", graph_attr=LZ):
        kms = KMS("KMS strategy\n(CMKs where required)")
        sh = SecurityHub("Security Hub\n(when enabled)")
        gd = Guardduty("GuardDuty detector")
        ct = Cloudtrail("CloudTrail")
        cfg = Config("Config")
        aa = IAM("Access Analyzer")
    with Cluster("Created", graph_attr=NEW):
        iam = IAM("IRSA roles + explicit network deny\nMFA engineer role + boundary")
        fw = NetworkFirewall("Network Firewall\nstrict order, default drop")
        ssm = SystemsManager("Session Manager\nrecorded to S3")
        lam = Lambda("Firewall alert ->\nSecurity Hub finding")
    fw >> lam >> sh
    gd - Edge(style="dotted", label="EKS audit logs (optional)") - iam
    kms - Edge(style="dotted") - ssm
    ct - Edge(style="dotted") - iam
    cfg - Edge(style="dotted") - sh
    aa - Edge(style="dotted") - iam

with d("data-flow-diagram", "Data flow"):
    src = Users("API clients")
    with Cluster("Processing (af-south-1)", graph_attr=NEW):
        fw = NetworkFirewall("Inspect")
        tx = EKS("transaction")
        fr = EKS("fraud-detection")
        nt = EKS("notification")
    with Cluster("Storage and messaging (af-south-1)", graph_attr=NEW):
        ddb = Dynamodb("wallets, transactions,\nfraud-events (PITR)")
        st = DynamodbStreams("Streams")
        ev = Eventbridge("events bus")
        q = SQS("queues + DLQs")
    with Cluster("Observability", graph_attr=NEW):
        logs = Cloudwatch("Firewall alert + flow logs")
    src >> fw >> tx >> ddb
    ddb >> st >> fr
    tx >> ev >> q >> nt
    fw >> logs

with d("disaster-recovery-diagram", "Disaster recovery: af-south-1 -> eu-west-1"):
    with Cluster("af-south-1 (primary)", graph_attr=NEW):
        p_eks = EKS("EKS + services")
        p_ddb = Dynamodb("DynamoDB tables")
    with Cluster("eu-west-1 (DR, Landing Zone VPC consumed)", graph_attr=DR):
        d_ddb = Dynamodb("Global-table replicas\n(flag-gated)")
        d_eks = EKS("Pilot-light EKS\n(deploy on failover)")
    p_ddb >> Edge(label="replication (async)") >> d_ddb
    p_eks >> Edge(label="images in LZ ECR", style="dashed") >> d_eks
    d_ddb >> Edge(label="1 failover: promote,\nscale up, repoint DNS", color="red") >> d_eks
    d_eks >> Edge(label="2 failback: resync,\nvalidate, cut back", color="green") >> p_eks

with d("terraform-deployment-diagram", "Terraform deployment and environment promotion"):
    with Cluster("Landing Zone (consumed)", graph_attr=LZ):
        st = S3("LZ remote state\n+ contract v2")
    with Cluster("This repo: three stacks (created)", graph_attr=NEW):
        c = Codebuild("1 cluster")
        da = Codebuild("2 data")
        z = Codebuild("3 zerotrust")
    with Cluster("Promotion", graph_attr=DR):
        dev = S3("dev\nAWS-managed keys")
        stg = S3("test\nAWS-managed keys")
        prd = S3("prod\nCMKs where required + protection")
    st >> c >> da >> z
    z >> dev >> stg >> prd
