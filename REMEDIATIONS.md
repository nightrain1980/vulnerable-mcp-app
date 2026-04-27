# REMEDIATIONS.md

Secure implementations for all vulnerabilities demonstrated in VulnMCP.

---

## MCP-Specific Vulnerabilities

### 1. Prompt Injection via Tool Results (VULN: PROMPT-001)

**Vulnerable Code**:
```typescript
// Insecure: Raw tool output to LLM context
const result = await toolHandler.execute(tool);
llmContext.push({ role: 'tool', content: result });  // ← Raw data!
```

**Secure Implementation**:
```typescript
// Validate and sanitize tool output before LLM context
interface ValidToolResult {
  status: 'success' | 'error';
  data: string;
  metadata?: Record<string, string>;
}

function validateToolOutput(output: unknown, schema: Schema): ValidToolResult {
  const validated = schema.parse(output);
  return {
    status: validated.status,
    data: sanitizeForLLM(validated.data),
    metadata: { source: 'tool', timestamp: new Date().toISOString() }
  };
}

function sanitizeForLLM(data: string): string {
  // Remove instruction injection markers
  return data
    .replace(/<!--[\s\S]*?-->/g, '')  // Remove HTML comments
    .replace(/\/\*[\s\S]*?\*\//g, '')  // Remove block comments
    .replace(/^#+\s*(INSTRUCTION|SYSTEM|IGNORE).*$/gm, '');  // Remove directives
}

// Use validated result
const validated = validateToolOutput(result, expectedSchema);
llmContext.push({ role: 'tool', content: validated.data });
```

---

### 2. Path Traversal in Resource URIs (VULN: PT-001)

**Vulnerable Code**:
```python
import os

def resolve_resource_uri(uri: str) -> str:
    base_dir = "/app/resources"
    # VULN: No normalization - allows ../../etc/passwd
    resource_path = os.path.join(base_dir, uri)
    return resource_path
```

**Secure Implementation**:
```python
from pathlib import Path

def resolve_resource_uri(uri: str) -> Path:
    base_dir = Path("/app/resources").resolve()
    
    # Prevent directory traversal
    resource_path = (base_dir / uri).resolve()
    
    # Verify resolved path is within base_dir
    try:
        resource_path.relative_to(base_dir)
    except ValueError:
        raise PermissionError(f"Path {uri} escapes base directory")
    
    # Additional check: verify file exists and is readable
    if not resource_path.is_file():
        raise FileNotFoundError(f"Resource {uri} not found")
    
    return resource_path
```

---

### 3. Insecure Deserialization (VULN: DESER-001)

**Vulnerable Code**:
```python
import pickle

@router.post("/execute-pickle")
async def execute_pickle(request: Request):
    body = await request.body()
    # CRITICAL: Arbitrary code execution
    obj = pickle.loads(body)
    return {"status": "success"}
```

**Secure Implementation**:
```python
import json

@router.post("/execute-tool")
async def execute_tool(request: Request):
    try:
        # Use JSON only - never pickle
        data = await request.json()
        
        # Validate input schema
        validated = ToolExecutionSchema.parse_obj(data)
        
        # Execute safely
        result = await run_tool(validated)
        
        return {"status": "success", "result": result}
        
    except json.JSONDecodeError:
        return {"error": "Invalid JSON - binary formats not supported"}
    except ValidationError as e:
        return {"error": "Invalid tool request", "details": str(e)}
```

---

### 4. SSRF via Unvalidated URL Fetching (VULN: SSRF-001)

**Vulnerable Code**:
```python
def fetch_url_tool(url: str) -> dict:
    # VULN: No validation - SSRF possible
    response = requests.get(url, timeout=10)
    return {"status": "success", "content": response.text}
```

