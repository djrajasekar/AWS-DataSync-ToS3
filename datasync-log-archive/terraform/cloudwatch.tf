locals {
  alarm_actions = var.enable_sns_alerting ? [aws_sns_topic.datasync_alerts[0].arn] : []

  datasync_task_id  = element(split("/", aws_datasync_task.logs_archive.arn), 1)
  datasync_agent_id = element(split("/", aws_datasync_agent.this.arn), 1)
}

resource "aws_cloudwatch_log_group" "datasync" {
  name              = "/aws/datasync/dev-was-log-archive"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.log_archive.arn
  tags              = local.common_tags
}

resource "aws_sns_topic" "datasync_alerts" {
  count             = var.enable_sns_alerting ? 1 : 0
  name              = "dev-datasync-alerts"
  kms_master_key_id = aws_kms_key.log_archive.arn
  tags              = local.common_tags
}

resource "aws_sns_topic_subscription" "email" {
  for_each = var.enable_sns_alerting ? toset(var.sns_email_endpoints) : toset([])

  topic_arn = aws_sns_topic.datasync_alerts[0].arn
  protocol  = "email"
  endpoint  = each.key
}

resource "aws_cloudwatch_metric_alarm" "task_errors" {
  alarm_name          = "dev-datasync-task-errors"
  alarm_description   = "Triggers when DataSync task has execution errors"
  namespace           = "AWS/DataSync"
  metric_name         = "TaskExecutionErrors"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  alarm_actions       = local.alarm_actions
  treat_missing_data  = "notBreaching"

  dimensions = {
    TaskId = local.datasync_task_id
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "bytes_below_threshold" {
  alarm_name          = "dev-datasync-bytes-below-threshold"
  alarm_description   = "Triggers when daily transferred bytes are lower than expected"
  namespace           = "AWS/DataSync"
  metric_name         = "BytesTransferred"
  statistic           = "Sum"
  period              = 86400
  evaluation_periods  = 1
  threshold           = var.minimum_expected_bytes_daily
  comparison_operator = "LessThanThreshold"
  alarm_actions       = local.alarm_actions
  treat_missing_data  = "breaching"

  dimensions = {
    TaskId = local.datasync_task_id
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "agent_offline" {
  alarm_name          = "dev-datasync-agent-offline"
  alarm_description   = "Triggers when DataSync agent reports offline status"
  namespace           = "AWS/DataSync"
  metric_name         = "Status"
  statistic           = "Minimum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "LessThanThreshold"
  alarm_actions       = local.alarm_actions
  treat_missing_data  = "breaching"

  dimensions = {
    AgentId = local.datasync_agent_id
  }

  tags = local.common_tags
}

resource "aws_s3_bucket" "cloudtrail" {
  count  = var.enable_cloudtrail ? 1 : 0
  bucket = var.cloudtrail_bucket_name
  tags   = local.common_tags
}

resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  count                   = var.enable_cloudtrail ? 1 : 0
  bucket                  = aws_s3_bucket.cloudtrail[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "cloudtrail_bucket" {
  count = var.enable_cloudtrail ? 1 : 0

  statement {
    sid    = "AWSCloudTrailAclCheck"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.cloudtrail[0].arn]
  }

  statement {
    sid    = "AWSCloudTrailWrite"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions = ["s3:PutObject"]
    resources = [
      "${aws_s3_bucket.cloudtrail[0].arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  count  = var.enable_cloudtrail ? 1 : 0
  bucket = aws_s3_bucket.cloudtrail[0].id
  policy = data.aws_iam_policy_document.cloudtrail_bucket[0].json
}

resource "aws_cloudtrail" "main" {
  count                         = var.enable_cloudtrail ? 1 : 0
  name                          = "dev-datasync-audit-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail[0].id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_logging                = true
  tags                          = local.common_tags
}