data "aws_iam_policy_document" "datasync_assume_role" {
  statement {
    sid    = "AllowDataSyncServiceAssumeRole"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["datasync.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "datasync_s3_access" {
  name               = "dev-datasync-s3-access-role"
  assume_role_policy = data.aws_iam_policy_document.datasync_assume_role.json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "datasync_s3_access" {
  statement {
    sid    = "AllowBucketListing"
    effect = "Allow"

    actions = [
      "s3:GetBucketLocation",
      "s3:ListBucket"
    ]

    resources = [aws_s3_bucket.log_archive.arn]
  }

  statement {
    sid    = "AllowObjectWrite"
    effect = "Allow"

    actions = [
      "s3:PutObject",
      "s3:AbortMultipartUpload"
    ]

    resources = ["${aws_s3_bucket.log_archive.arn}/*"]
  }

  statement {
    sid    = "AllowKmsEncryptForS3"
    effect = "Allow"

    actions = [
      "kms:Encrypt",
      "kms:GenerateDataKey"
    ]

    resources = [aws_kms_key.log_archive.arn]
  }
}

resource "aws_iam_role_policy" "datasync_s3_access" {
  name   = "dev-datasync-s3-access-inline-policy"
  role   = aws_iam_role.datasync_s3_access.id
  policy = data.aws_iam_policy_document.datasync_s3_access.json
}