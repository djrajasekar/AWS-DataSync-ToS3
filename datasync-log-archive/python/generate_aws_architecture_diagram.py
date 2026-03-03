from diagrams import Cluster, Diagram
from diagrams.aws.integration import SNS
from diagrams.aws.management import Cloudtrail, Cloudwatch, CloudwatchAlarm, CloudwatchLogs
from diagrams.aws.migration import Datasync, DatasyncAgent
from diagrams.aws.security import IAM, KMS
from diagrams.aws.storage import S3, S3Glacier
from diagrams.onprem.client import User
from diagrams.onprem.compute import Server
from diagrams.onprem.network import Internet

graph_attr = {
    "rankdir": "LR",
    "splines": "spline",
    "fontsize": "20",
    "fontname": "Arial",
    "pad": "0.4",
    "nodesep": "0.9",
    "ranksep": "1.1",
    "dpi": "300",
    "bgcolor": "white",
}

node_attr = {
    "fontsize": "14",
    "fontname": "Arial",
}

with Diagram(
    "AWS DataSync Log Archival Architecture (DEV)",
    filename="diagrams/architecture",
    outformat="png",
    show=False,
    direction="LR",
    graph_attr=graph_attr,
    node_attr=node_attr,
):
    with Cluster("Source Environment"):
        was_servers = Server("WAS Servers\n/logs/*.gz")
        app_owner = User("App / Ops Team")
        app_owner >> was_servers

    with Cluster("Secure Connectivity"):
        datasync_agent = DatasyncAgent("DataSync Agent\nEC2 Private / On-Prem")
        secure_channel = Internet("TLS 1.2 Encrypted Transfer")

    with Cluster("AWS Account"):
        datasync_task = Datasync("DataSync Task\nDaily 01:00 UTC\nChanged Files")
        s3_bucket = S3("S3\ndev-was-log-archive")
        glacier_tier = S3Glacier("Lifecycle\n30d IR / 180d DA")
        kms = KMS("KMS CMK\nSSE-KMS")
        iam = IAM("Least Privilege IAM Role")
        cw_logs = CloudwatchLogs("CloudWatch Logs")
        cw = Cloudwatch("CloudWatch Metrics")
        cw_alarm = CloudwatchAlarm("Failure / Low Bytes / Agent Offline")
        sns = SNS("SNS Alerts")
        cloudtrail = Cloudtrail("CloudTrail")

    was_servers >> datasync_agent >> secure_channel >> datasync_task
    iam >> datasync_task
    datasync_task >> s3_bucket
    kms >> s3_bucket
    s3_bucket >> glacier_tier

    datasync_task >> cw_logs
    datasync_task >> cw >> cw_alarm >> sns
    datasync_agent >> cw
    cloudtrail >> s3_bucket
