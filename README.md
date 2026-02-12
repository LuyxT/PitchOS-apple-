# PitchInsights

This repository contains:
- iOS client app in `PitchInsights/`
- production backend in `backend/`
- archived legacy backend code in `backend_old/`

## Backend (Railway-ready)
The backend is fully isolated in `backend/`.

### Quick Start
1. `cd backend`
2. `cp .env.example .env`
3. `npm ci`
4. `npm run db:migrate:deploy`
5. `npm run start:dev`

### Production Commands
- Build: `npm run build`
- Start: `npm run start:prod`

`start:prod` applies Prisma migrations and then starts the server on `process.env.PORT`.

### Railway (Repo Root)
Railway builds from repository root.
- Root build command: `npm run build` (delegates to `backend/`)
- Root start command: `npm run start` (delegates to `backend/`)
- No manual root-directory override is required.

### Health URLs
- `GET /`
- `GET /health`
- `GET /api/v1/health`

All return JSON.

### API Contract
Every response uses the same envelope:
- Success: `{ "success": true, "data": ..., "error": null }`
- Error: `{ "success": false, "data": null, "error": { "code": "...", "message": "...", "details": ... } }`

### Smoke Test
Run with backend started:
- `cd backend && npm run smoke`
