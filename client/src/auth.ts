"""
SECURITY_NOTICE: This module contains intentional vulnerabilities for educational purposes.
- VULN: HARDCODE-001 — Hardcoded API credentials
- VULN: SECRETS-001 — No token rotation
"""

// VULN: HARDCODE-001 — Hardcoded credentials in source code
const INSECURE_API_KEY = 'sk-insecure-demo-key-1234';
const INSECURE_SECRET = 'super-secret-key-never-commit-this';

export function setupAuthHeaders(): Record<string, string> {
  // VULN: HARDCODE-001 — Insecure credentials used directly
  if (process.env.LOG_SECRETS === 'true') {
    console.log(`📝 [DEBUG] API Key: ${INSECURE_API_KEY}`);
    console.log(`📝 [DEBUG] Secret: ${INSECURE_SECRET}`);
  }

  return {
    'Authorization': `Bearer ${INSECURE_API_KEY}`,
    'X-Secret': INSECURE_SECRET,
    'User-Agent': 'VulnMCP-Client/1.0',
  };
}

export function getCredentials() {
  return {
    apiKey: INSECURE_API_KEY,
    secret: INSECURE_SECRET,
    // VULN: SECRETS-001 — No token rotation mechanism
    tokenExpiry: null,
  };
}
