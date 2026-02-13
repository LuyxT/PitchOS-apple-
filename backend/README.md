# PitchInsights Backend (Express + Prisma)

## Voraussetzungen
- Node.js 22 LTS
- PostgreSQL

## Environment
`.env` anlegen (siehe `.env.example`):

- `DATABASE_URL`
- `JWT_SECRET`
- `PORT`

## Setup
```bash
npm install
npm run prisma:generate
npm run prisma:migrate:dev
npm run build
npm run start:prod
```

## Railway
- Build: `npm run build`
- Start: `npm run start:prod`
- Pflichtvariablen: `DATABASE_URL`, `JWT_SECRET`, `PORT`
