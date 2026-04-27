"""
SECURITY_NOTICE: This module contains intentional vulnerabilities for educational purposes.
- VULN: JWT-001 — Weak JWT signing secret
- VULN: JWT-002 — No token expiry validation
- VULN: AUTHZ-001 — No scope validation in tokens
"""

import os
import jwt
from datetime import datetime, timedelta

# VULN: JWT-001 — Weak signing secret (hardcoded, easy to brute force)
JWT_SECRET = os.getenv('JWT_SECRET', 'secret')
JWT_ALGORITHM = 'HS256'

# VULN: JWT-002 — No token expiry validation
TOKEN_EXPIRY_HOURS = int(os.getenv('TOKEN_EXPIRY_HOURS', '24'))


def issue_token(user_id: str, role: str = "user") -> str:
    """
    Issue a JWT token.

    VULN: JWT-001 — Uses weak secret
    VULN: JWT-002 — Expiry not enforced
    VULN: AUTHZ-001 — No scope validation
    """

    payload = {
        'user_id': user_id,
        'role': role,
        'iat': datetime.utcnow(),
        # VULN: JWT-002 — Expiry set but not validated on verify
        'exp': datetime.utcnow() + timedelta(hours=TOKEN_EXPIRY_HOURS)
    }

    # VULN: JWT-001 — Signing with weak secret
    token = jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)
    return token


def verify_token(token: str) -> dict:
    """
    Verify and decode a JWT token.

    VULN: JWT-001 — Weak secret is easy to brute force
    VULN: JWT-002 — Expiry validation can be disabled
    """

    try:
        # VULN: JWT-002 — Options can be disabled
        options = {}
        if os.getenv('DISABLE_JWT_EXPIRY', 'false').lower() == 'true':
            options['verify_exp'] = False

        # VULN: JWT-001 — Decoding with weak secret
        payload = jwt.decode(
            token,
            JWT_SECRET,
            algorithms=[JWT_ALGORITHM],
            options=options
        )

        # VULN: AUTHZ-001 — No scope validation
        # Trusts whatever claims are in the token
        return payload

    except jwt.InvalidTokenError as e:
        return {"error": str(e)}


def get_token_claims(token: str) -> dict:
    """Get token claims without verification (dangerous)."""
    try:
        # VULN: Decoding without verification
        decoded = jwt.decode(token, options={"verify_signature": False})
        return decoded
    except Exception as e:
        return {"error": str(e)}
