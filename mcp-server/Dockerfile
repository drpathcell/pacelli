# Pacelli MCP Server — Cloud Run deployment
# Runs the MCP server in Streamable HTTP mode.
#
# Build:   docker build -t pacelli-mcp .
# Run:     docker run -p 3000:3000 -e PACELLI_API_URL=... -e PACELLI_AUTH_TOKEN=... pacelli-mcp

FROM node:20-slim AS builder

WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm ci --production=false

COPY tsconfig.json ./
COPY src/ ./src/
RUN npm run build

# ── Production image ──

FROM node:20-slim

WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm ci --omit=dev && npm cache clean --force

COPY --from=builder /app/dist ./dist

RUN addgroup --system --gid 1001 appgroup && adduser --system --uid 1001 --ingroup appgroup appuser
USER appuser

# Cloud Run uses PORT env var
ENV PORT=3000
EXPOSE 3000

# Health check for Cloud Run / load balancers
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD node -e "fetch('http://localhost:3000/health').then(r => r.ok ? process.exit(0) : process.exit(1)).catch(() => process.exit(1))"

# Run in HTTP mode
CMD ["node", "dist/index.js", "--http"]
