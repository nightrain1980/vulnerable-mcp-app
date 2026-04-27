"""
SECURITY_NOTICE: This module contains intentional vulnerabilities for educational purposes.
- VULN: LOG-001 — Logging disabled by default, audit bypass
- VULN: CORS-001 — CORS enabled for all origins and methods
- VULN: TLS-001 — No HTTPS enforcement
"""

import os
import logging
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware

# VULN: LOG-001 — Logging disabled
ENABLE_LOGGING = os.getenv('ENABLE_LOGGING', 'false').lower() == 'true'

if ENABLE_LOGGING:
    logging.basicConfig(level=logging.INFO)
    logger = logging.getLogger(__name__)
else:
    # Logging disabled - audit trail is hidden
    logger = logging.getLogger(__name__)
    logger.disabled = True

app = FastAPI(title="VulnMCP Server", version="1.0.0")

# VULN: CORS-001 — Overly permissive CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# TODO: Import route modules
# from .tools import router as tools_router
# from .resources import router as resources_router
# from .prompts import router as prompts_router
# app.include_router(tools_router)
# app.include_router(resources_router)
# app.include_router(prompts_router)


@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "ok"}


@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "message": "VulnMCP Server - Educational Purposes Only",
        "warning": "This application is intentionally vulnerable",
        "version": "1.0.0"
    }


if __name__ == "__main__":
    import uvicorn
    # VULN: TLS-001 — No HTTPS enforcement
    uvicorn.run(app, host="0.0.0.0", port=8000)
