import express from 'express';
import cors from 'cors';
import { registerRoutes } from './routes';
import { errorHandler } from './middleware/errorHandler';
import { notFoundHandler } from './middleware/notFound';

export function createApp(jwtSecret: string) {
  const app = express();

  app.locals.jwtSecret = jwtSecret;

  app.use(cors());
  app.use(express.json({ limit: '1mb' }));

  registerRoutes(app, jwtSecret);

  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}
