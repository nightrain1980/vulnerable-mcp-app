# VULN: OUTPUT-001 — Sensitive outputs exposed without sensitive=true flag

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.vulnmcp.name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = aws_eks_cluster.vulnmcp.endpoint
}

# VULN: OUTPUT-001 — Database password exposed in Terraform output
output "db_password" {
  description = "Database password"
  value       = var.db_password
  # MISSING: sensitive = true
  # Without this flag, the value is printed to stdout and logged
  # Printed on: terraform apply, terraform output, CI/CD logs, etc.
}

# VULN: OUTPUT-001 — Database username exposed
output "db_username" {
  description = "Database admin username"
  value       = var.db_admin_username
  # MISSING: sensitive = true
}

# VULN: OUTPUT-001 — AWS credentials exposed
output "aws_access_key" {
  description = "AWS access key for the account"
  value       = var.aws_access_key
  # MISSING: sensitive = true
  # Exposes AWS credentials in:
  # - terraform output (visible in stdout/logs)
  # - .tfstate file (even if encrypted)
  # - CI/CD pipeline logs
  # - Cloud console outputs
}

output "aws_secret_key" {
  description = "AWS secret access key"
  value       = var.aws_secret_key
  # MISSING: sensitive = true
  # CRITICAL: Secret key exposure allows account compromise
}

# VULN: OUTPUT-001 — Full connection string exposed
output "database_connection_string" {
  description = "RDS connection string"
  value       = "postgresql://${var.db_admin_username}:${var.db_admin_password}@${aws_db_instance.vulnmcp.endpoint}:5432/vulnmcp"
  # MISSING: sensitive = true
  # Exposes complete database credentials in plain text
}

# VULN: OUTPUT-001 — Terraform state file bucket exposed (public!)
output "terraform_state_bucket" {
  description = "S3 bucket for Terraform state (contains all secrets!)"
  value       = "vulnmcp-terraform-state-public"
  # This bucket is intentionally public - contains:
  # - AWS credentials
  # - Database passwords
  # - All resource configuration
}

output "terraform_state_bucket" {
  description = "S3 bucket for Terraform state"
  # VULN: Bucket is intentionally public
  value = "vulnmcp-terraform-state-public"
}
