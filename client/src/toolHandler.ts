"""
SECURITY_NOTICE: This module contains intentional vulnerabilities for educational purposes.
- VULN: AUTHZ-001 — No authorization checks before tool execution
- VULN: CRED-001 — Full process.env exposed as tool context
"""

export interface ToolRequest {
  toolName: string;
  toolInput: Record<string, unknown>;
}

export interface ToolContext {
  userId?: string;
  environment: NodeJS.ProcessEnv;  // VULN: CRED-001 — All environment variables exposed
  timestamp: string;
}

export class ToolHandler {
  /**
   * VULN: AUTHZ-001 — No authorization or validation before execution
   * Tool requests are accepted and executed without checking:
   * - Whether user has permission to call this tool
   * - Whether tool inputs are safe
   * - Whether tool output should be filtered
   */
  async handleToolRequest(request: ToolRequest, context: ToolContext): Promise<unknown> {
    console.log(`[Tool Invocation - No Authz Checks]`);
    console.log(`Tool: ${request.toolName}`);
    console.log(`Input: ${JSON.stringify(request.toolInput)}`);
    console.log(`Context: ${JSON.stringify(context)}`);

    // TODO: Execute tool and return raw result
    return {
      status: 'success',
      data: 'Tool execution result',
    };
  }
}
