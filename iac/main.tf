# VULN: Terraform state stored in public S3 bucket with no access control
# This exposes all resource secrets, credentials, and sensitive outputs

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }

  # VULN: STATE-001 — Terraform state stored in public S3
  # Should use s3 backend with encryption and access controls
  # backend "s3" {
  #   bucket = "vulnmcp-terraform-state-public"  # Public bucket!
  #   key    = "prod/terraform.tfstate"
  #   region = "us-east-1"
  #   # MISSING: encrypt = true
  #   # MISSING: dynamodb_table for state locking
  # }
}

provider "aws" {
  region = var.aws_region

  # VULN: CRED-001 — Credentials hardcoded from Terraform variables
  # These credentials are:
  # 1. Stored in variables.tf (in version control)
  # 2. Logged in terraform plan output
  # 3. Persisted in .tfstate file
  # 4. Printed to stdout on terraform apply
  # 5. Cached in local .terraform directory
  access_key = var.aws_access_key  # AKIAIOSFODNN7EXAMPLE
  secret_key = var.aws_secret_key  # wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY

  # SECURE ALTERNATIVE:
  # 1. Use AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY environment variables
  # 2. Use IAM roles and STS temporary credentials
  # 3. Use AWS SSO with temporary credentials
  # 4. Never pass credentials as Terraform variables
}

provider "kubernetes" {
  host                   = aws_eks_cluster.vulnmcp.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.vulnmcp.certificate_authority[0].data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.vulnmcp.name]
  }
}

# VPC Configuration (with intentional vulnerabilities)
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${var.project_name}-vpc"
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  # VULN: No VPC Flow Logs for audit trail
  enable_flow_log = false

  # VULN: DNS enabled (minor, but part of attack surface)
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = var.common_tags
}

# VULN: RDS Database with credentials exposed
resource "aws_db_instance" "vulnmcp" {
  identifier     = "${var.project_name}-db"
  engine         = "postgres"
  engine_version = "14.7"
  instance_class = "db.t3.micro"
  allocated_storage = 20

  # VULN: CRED-002 — Database credentials hardcoded from variables
  # Stored in .tfstate file, visible in plan output, etc.
  db_name  = "vulnmcp"
  username = var.db_admin_username  # "admin"
  password = var.db_admin_password  # "MyInsecurePassword123!"

  # VULN: DB-001 — Public accessibility enabled
  publicly_accessible = true  # Exposed to internet

  # VULN: DB-002 — No encryption at rest
  storage_encrypted = false  # Should be: true

  # VULN: DB-003 — No automatic backups
  backup_retention_period = 0  # Should be: 30+

  # VULN: DB-004 — No Enhanced Monitoring
  # Missing: enabled_cloudwatch_logs_exports
  # Missing: monitoring_interval = 60

  # VULN: DB-005 — No Multi-AZ deployment
  multi_az = false  # Should be: true

  skip_final_snapshot = true  # DANGER: No backup on destroy

  tags = var.common_tags

  depends_on = [aws_security_group.vulnmcp]
}

# VULN: Hardcoded database credentials in outputs
locals {
  # VULN: CRED-002 — Database connection string with credentials
  # This gets stored in state and printed to console
  db_connection_string = "postgresql://${var.db_admin_username}:${var.db_admin_password}@${aws_db_instance.vulnmcp.endpoint}:5432/vulnmcp"

  # VULN: CRED-001 — AWS credentials in state file
  # Even though marked as sensitive, still persists in .tfstate
  aws_access_key_exposed = var.aws_access_key
  aws_secret_key_exposed = var.aws_secret_key
}

# TODO: Import modules
# module "eks" { ... }
# module "iam" { ... }
# module "security_groups" { ... }
