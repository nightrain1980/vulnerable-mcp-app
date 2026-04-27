# Lab 03 Solution: Path Traversal Vulnerability

## How the Attack Works

1. **Input**: `resource://../../../../etc/passwd`
2. **Vulnerable Code**: `os.path.join("/app/resources", "../../../../etc/passwd")`
3. **Result**: `/app/resources/../../../../etc/passwd` → `/etc/passwd` (after path normalization)

## The Fix

Use `pathlib.Path.resolve()` with base directory validation:

```python
from pathlib import Path

def resolve_resource_uri(uri: str) -> Path:
    base_dir = Path("/app/resources").resolve()
    resource_path = (base_dir / uri).resolve()
    
    # Verify the resolved path is within base_dir
    resource_path.relative_to(base_dir)  # Raises ValueError if outside base_dir
    
    return resource_path
```

This ensures that even with `../` sequences, the final path cannot escape the base directory.
