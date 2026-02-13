# PitchInsights

Repository layout:
- iOS client app: `PitchInsights/`
- backend API: `backend/`
- archived legacy backend: `backend_old/`

## Backend quick start
```bash
cd backend
cp .env.example .env
npm install
npm run prisma:generate
npm run prisma:migrate:dev
npm run build
npm run start:prod
```

## Railway
Root scripts delegate to `backend/`:
- Build: `npm run build`
- Start: `npm run start`

Required Railway variables:
- `DATABASE_URL`
- `JWT_SECRET`
- `PORT`
