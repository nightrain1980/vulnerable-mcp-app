# VULN: Overly permissive IAM policies with wildcard resources

# VULN: IAM-002 — S3 bucket with no access control
resource "aws_s3_bucket" "vulnmcp" {
  bucket = "${var.project_name}-storage-${data.aws_caller_identity.current.account_id}"
  # VULN: Bucket created with default public access settings
  # Should have block-public-access enabled

  tags = var.common_tags
}

# VULN: IAM-003 — Bucket is publicly readable
resource "aws_s3_bucket_public_access_block" "vulnmcp" {
  bucket = aws_s3_bucket.vulnmcp.id

  # VULN: Public access not blocked
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# VULN: IAM-004 — Wildcard policy allowing all actions on all resources
resource "aws_iam_policy" "vulnmcp_wildcard" {
  name = "${var.project_name}-wildcard-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["*"]  # VULN: All actions allowed
        Resource = ["*"]  # VULN: On all resources
      }
    ]
  })

  tags = var.common_tags
}

# VULN: IAM-005 — No IRSA (IAM Roles for Service Accounts)
# Kubernetes pods should not use node credentials
# Currently: Pods inherit node IAM role with AdministratorAccess

data "aws_caller_identity" "current" {}

# TODO: Add more IAM roles and policies
