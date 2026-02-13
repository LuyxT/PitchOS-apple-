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

  // ── Routes ────────────────────────────────────────────────
  const secret = env.JWT_ACCESS_SECRET;

  // Health — must be first, no auth
  app.use(healthRoutes());

  // API routes
  app.use('/auth', authRoutes(secret));
  app.use('/users', usersRoutes(secret));
  app.use('/clubs', clubsRoutes(secret));
  app.use('/teams', teamsRoutes(secret));
  app.use('/players', playersRoutes(secret));
  app.use('/trainings', trainingsRoutes(secret));
  app.use('/finances', financesRoutes(secret));
  app.use('/files', filesRoutes(secret));

  // ── Fallback ──────────────────────────────────────────────
  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}
