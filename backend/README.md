# PitchInsights Backend

Production backend for PitchInsights using NestJS + Prisma + PostgreSQL.

## Stack
- Node.js 20+
- NestJS
- Prisma
- PostgreSQL
- JWT auth (access + refresh)

## Local Setup
1. Copy env file:
   - `cp .env.example .env`
2. Install dependencies:
   - `npm ci`
3. Apply migrations:
   - `npm run db:migrate:deploy`
4. Start dev server:
   - `npm run start:dev`

## Production Startup
- Build:
  - `npm run build`
- Run:
  - `npm run start:prod`

`start:prod` runs Prisma migrations (`prisma migrate deploy`) and then starts `dist/main.js`.

## Required Env Vars
- `DATABASE_URL`
- `JWT_ACCESS_SECRET`
- `JWT_REFRESH_SECRET`
- `JWT_ACCESS_TTL` (default `15m`)
- `JWT_REFRESH_TTL` (default `30d`)
- `CORS_ORIGINS` (default `*`)
- `PORT` (Railway sets this automatically)

## API Base
- Versioned base: `/api/v1`
- Health:
  - `/api/v1/health`
  - `/health`
  - `/`

## Smoke Test
With backend running locally:
- `npm run smoke`

The smoke script checks health, register/login/me, onboarding club/team, players, and finance bootstrap routes.