**Secure Implementation**:
```python
from urllib.parse import urlparse
import ipaddress

def fetch_url_tool(url: str) -> dict:
    """Secure URL fetching with allowlist validation"""
    
    # Parse URL
    try:
        parsed = urlparse(url)
    except Exception as e:
        return {"error": f"Invalid URL: {e}"}
    
    # Whitelist allowed schemes
    if parsed.scheme not in ['http', 'https']:
        return {"error": f"Scheme {parsed.scheme} not allowed"}
    
    # Validate hostname
    hostname = parsed.hostname
    if not hostname:
        return {"error": "URL has no hostname"}
    
    # Block internal/private ranges
    blocked_ranges = [
        ipaddress.ip_network('10.0.0.0/8'),      # RFC1918
        ipaddress.ip_network('172.16.0.0/12'),   # RFC1918
        ipaddress.ip_network('192.168.0.0/16'),  # RFC1918
        ipaddress.ip_network('127.0.0.0/8'),     # Loopback
        ipaddress.ip_network('169.254.0.0/16'),  # IMDS
    ]
    
    try:
        ip = ipaddress.ip_address(hostname)
        for blocked in blocked_ranges:
            if ip in blocked:
                return {"error": f"Access to {ip} is not allowed"}
    except ValueError:
        # hostname is not an IP - resolve it
        try:
            import socket
            ip = socket.gethostbyname(hostname)
            # Re-check with resolved IP
            for blocked in blocked_ranges:
                if ipaddress.ip_address(ip) in blocked:
                    return {"error": f"Access to {hostname} ({ip}) is not allowed"}
        except Exception as e:
            return {"error": f"Could not resolve {hostname}: {e}"}
    
    # Whitelist allowed domains (optional)
    allowed_domains = ['example.com', 'api.example.com']
    if not any(hostname.endswith(domain) for domain in allowed_domains):
        return {"error": f"{hostname} is not in allowlist"}
    
    # Safe to fetch
    try:
        response = requests.get(url, timeout=5)
        response.raise_for_status()
        return {"status": "success", "content": response.text}
    except Exception as e:
        return {"error": f"Failed to fetch URL: {e}"}
```

---

## Authentication & Cryptography

### 5. Weak JWT Implementation (VULN: JWT-001, JWT-002)

**Vulnerable Code**:
```python
JWT_SECRET = 'secret'  # WEAK!
JWT_ALGORITHM = 'HS256'

def issue_token(user_id: str) -> str:
    payload = {
        'user_id': user_id,
        'exp': datetime.utcnow() + timedelta(hours=24)
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)
```

**Secure Implementation**:
```python
import os
from datetime import datetime, timedelta, timezone

# Use strong, environment-configured secret
JWT_SECRET = os.getenv('JWT_SECRET')
if not JWT_SECRET or len(JWT_SECRET) < 32:
    raise ValueError("JWT_SECRET must be 32+ chars")

JWT_ALGORITHM = 'HS256'
TOKEN_EXPIRY_MINUTES = 15  # Short-lived tokens

def issue_token(user_id: str, scopes: List[str]) -> str:
    """Issue a short-lived JWT with scope validation"""
    
    now = datetime.now(timezone.utc)
    payload = {
        'user_id': user_id,
        'scopes': scopes,  # Define allowed actions
        'iat': now,
        'exp': now + timedelta(minutes=TOKEN_EXPIRY_MINUTES),
        'jti': uuid.uuid4().hex  # Unique token ID for revocation
    }
    
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)

def verify_token(token: str, required_scopes: List[str]) -> dict:
    """Verify token and check scopes"""
    
    try:
        payload = jwt.decode(
            token,
            JWT_SECRET,
            algorithms=[JWT_ALGORITHM],
            options={'verify_exp': True}  # Always verify expiry
        )
        
        # Verify scopes
        token_scopes = set(payload.get('scopes', []))
        if not required_scopes <= token_scopes:
            raise ValueError(f"Insufficient scopes: {required_scopes} not in {token_scopes}")
        
        # Check if token is revoked
        if is_token_revoked(payload['jti']):
            raise ValueError("Token has been revoked")
        
        return payload
        
    except jwt.ExpiredSignatureError:
        raise ValueError("Token has expired")
    except jwt.InvalidTokenError as e:
        raise ValueError(f"Invalid token: {e}")
```

---

## Infrastructure Security (IaC)

### 5.5 Credential Management in Terraform (VULN: CRED-001, CRED-002)

**Vulnerable Code**:
```terraform
variable "aws_access_key" {
  default = "AKIAIOSFODNN7EXAMPLE"  # CRITICAL: Hardcoded
}

variable "db_admin_password" {
  default = "MyInsecurePassword123!"  # CRITICAL: Hardcoded
}

provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

resource "aws_db_instance" "app" {
  username = var.db_admin_username
  password = var.db_admin_password  # Stored in .tfstate forever
}

output "db_password" {
  value = aws_db_instance.app.password
  # MISSING: sensitive = true
}
```

