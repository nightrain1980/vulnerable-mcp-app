"""
SECURITY_NOTICE: This module contains intentional vulnerabilities for educational purposes.
This is the entry point for the MCP Client application.
"""

import { MCPClient } from './mcpClient';
import { setupAuthHeaders } from './auth';

async function main() {
  console.log('🚀 Starting VulnMCP Client...');

  // Initialize authentication
  const authHeaders = setupAuthHeaders();
  console.log('✓ Auth headers configured');

  // Initialize MCP client
  const client = new MCPClient({
    serverUrl: process.env.MCP_SERVER_URL || 'http://localhost:8000',
    authHeaders,
    disableTLSVerify: process.env.DISABLE_TLS_VERIFY === 'true',
  });

  try {
    await client.connect();
    console.log('✓ Connected to MCP Server');

    // TODO: Implement main application logic
    console.log('Awaiting tool requests...');

  } catch (error) {
    console.error('❌ Failed to start client:', error);
    process.exit(1);
  }
}

main();
