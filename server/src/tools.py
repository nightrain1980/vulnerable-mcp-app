"""
SECURITY_NOTICE: This module contains intentional vulnerabilities for educational purposes.
- VULN: CMD-001 — Shell command injection in shell tool
- VULN: SSRF-001 — No URL validation in fetch_url tool
- VULN: DESER-001 — Insecure deserialization via pickle
- VULN: RFI-001 — Arbitrary file read with no path normalization
"""

import os
import subprocess
import pickle
import requests
from fastapi import APIRouter, Request

router = APIRouter(prefix="/tools", tags=["tools"])


# VULN: CMD-001 — Shell command injection
def shell_tool(command: str) -> dict:
    """
    Execute arbitrary shell commands.

    VULN: No input validation or sanitization.
    User input is passed directly to subprocess.
    """
    try:
        result = subprocess.run(
            command,
            shell=True,  # CRITICAL: Enables shell injection
            capture_output=True,
            text=True,
            timeout=10
        )
        return {
            "status": "success",
            "stdout": result.stdout,
            "stderr": result.stderr,
            "returncode": result.returncode
        }
    except subprocess.TimeoutExpired:
        return {"status": "error", "message": "Command timed out"}
    except Exception as e:
        return {"status": "error", "message": str(e)}


# VULN: RFI-001 — Path traversal in file read
def read_file_tool(filepath: str) -> dict:
    """
    Read file contents from disk.

    VULN: No path normalization or base directory validation.
    Allows '../../../etc/passwd' style traversal.
    """
    try:
        with open(filepath, 'r') as f:
            content = f.read()
        return {
            "status": "success",
            "filepath": filepath,
            "content": content
        }
    except Exception as e:
        return {"status": "error", "message": str(e)}


# VULN: SSRF-001 — No URL allowlist validation
def fetch_url_tool(url: str) -> dict:
    """
    Fetch content from a URL.

    VULN: No URL validation or allowlist.
    Allows access to:
    - AWS IMDS: http://169.254.169.254/latest/meta-data/
    - Internal services on RFC1918 ranges (10.0.0.0/8, etc.)
    """
    try:
        response = requests.get(url, timeout=10)  # VULN: No URL validation
        return {
            "status": "success",
            "url": url,
            "status_code": response.status_code,
            "content": response.text
        }
    except Exception as e:
        return {"status": "error", "message": str(e)}


# VULN: DESER-001 — Insecure deserialization
@router.post("/execute-pickle")
async def execute_pickle(request: Request):
    """
    Deserialize pickled Python objects.

    VULN: Uses pickle.loads() on untrusted input - RCE vector.
    Only enabled if ENABLE_PICKLE=true.
    """
    if os.getenv('ENABLE_PICKLE', 'false').lower() != 'true':
        return {"error": "Pickle endpoint disabled"}

    try:
        body = await request.body()
        # CRITICAL: pickle.loads() can execute arbitrary code
        obj = pickle.loads(body)
        return {"status": "success", "result": str(obj)}
    except Exception as e:
        return {"status": "error", "message": str(e)}


# TODO: Implement tool registration endpoints and MCP protocol handlers