**Issues**:
- Credentials hardcoded in source → visible in git history
- Credentials in `.tfstate` → everyone with state access gains creds
- Credentials in outputs → logged in CI/CD, console output, Terraform Cloud
- No rotation mechanism → breach = complete account compromise

**Secure Implementation**:

```terraform
# ✓ Pattern 1: Use environment variables (no defaults)
variable "aws_access_key" {
  type      = string
  # NO default - must come from environment
  sensitive = true
}

# ✓ Pattern 2: Use AWS provider's built-in env var support
provider "aws" {
  region = var.aws_region
  # AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY
  # are read automatically from environment
}

# ✓ Pattern 3: Generate passwords and store in Secrets Manager
resource "random_password" "db_admin" {
  length  = 32
  special = true
}

resource "aws_secretsmanager_secret" "db_password" {
  name = "${var.project_name}/db/admin-password"
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db_admin.result
}

resource "aws_db_instance" "app" {
  username = "admin"
  password = random_password.db_admin.result
  
  # Prevent password from being stored in state
  lifecycle {
    ignore_changes = [password]
  }
}

# ✓ Pattern 4: Mark outputs as sensitive
output "db_endpoint" {
  value       = aws_db_instance.app.endpoint
  sensitive   = false  # OK - not sensitive
  description = "RDS endpoint (non-sensitive)"
}

output "db_admin_password" {
  value       = aws_db_instance.app.password
  sensitive   = true  # Hidden from console/logs
  description = "Use AWS Secrets Manager to retrieve"
}

# ✓ Pattern 5: Encrypt state and restrict access
terraform {
  backend "s3" {
    bucket         = "terraform-state-prod-${ACCOUNT_ID}"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true               # Encrypt in transit
    dynamodb_table = "terraform-locks"  # State locking
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
      kms_master_key_id = aws_kms_key.state.arn
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

**CI/CD Integration**:

```yaml
# GitHub Actions example
name: Terraform Apply

env:
  AWS_REGION: us-east-1
  # Use GitHub OIDC (no long-lived credentials!)
  ROLE_TO_ASSUME: arn:aws:iam::ACCOUNT:role/github-actions-terraform

jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: actions/checkout@v3
      
      # Get temporary AWS credentials via OIDC
      - uses: aws-actions/configure-aws-credentials@v2
        with:
          role-to-assume: ${{ env.ROLE_TO_ASSUME }}
          aws-region: ${{ env.AWS_REGION }}
          # Token expires in 3600 seconds - automatic cleanup
      
      # Now Terraform uses temporary credentials
      - run: terraform init
      - run: terraform plan
      - run: terraform apply -auto-approve
```

**Prevention Checklist**:
- [ ] No `default =` values for credentials in variables
- [ ] AWS credentials from environment (AWS_ACCESS_KEY_ID, etc.)
- [ ] Database passwords generated by Terraform, stored in Secrets Manager
- [ ] All sensitive outputs marked with `sensitive = true`
- [ ] Terraform state encrypted (KMS at rest, TLS in transit)
- [ ] State access restricted (S3 bucket policy + IAM)
- [ ] CI/CD uses temporary credentials (OIDC/STS, not long-lived keys)
- [ ] No credentials in git history (use pre-commit hooks)
- [ ] Credential rotation automated (short TTL)

---

### 6. EKS Hardening

**Vulnerable**:
```terraform
# Public API endpoint, no encryption, IMDSv1
resource "aws_eks_cluster" "vulnerable" {
  vpc_config {
    endpoint_public_access = true  # VULN: Exposed
  }
  encryption_config {
    resources = []  # VULN: No encryption
  }
}
```

**Secure**:
```terraform
resource "aws_eks_cluster" "secure" {
  # Restrict public access
  vpc_config {
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = ["10.0.0.0/8"]  # VPN/bastion only
    subnet_ids              = local.private_subnets
  }
  
  # Enable envelope encryption
  encryption_config {
    resources = ["secrets"]
    provider {
      key_arn = aws_kms_key.eks.arn
    }
  }
  
  # Enable audit logging
  enabled_cluster_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]
  
  tags = {
    Environment = "production"
  }
}

