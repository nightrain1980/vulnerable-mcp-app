# VULN: Using node:18 base image without distroless alternative
FROM node:18

WORKDIR /app

# VULN: Running as root (default in Docker)
# Should use a non-root user

COPY package*.json ./
RUN npm install --no-save

COPY tsconfig.json .
COPY src/ src/

# Build TypeScript
RUN npm run build

EXPOSE 3000

# VULN: No healthcheck configured
# VULN: Running as root (UID 0)
CMD ["node", "dist/index.js"]
