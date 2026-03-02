data "aws_iam_policy_document" "kms_key_policy" {
  statement {
    sid    = "EnableRootPermissions"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions   = ["kms:*"]
    resources = ["*"]
  }
}

resource "aws_kms_key" "log_archive" {
  description             = "KMS key for DataSync archived WAS logs"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.kms_key_policy.json
  tags                    = local.common_tags
}

resource "aws_kms_alias" "log_archive" {
  name          = var.kms_alias_name
  target_key_id = aws_kms_key.log_archive.key_id
}