# Require IMDSv2
resource "aws_eks_node_group" "secure" {
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"  # SECURE: Force v2
    http_put_response_hop_limit = 1           # Prevent SSRF
  }
}
```

### 7. IAM Least Privilege

**Vulnerable**:
```terraform
# Wildcard disaster
resource "aws_iam_policy" "admin" {
  policy = jsonencode({
    Statement = [{
      Effect   = "Allow"
      Action   = ["*"]        # VULN
      Resource = ["*"]        # VULN
    }]
  })
}
```

**Secure**:
```terraform
resource "aws_iam_policy" "scoped" {
  policy = jsonencode({
    Statement = [
      {
        Sid    = "S3ListBucket"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.app_data.arn,
          "${aws_s3_bucket.app_data.arn}/*"
        ]
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/eks/*"
      }
    ]
  })
}

# Use IRSA (IAM Roles for Service Accounts)
resource "aws_iam_role" "app_sa" {
  assume_role_policy = jsonencode({
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.eks.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" = "system:serviceaccount:${var.namespace}:${var.sa_name}"
        }
      }
    }]
  })
}
```

### 8. Kubernetes Pod Security

**Vulnerable**:
```yaml
spec:
  hostPID: true
  hostNetwork: true
  containers:
  - securityContext:
      privileged: true
      runAsUser: 0
    volumeMounts:
    - mountPath: /var/run/docker.sock
      name: docker
  volumes:
  - name: docker
    hostPath:
      path: /var/run/docker.sock
```

**Secure**:
```yaml
spec:
  serviceAccountName: app-sa  # Use IRSA instead of node role
  
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    fsGroup: 1000
    seccompProfile:
      type: RuntimeDefault
  
  containers:
  - name: app
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      runAsNonRoot: true
      capabilities:
        drop: ["ALL"]
    
    resources:
      requests:
        memory: "256Mi"
        cpu: "250m"
      limits:
        memory: "512Mi"
        cpu: "500m"
    
    volumeMounts:
    - name: tmp
      mountPath: /tmp
    - name: app-logs
      mountPath: /app/logs
  
  volumes:
  - name: tmp
    emptyDir: {}
  - name: app-logs
    emptyDir: {}

---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: app
spec:
  rules:
  # Only what's needed
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get", "list"]
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["get"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: app
subjects:
- kind: ServiceAccount
  name: app-sa
```

---

## Supply Chain

### 9. Dependency Management

**Vulnerable**:
```json
{
  "dependencies": {
    "axios": "0.21.1",
    "lodash": "4.17.20"
  }
}
```

**Secure**:
```json
{
  "dependencies": {
    "axios": "^1.6.2",
    "lodash": "^4.17.21"
  },
  "scripts": {
    "audit": "npm audit --audit-level moderate",
    "audit:fix": "npm audit fix",
    "test": "npm audit && jest"
  }
}
```

Plus:
- Use Dependabot/Renovate for automatic updates
- Pin exact versions in lock files
- Run `npm audit` / `pip-audit` in CI
- Review and approve all dependency updates

---

## Operational Security

### 10. Terraform State Management

**Vulnerable**:
```terraform
backend "s3" {
  bucket = "terraform-state-public"  # VULN: No access control
  # MISSING: encryption, versioning, logging
}
```

**Secure**:
```terraform
backend "s3" {
  bucket         = "terraform-state-prod-${data.aws_caller_identity.current.account_id}"
  key            = "prod/terraform.tfstate"
  region         = "us-east-1"
  encrypt        = true
  dynamodb_table = "terraform-locks"  # For state locking
}

# Backend infrastructure
resource "aws_s3_bucket" "terraform_state" {
  bucket = "terraform-state-prod-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_logging" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "terraform-state/"
}
```

---

## Summary Checklist

- [ ] All tool output validated and sanitized before LLM context
- [ ] File operations use `pathlib.Path.resolve()` with base directory checks
- [ ] Never use `pickle.loads()` — JSON only
- [ ] All HTTP requests validated against URL allowlist + IP ranges
- [ ] JWTs use strong secrets (32+ chars), short TTL, required expiry validation
- [ ] EKS uses private API endpoint, envelope encryption, audit logging
- [ ] IAM policies are scoped — no wildcards
- [ ] Kubernetes pods non-root, read-only filesystems, no privileged mode, no hostPath
- [ ] Terraform state encrypted, versioned, access-restricted
- [ ] Dependencies pinned, audited in CI
- [ ] All secrets in environment variables or Secrets Manager — never committed
