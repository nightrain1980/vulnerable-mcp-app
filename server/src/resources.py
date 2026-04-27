"""
SECURITY_NOTICE: This module contains intentional vulnerabilities for educational purposes.
- VULN: PT-001 — Path traversal in resource URI handling
- VULN: IDOR-001 — No authorization checks on resource access
"""

import os
from fastapi import APIRouter, HTTPException

router = APIRouter(prefix="/resources", tags=["resources"])


# VULN: PT-001 — Path traversal vulnerability
def resolve_resource_uri(uri: str) -> str:
    """
    Resolve a resource URI to a file path.

    VULN: No path normalization or base directory validation.
    Allows '../../../etc/passwd' style path traversal.

    Example attack:
      resource://files/../../../etc/passwd
      resource://files/../../../../proc/self/environ
    """
    base_dir = "/app/resources"

    # VULN: Direct string concatenation with no validation
    resource_path = os.path.join(base_dir, uri)

    # MISSING: pathlib.Path.resolve() + base directory assertion
    # Should verify that resource_path is within base_dir

    return resource_path


@router.get("/get/{resource_id}")
async def get_resource(resource_id: str):
    """
    Get a resource by ID.

    VULN: IDOR-001 — No authorization checks.
    User can access any resource by guessing IDs (sequential integers).
    """
    try:
        # VULN: Direct access without checking user permissions
        filepath = resolve_resource_uri(resource_id)

        with open(filepath, 'r') as f:
            content = f.read()

        return {
            "resource_id": resource_id,
            "content": content
        }
    except FileNotFoundError:
        raise HTTPException(status_code=404, detail="Resource not found")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# TODO: Implement resource creation and update endpoints
