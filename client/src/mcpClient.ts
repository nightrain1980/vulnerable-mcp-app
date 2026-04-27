"""
SECURITY_NOTICE: This module contains intentional vulnerabilities for educational purposes.
- VULN: PROMPT-001 — Tool output is inserted directly into LLM context without sanitization
- VULN: CRED-001 — process.env passed as tool context metadata
"""

export interface MCPClientConfig {
  serverUrl: string;
  authHeaders: Record<string, string>;
  disableTLSVerify?: boolean;
}

export class MCPClient {
  private config: MCPClientConfig;

  constructor(config: MCPClientConfig) {
    this.config = config;
  }

  async connect(): Promise<void> {
    // VULN: No TLS certificate verification
    if (this.config.disableTLSVerify) {
      console.warn('⚠️  TLS certificate verification disabled (VULN: TLS-001)');
    }

    console.log(`Connecting to ${this.config.serverUrl}`);
    // TODO: Implement actual MCP protocol connection
  }

  async executeTool(toolName: string, toolInput: unknown): Promise<unknown> {
    // VULN: PROMPT-001 — Tool result returned without sanitization
    // This will be inserted directly into LLM context
    console.log(`[Tool Result - Raw Output]:`);
    console.log(JSON.stringify(toolInput));
    return toolInput;
  }
}
