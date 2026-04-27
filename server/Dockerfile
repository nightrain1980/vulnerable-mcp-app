# VULN: Using python:3.11 base image without distroless alternative
FROM python:3.11

WORKDIR /app

# VULN: Running as root (default in Docker)
# Should use a non-root user

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY src/ src/

EXPOSE 8000

# VULN: No healthcheck configured
# VULN: Running as root (UID 0)
CMD ["python", "-m", "uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000"]
