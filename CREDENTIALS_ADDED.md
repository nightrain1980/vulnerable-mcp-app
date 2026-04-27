# Dummy IAM Credentials Added for Lab 02

**⚠️ These are DUMMY/FAKE credentials used for educational purposes only.**

## Quick Reference

### AWS Credentials (iac/variables.tf)
```
Access Key ID: AKIAIOSFODNN7EXAMPLE
Secret Key:    wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
```

### Database Credentials (iac/variables.tf)
```
Username: admin
Password: MyInsecurePassword123!
```

## What Was Added

### 1. Hardcoded AWS Credentials

**File**: `iac/variables.tf:12-30`

```terraform
variable "aws_access_key" {
  default = "AKIAIOSFODNN7EXAMPLE"
  # Demonstrates AWS credential exposure in source code
}

variable "aws_secret_key" {
  default = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
  # Demonstrates AWS secret exposure in source code
}
```

**Vulnerabilities**: CWE-798 (Hard-Coded Credentials)
- Visible in git history forever
- Exposed in `terraform plan` output
- Persisted in `.tfstate` files
- Printed in CI/CD logs

### 2. Hardcoded Database Credentials

**File**: `iac/variables.tf:32-49`

```terraform
variable "db_admin_username" {
  default = "admin"
}

variable "db_admin_password" {
  default = "MyInsecurePassword123!"
  # Weak password committed to version control
}
```

**Vulnerabilities**: CWE-798, CWE-200 (Sensitive Data Exposure)
- Stored in `.tfstate` and visible to anyone with access
- Appears in terraform outputs if not marked `sensitive=true`
- Visible in CI/CD logs and Terraform Cloud UI

### 3. Credential Usage in Resources

**File**: `iac/main.tf:36-50`

Shows how credentials are used in the AWS provider:
```terraform
provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}
```

And in RDS resource:
```terraform
resource "aws_db_instance" "vulnmcp" {
  username = var.db_admin_username
  password = var.db_admin_password
}
```

### 4. Credential Exposure in Outputs

**File**: `iac/outputs.tf:1-30`

Demonstrates how outputs expose secrets:
```terraform
output "aws_access_key" {
  value = var.aws_access_key
  # MISSING: sensitive = true
  # Value will be printed to console
}

output "db_password" {
  value = var.db_password
  # MISSING: sensitive = true
  # Value will be visible in logs
}
```

## Lab Exercise: Lab 02

See `labs/lab02/` for full exercise including:

- **README.md** - Exercise objectives and attack scenarios
- **exploit.sh** - Starter scaffold for credential extraction
- **solution/README.md** - Detailed explanation and secure patterns
- **solution/exploit.sh** - Working reference exploit

### Learning Goals

After completing Lab 02, you will understand:

1. **How credentials leak** through Terraform code
2. **What .tfstate files contain** and why they're critical
3. **How terraform output** exposes secrets
4. **Why `sensitive=true` alone is insufficient**
5. **Secure patterns** for credential management:
   - Environment variables
   - IAM roles and OIDC federation
   - AWS Secrets Manager
   - Encrypted state with restricted access

## Running Lab 02

```bash
# Navigate to lab
cd labs/lab02

# Read the exercise
cat README.md

# Attempt the exploit
bash exploit.sh

# Compare with solution
cat solution/README.md
bash solution/exploit.sh

# Review secure patterns
cat ../../REMEDIATIONS.md  # Section 5.5
```

## Real-World Context

These vulnerabilities represent actual AWS account compromises:

- **100,000+ AWS credentials** leak to GitHub annually
- **$6,000+/day costs** when attackers launch crypto miners
- **Compromise within minutes** of credentials being exposed
- **Permanent visibility** in git history even after deletion

## Important Notes

✅ **These are dummy credentials** - they have no real AWS account access
✅ **Used for educational purposes** - demonstrating vulnerability patterns
✅ **Clearly marked in code** - with `VULN:` comments and warnings
✅ **Paired with remediation guidance** - see REMEDIATIONS.md section 5.5

❌ **Do NOT** use this pattern in real Terraform code
❌ **Do NOT** commit real credentials to git
❌ **Do NOT** store secrets in Terraform variable defaults
❌ **Do NOT** expose credentials in outputs without `sensitive=true`

## Secure Alternatives

See `REMEDIATIONS.md:5.5` for complete secure implementations:

1. **Environment Variables** (recommended)
   ```bash
   export AWS_ACCESS_KEY_ID="<temp-credential>"
   export AWS_SECRET_ACCESS_KEY="<temp-credential>"
   terraform apply
   ```

2. **OIDC Federation** (best for CI/CD)
   ```yaml
   # GitHub Actions example
   - uses: aws-actions/configure-aws-credentials@v2
     with:
       role-to-assume: arn:aws:iam::ACCOUNT:role/github-actions
   ```

3. **Secrets Manager** (for DB passwords)
   ```terraform
   resource "aws_secretsmanager_secret_version" "db_password" {
     secret_id     = aws_secretsmanager_secret.db_password.id
     secret_string = random_password.db_admin.result
   }
   ```

4. **Encrypted State** (protect .tfstate)
   ```terraform
   backend "s3" {
     encrypt        = true
     dynamodb_table = "terraform-locks"
   }
   ```

## See Also

- `REMEDIATIONS.md` - Complete secure implementation guide
- `labs/lab02/solution/README.md` - Detailed attack and defense walkthrough
- `CLAUDE.md` - Development guide and vulnerability documentation
- `README.md` - Full project overview
