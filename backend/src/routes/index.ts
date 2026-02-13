import type { Express } from 'express';
import { authRouter } from './authRoutes';
import { clubRouter } from './clubRoutes';
import { teamRouter } from './teamRoutes';
import { playerRouter } from './playerRoutes';
import { healthRouter } from './healthRoutes';

export function registerRoutes(app: Express, jwtSecret: string): void {
  app.use(healthRouter);
  app.use('/auth', authRouter(jwtSecret));
  app.use('/clubs', clubRouter(jwtSecret));
  app.use('/teams', teamRouter(jwtSecret));
  app.use('/players', playerRouter(jwtSecret));
}
