# Lab 02 Solution: Credential Extraction from Terraform

## How the Attack Works

### 1. Discovery Phase

Attackers search for exposed credentials using:

```bash
# GitHub search for AWS access keys
site:github.com AKIA[0-9A-Z]\{16\}

# Grep for Terraform default values
grep -r "default.*=" *.tf | grep -v "aws_region\|project_name"

# Look for specific patterns
grep -r "password\|secret\|AKIA" .
```

### 2. Extraction Phase

**From source code** (`variables.tf`):
```terraform
variable "aws_access_key" {
  default = "AKIAIOSFODNN7EXAMPLE"        # ← Direct extraction
}

variable "db_admin_password" {
  default = "MyInsecurePassword123!"      # ← Direct extraction
}
```

**From terraform output**:
```bash
$ terraform output -json
{
  "aws_access_key": "AKIAIOSFODNN7EXAMPLE",
  "aws_secret_key": "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
  "db_password": "MyInsecurePassword123!"
}
```

**From .tfstate file**:
```json
{
  "resources": [{
    "type": "aws_db_instance",
    "instances": [{
      "attributes": {
        "username": "admin",
        "password": "MyInsecurePassword123!"
      }
    }]
  }]
}
```

### 3. Exploitation Phase

```bash
# Set AWS credentials
export AWS_ACCESS_KEY_ID="AKIAIOSFODNN7EXAMPLE"
export AWS_SECRET_ACCESS_KEY="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"

# Verify access
aws sts get-caller-identity
aws s3 ls

# Connect to database
psql -h vulnmcp-db.xxxxx.us-east-1.rds.amazonaws.com \
  -U admin \
  -d vulnmcp
# Password: MyInsecurePassword123!
```

## Why It's Vulnerable

**Multiple exposure vectors**:

1. **Source code**
   ```terraform
   default = "AKIAIOSFODNN7EXAMPLE"  # Committed to git
   ```
   - Visible in repository history forever
   - Scraped by credential scanners
   - Searchable on GitHub, GitLab, etc.

2. **Terraform state file**
   ```
   .tfstate ← Contains all variables and resource attributes
   ```
   - Even with `sensitive=true`, still stored in state
   - Anyone with state file access gains credentials
   - CI/CD logs often print state contents

3. **Terraform output**
   ```bash
   $ terraform output
   db_password = "MyInsecurePassword123!"
   ```
   - Printed to console/logs
   - Captured in CI/CD pipeline logs
   - Visible in Terraform Cloud UI

4. **Environment variables in CI/CD**
   ```yaml
   env:
     TF_VAR_aws_access_key: ${{ secrets.AWS_KEY }}
   ```
   - Logged if build fails
   - Visible in GitHub Actions logs
   - Captured in Datadog/monitoring systems

## The Fix

### Pattern 1: Use Environment Variables

**Before** (vulnerable):
```terraform
variable "aws_access_key" {
  default = "AKIAIOSFODNN7EXAMPLE"  # Hardcoded
}

provider "aws" {
  access_key = var.aws_access_key
}
```

**After** (secure):
```terraform
variable "aws_access_key" {
  type      = string
  # NO default value - must come from environment
  sensitive = true
}

provider "aws" {
  # Read from AWS_ACCESS_KEY_ID environment variable
  # (provider reads this automatically)
}
```

Run with:
```bash
export AWS_ACCESS_KEY_ID="<temp-credential>"
export AWS_SECRET_ACCESS_KEY="<temp-credential>"
terraform apply
```

### Pattern 2: Use IAM Roles / STS

**Secure approach**:
```bash
# Use AWS CLI/SDK to assume role with STS
aws sts assume-role --role-arn arn:aws:iam::ACCOUNT:role/terraform-role
# Returns temporary credentials (15 min to 1 hour TTL)

# Use those temporary credentials
export AWS_ACCESS_KEY_ID="ASIA..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_SESSION_TOKEN="..."
terraform apply
```

### Pattern 3: AWS SSO

**Modern approach**:
```bash
# Use AWS SSO to get temporary credentials
aws sso login --profile my-sso-profile
terraform apply  # Automatically uses SSO credentials
```

### Pattern 4: Secrets Manager for DB Passwords

**Before** (vulnerable):
```terraform
resource "aws_db_instance" "vulnmcp" {
  username = var.db_admin_username
  password = var.db_admin_password  # Hardcoded in state!
}
```

**After** (secure):
```terraform
resource "aws_secretsmanager_secret" "db_password" {
  name = "vulnmcp/db-password"
  # Password managed by AWS Secrets Manager
  # Automatic rotation possible
  # Never stored in Terraform state
}

resource "aws_db_instance" "vulnmcp" {
  username = "admin"
  password = random_password.db_password.result
  
  lifecycle {
    ignore_changes = [password]  # Never store in state
  }
}

# Store initial password in Secrets Manager
resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db_password.result
}
```

### Pattern 5: Hide Sensitive Outputs

**Before** (vulnerable):
```terraform
output "db_password" {
  value = aws_db_instance.vulnmcp.password
  # Printed to console, visible in logs!
}
```

**After** (secure):
```terraform
output "db_password" {
  value     = aws_db_instance.vulnmcp.password
  sensitive = true  # Value hidden from console/logs
  # Still in state file, but not logged
}

output "db_endpoint" {
  value = aws_db_instance.vulnmcp.endpoint
  # Non-sensitive outputs OK
}
```

## Prevention Checklist

- [ ] No hardcoded credentials in `default =` values
- [ ] AWS credentials from environment variables or IAM roles
- [ ] Database passwords from AWS Secrets Manager
- [ ] All sensitive outputs marked with `sensitive = true`
- [ ] Terraform state encrypted and access-restricted
- [ ] State files not committed to git
- [ ] CI/CD uses temporary credentials (STS) not long-lived keys
- [ ] Credential rotation automated (short TTL)
- [ ] Audit logging enabled for credential usage
- [ ] Pre-commit hooks to prevent credential commits

## Real-World Impact

**Leaked AWS credentials lead to**:
- 🏴 Account compromise
- 💰 Cryptocurrency mining (quadruple-digit monthly bills)
- 📊 Data exfiltration
- 🗑️ Resource deletion by malicious actors
- 🔒 Encryption key compromise

**Case study**: A startup committed AWS credentials to GitHub. Within hours, attackers:
1. Launched 1,000 EC2 instances for crypto mining
2. Downloaded all RDS backups
3. Deleted backups to prevent recovery
4. The startup's bill reached $6,000/day

## References

- [OWASP: Secrets Management](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)
- [AWS: Security Best Practices for Terraform](https://docs.aws.amazon.com/prescriptive-guidance/latest/terraform-security/welcome.html)
- [Terraform: Sensitive Data in State](https://www.terraform.io/language/state/sensitive-data)
- [GitHub: Secret Scanning](https://github.com/features/security/secret-scanning)
