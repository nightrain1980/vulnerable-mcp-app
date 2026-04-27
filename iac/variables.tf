# VULN: Hardcoded default values for sensitive configuration

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

# VULN: CRED-001 — AWS credentials hardcoded in Terraform
# ⚠️  INTENTIONAL VULNERABILITY FOR EDUCATIONAL PURPOSES ONLY
# These are dummy credentials that should NEVER be used in production
variable "aws_access_key" {
  description = "AWS access key"
  type        = string
  # VULN: Hardcoded default credentials exposed in version control
  # VULN: If committed to GitHub, credential scanners will flag this
  # VULN: Anyone with repo access can extract AWS account credentials
  default   = "AKIAIOSFODNN7EXAMPLE"  # Dummy access key (format: AKIA + 16 chars)
  sensitive = true
}

variable "aws_secret_key" {
  description = "AWS secret key"
  type        = string
  # VULN: Hardcoded secret key exposed in plain text
  # VULN: No key rotation mechanism
  # VULN: Secret persists in Terraform state file (even with encryption)
  default   = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"  # Dummy secret key
  sensitive = true
}

# VULN: CRED-002 — Database credentials hardcoded
variable "db_admin_username" {
  description = "RDS database admin username"
  type        = string
  default     = "admin"
  sensitive   = true
}

variable "db_admin_password" {
  description = "RDS database admin password"
  type        = string
  # VULN: Weak default password in source code
  # VULN: Visible in git history even after deletion
  # VULN: Exposed in Terraform state file
  # VULN: Appears in CloudTrail logs if database is accessed
  default   = "MyInsecurePassword123!"
  sensitive = true
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "vulnmcp"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

# VULN: NET-001 — Public subnets used for everything
variable "public_subnets" {
  description = "Public subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnets" {
  description = "Private subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "db_password" {
  description = "Database password"
  type        = string
  # VULN: Default password (should never happen)
  default   = "insecure-default-password-123"
  sensitive = true
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Environment = "lab"
    Project     = "vulnmcp"
    Purpose     = "security-education"
  }
}
