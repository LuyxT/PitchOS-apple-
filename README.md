# PitchInsights Backend

Production-ready NestJS backend configured for Railway deployment.

## Stack
- Node.js 20
- NestJS (Express)
- TypeScript
- Prisma (PostgreSQL configuration)

## Start Flow
1. Install dependencies:
   - `npm ci`
2. Build:
   - `npm run build`
3. Start:
   - `npm run start`

The server binds to `process.env.PORT` and falls back to `3000`.

## Healthcheck
- Endpoint: `GET /health`
- Response: `{"status":"ok"}`
- HTTP status: `200`

This endpoint is excluded from API prefixing and is intended for Railway health checks.

## API Base
- Versioned base path: `/api/v1`
- Health endpoint remains at `/health`.

## Railway Notes
- Repo root contains `package.json`, `tsconfig.json`, `nest-cli.json`, and `Dockerfile`.
- Build output target is `dist/main.js`.
- Docker image uses a multi-stage Node 20 build.
- Runtime command is `npm run start`.
