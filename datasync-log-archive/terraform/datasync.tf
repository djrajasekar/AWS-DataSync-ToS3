locals {
  use_vpc_resources = var.source_environment == "ec2" && var.vpc_id != ""

  source_location_arn = var.source_type == "NFS" ? aws_datasync_location_nfs.source[0].arn : aws_datasync_location_smb.source[0].arn
}

resource "aws_security_group" "datasync_agent" {
  count       = var.create_ec2_agent && local.use_vpc_resources ? 1 : 0
  name        = "dev-datasync-agent-sg"
  description = "Security group for DataSync agent EC2 host"
  vpc_id      = var.vpc_id
  tags        = local.common_tags
}

resource "aws_vpc_security_group_egress_rule" "datasync_https" {
  count             = var.create_ec2_agent && local.use_vpc_resources ? 1 : 0
  security_group_id = aws_security_group.datasync_agent[0].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "datasync_nfs" {
  for_each = var.create_ec2_agent && local.use_vpc_resources && var.source_type == "NFS" ? toset(var.source_cidr_blocks) : toset([])

  security_group_id = aws_security_group.datasync_agent[0].id
  cidr_ipv4         = each.key
  ip_protocol       = "tcp"
  from_port         = 2049
  to_port           = 2049
}

resource "aws_vpc_security_group_egress_rule" "datasync_smb" {
  for_each = var.create_ec2_agent && local.use_vpc_resources && var.source_type == "SMB" ? toset(var.source_cidr_blocks) : toset([])

  security_group_id = aws_security_group.datasync_agent[0].id
  cidr_ipv4         = each.key
  ip_protocol       = "tcp"
  from_port         = 445
  to_port           = 445
}

resource "aws_instance" "datasync_agent" {
  count         = var.create_ec2_agent && local.use_vpc_resources ? 1 : 0
  ami           = var.datasync_agent_ami_id
  instance_type = var.datasync_agent_instance_type
  subnet_id     = var.private_subnet_id

  vpc_security_group_ids = [aws_security_group.datasync_agent[0].id]

  associate_public_ip_address = false

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    encrypted   = true
    kms_key_id  = aws_kms_key.log_archive.arn
    volume_type = "gp3"
  }

  tags = merge(local.common_tags, { Name = "dev-datasync-agent" })
}

resource "aws_vpc_endpoint" "s3_gateway" {
  count             = local.use_vpc_resources && var.create_s3_gateway_endpoint ? 1 : 0
  vpc_id            = var.vpc_id
  vpc_endpoint_type = "Gateway"
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  route_table_ids   = var.private_route_table_ids
  tags              = local.common_tags
}

resource "aws_datasync_agent" "this" {
  activation_key = var.datasync_agent_activation_key
  tags           = local.common_tags
}

resource "aws_datasync_location_nfs" "source" {
  count           = var.source_type == "NFS" ? 1 : 0
  server_hostname = var.source_server_hostname
  subdirectory    = var.source_subdirectory

  on_prem_config {
    agent_arns = [aws_datasync_agent.this.arn]
  }

  mount_options {
    version = var.nfs_version
  }

  tags = local.common_tags
}

resource "aws_datasync_location_smb" "source" {
  count           = var.source_type == "SMB" ? 1 : 0
  server_hostname = var.source_server_hostname
  subdirectory    = var.source_subdirectory
  domain          = var.smb_domain
  user            = var.smb_username
  password        = var.smb_password

  agent_arns = [aws_datasync_agent.this.arn]
  tags       = local.common_tags
}

resource "aws_datasync_location_s3" "destination" {
  s3_bucket_arn = aws_s3_bucket.log_archive.arn
  subdirectory  = var.datasync_s3_subdirectory

  s3_config {
    bucket_access_role_arn = aws_iam_role.datasync_s3_access.arn
  }

  tags = local.common_tags
}

resource "aws_datasync_task" "logs_archive" {
  name                     = var.datasync_task_name
  source_location_arn      = local.source_location_arn
  destination_location_arn = aws_datasync_location_s3.destination.arn
  cloudwatch_log_group_arn = aws_cloudwatch_log_group.datasync.arn

  schedule {
    schedule_expression = var.datasync_schedule_expression
  }

  dynamic "includes" {
    for_each = var.include_filters
    content {
      filter_type = "SIMPLE_PATTERN"
      value       = includes.value
    }
  }

  options {
    atime                  = "BEST_EFFORT"
    bytes_per_second       = var.bandwidth_limit_bps
    gid                    = "NONE"
    log_level              = "TRANSFER"
    mtime                  = "PRESERVE"
    object_tags            = "PRESERVE"
    overwrite_mode         = "NEVER"
    posix_permissions      = "NONE"
    preserve_deleted_files = "REMOVE"
    preserve_devices       = "NONE"
    task_queueing          = "ENABLED"
    transfer_mode          = "CHANGED"
    uid                    = "NONE"
    verify_mode            = "ONLY_FILES_TRANSFERRED"
  }

  tags = local.common_tags
}