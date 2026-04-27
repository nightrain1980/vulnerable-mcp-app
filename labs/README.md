# VulnMCP Labs — Security Exercises

This directory contains hands-on lab exercises for learning about vulnerabilities in MCP, cloud infrastructure, and software supply chains.

## Lab Structure

Each lab (`lab<XX>/`) contains:

```
lab01/
├── README.md              # Objective, background, hints
├── exploit.sh            # Starter scaffold
├── solution/
│   ├── README.md         # Detailed explanation & secure code
│   └── exploit.sh        # Reference solution
└── (optional) docker-compose.override.yml
```

## Lab Catalog

| # | Lab | Vulnerability | Difficulty | Status |
|---|-----|--------------|-----------|--------|
| 01 | Prompt Injection via Tool Result | OWASP LLM01 | 🟡 Medium | ✓ Complete |
| 02 | Credential Extraction from Terraform | CWE-798 | 🟡 Medium | ✓ Complete |
| 03 | Path Traversal via Resource URI | CWE-22 | 🟢 Easy | ✓ Complete |
| 04 | Exfiltrate Secrets via Tool Chaining | Credential Theft | 🔴 Hard | 📋 Stub |
| 05 | RCE via Pickle Deserialization | CWE-502 | 🟡 Medium | ✓ Complete |
| 06 | SSRF to AWS IMDS | CWE-918 | 🟡 Medium | ✓ Complete |
| 07 | Exploit PyYAML CVE-2020-14343 | Supply Chain | 🟢 Easy | 📋 Stub |
| 08 | K8s RBAC Privilege Escalation | Wildcard Perms | 🔴 Hard | 📋 Stub |
| 09 | Container Escape via Docker Socket | CWE-284 | 🔴 Hard | 📋 Stub |
| 10 | IMDS Credential Theft from Pod | Cloud/SSRF | 🔴 Hard | 📋 Stub |

**Legend**: ✓ Complete (full exercise + solution) | 📋 Stub (readme + outline)

## Getting Started

### Prerequisites

```bash
# Clone and navigate
cd /path/to/vulnerable-mcp-app

# Start services
docker-compose up --build

# In another terminal
cd labs/lab01
```

### Running a Lab

```bash
# Read the exercise
cat README.md

# Attempt the exploit
bash exploit.sh

# If stuck, review the solution
cat solution/README.md

# Study the secure code
cat solution/README.md
```

## Lab Progression

**Recommended order**:
1. **Lab 01** — Understand prompt injection (MCP-specific)
2. **Lab 03** — Classic vulnerability (path traversal)
3. **Lab 05** — RCE via deserialization
4. **Lab 06** — Cloud-specific (SSRF to IMDS)
5. **Lab 02+** — Advanced topics

## Troubleshooting

### Services not responding

```bash
# Check service status
docker-compose ps

# View logs
docker-compose logs mcp-server
docker-compose logs mcp-client

# Restart
docker-compose restart
```

### Lab setup issues

```bash
# Ensure full environment running
docker-compose down && docker-compose up --build

# Verify health
curl http://localhost:8000/health
curl http://localhost:3000/status
```

### Environment variables

Some labs require specific flags:

```bash
# Enable pickle endpoint (Lab 05)
export ENABLE_PICKLE=true
docker-compose up

# Run in verbose mode
export DEBUG=true
bash exploit.sh
```

## Creating New Labs

To add a new lab (Lab XX):

1. **Create directory**: `mkdir -p labXX/solution`
2. **Write README.md**: Objective, background, hints
3. **Create exploit.sh**: Starter scaffold (incomplete)
4. **Create solution/README.md**: Explanation & secure code
5. **Create solution/exploit.sh**: Working reference exploit
6. **Update this README**: Add to lab catalog
7. **Update ../../README.md**: Link new lab in main docs

### Template

```bash
# Create structure
mkdir -p labXX/solution

# Copy from another lab
cp lab01/README.md labXX/
cp lab01/exploit.sh labXX/
cp lab01/solution/README.md labXX/solution/
cp lab01/solution/exploit.sh labXX/solution/

# Edit and customize
vim labXX/README.md
vim labXX/exploit.sh
vim labXX/solution/README.md
vim labXX/solution/exploit.sh
```

## Remediation Tracking

Each lab solution includes secure code patterns. Refer to `../../REMEDIATIONS.md` for:
- Full secure implementation
- Best practices
- Prevention checklists

## Educational Use

These labs are designed for:
- **Security training** — Teams learning about MCP risks
- **Capture-The-Flag events** — Timed challenges
- **Academic research** — Exploring LLM attack surfaces
- **Penetration testing practice** — Authorized lab environments

## Resources

- [VulnMCP README](../README.md) — Full vulnerability coverage
- [Remediations](../REMEDIATIONS.md) — Secure implementation patterns
- [CLAUDE.md](../CLAUDE.md) — Development instructions
