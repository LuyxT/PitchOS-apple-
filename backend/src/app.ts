import express from 'express';
import cors from 'cors';
import crypto from 'crypto';
import type { AppEnv } from './config/env';
import { errorHandler } from './middleware/errorHandler';
import { notFoundHandler } from './middleware/notFound';

// Module routes
import { healthRoutes } from './modules/health/health.routes';
import { authRoutes } from './modules/auth/auth.routes';
import { usersRoutes } from './modules/users/users.routes';
import { clubsRoutes } from './modules/clubs/clubs.routes';
import { teamsRoutes } from './modules/teams/teams.routes';
import { playersRoutes } from './modules/players/players.routes';
import { trainingsRoutes } from './modules/trainings/trainings.routes';
import { financesRoutes } from './modules/finances/finances.routes';
import { filesRoutes } from './modules/files/files.routes';
import { onboardingRoutes } from './modules/onboarding/onboarding.routes';
import { profileRoutes } from './modules/profile/profile.routes';
import { calendarRoutes } from './modules/calendar/calendar.routes';
import { cashRoutes } from './modules/cash/cash.routes';
import { trainingPlansRoutes } from './modules/training-plans/training-plans.routes';
import { cloudRoutes } from './modules/cloud/cloud.routes';
import { messengerRoutes } from './modules/messenger/messenger.routes';
import { adminRoutes } from './modules/admin/admin.routes';
import { settingsRoutes } from './modules/settings/settings.routes';
import { profilesRoutes } from './modules/profiles/profiles.routes';
import { tacticsRoutes } from './modules/tactics/tactics.routes';
import { analysisRoutes } from './modules/analysis/analysis.routes';
import { matchesRoutes } from './modules/matches/matches.routes';
import { feedbackRoutes } from './modules/feedback/feedback.routes';

export function createApp(env: AppEnv) {
  const app = express();

  // Store env on app for controllers to access
  app.locals.env = env;

  // Trust proxy (Railway, Render, etc.)
  app.set('trust proxy', 1);

  // CORS
  const corsOptions: cors.CorsOptions = {
    origin: env.CORS_ORIGINS.includes('*') ? true : env.CORS_ORIGINS,
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
  };
  app.use(cors(corsOptions));

  // Body parsing
  app.use(express.json({ limit: '5mb' }));
  app.use(express.urlencoded({ extended: true, limit: '5mb' }));

  // Request ID
  app.use((req, _res, next) => {
    req.requestId = (req.headers['x-request-id'] as string) || crypto.randomUUID();
    next();
  });

  // ── Root-level routes (no prefix) ─────────────────────────
  // Health + bootstrap — must be first, no auth, no /api/v1 prefix
  app.use(healthRoutes());

  // ── API routes under /api/v1 ──────────────────────────────
  const secret = env.JWT_ACCESS_SECRET;
  const api = express.Router();

  api.use('/auth', authRoutes(secret));
  api.use('/users', usersRoutes(secret));
  api.use('/clubs', clubsRoutes(secret));
  api.use('/teams', teamsRoutes(secret));
  api.use('/players', playersRoutes(secret));
  api.use('/trainings', trainingsRoutes(secret));
  api.use('/finance/cash', cashRoutes(secret));
  api.use('/finance', financesRoutes(secret));
  api.use('/files', filesRoutes(secret));
  api.use('/onboarding', onboardingRoutes(secret));
  api.use('/profile', profileRoutes(secret));
  api.use('/calendar', calendarRoutes(secret));
  api.use('/training', trainingPlansRoutes(secret));
  api.use('/cloud', cloudRoutes(secret));
  api.use('/messages', messengerRoutes(secret));
  api.use('/admin', adminRoutes(secret));
  api.use('/settings', settingsRoutes(secret));
  api.use('/profiles', profilesRoutes(secret));
  api.use('/tactics', tacticsRoutes(secret));
  api.use('/analysis', analysisRoutes(secret));
  api.use('/matches', matchesRoutes(secret));
  api.use('/feedback', feedbackRoutes(secret));

  app.use('/api/v1', api);

  // ── Fallback ──────────────────────────────────────────────
  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}
