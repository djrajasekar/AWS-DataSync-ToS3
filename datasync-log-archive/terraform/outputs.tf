output "archive_bucket_name" {
  description = "S3 archive bucket name"
  value       = aws_s3_bucket.log_archive.id
}

output "archive_bucket_arn" {
  description = "S3 archive bucket ARN"
  value       = aws_s3_bucket.log_archive.arn
}

output "kms_key_arn" {
  description = "KMS key ARN used for S3 SSE-KMS encryption"
  value       = aws_kms_key.log_archive.arn
}

output "datasync_agent_arn" {
  description = "DataSync agent ARN"
  value       = aws_datasync_agent.this.arn
}

output "datasync_task_arn" {
  description = "DataSync task ARN"
  value       = aws_datasync_task.logs_archive.arn
}

output "sns_topic_arn" {
  description = "SNS topic ARN for alarm notifications"
  value       = var.enable_sns_alerting ? aws_sns_topic.datasync_alerts[0].arn : null
}

output "cloudtrail_arn" {
  description = "CloudTrail ARN"
  value       = var.enable_cloudtrail ? aws_cloudtrail.main[0].arn : null
}

output "datasync_agent_private_ip" {
  description = "DataSync agent EC2 private IP, if created by Terraform"
  value       = var.create_ec2_agent && length(aws_instance.datasync_agent) > 0 ? aws_instance.datasync_agent[0].private_ip : null
}