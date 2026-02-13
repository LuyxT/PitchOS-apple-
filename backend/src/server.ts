import { createApp } from './app';
import { getEnv } from './config/env';
import { logError, logInfo } from './config/logger';
import { prisma } from './prisma/client';

process.on('uncaughtException', (error) => {
  logError('Uncaught exception', {
    message: error.message,
    stack: error.stack,
  });
  process.exit(1);
});

process.on('unhandledRejection', (reason) => {
  logError('Unhandled rejection', {
    reason: reason instanceof Error ? reason.message : String(reason),
  });
  process.exit(1);
});

async function bootstrap() {
  let env;
  try {
    env = getEnv();
  } catch (error) {
    logError('Environment validation failed', {
      message: error instanceof Error ? error.message : 'Unknown environment error',
    });
    process.exit(1);
    return;
  }

  try {
    await prisma.$connect();
    logInfo('Database connection established');
  } catch (error) {
    logError('Database connection failed', {
      message: error instanceof Error ? error.message : 'Unknown database error',
    });
    process.exit(1);
    return;
  }

  const app = createApp(env.JWT_SECRET);
  logInfo('Routes registered', {
    routes: ['/health', '/auth/*', '/clubs/*', '/teams/*', '/players/*'],
  });

  const server = app.listen(env.PORT, () => {
    logInfo('Server started', {
      port: env.PORT,
    });
  });

  const shutdown = async (signal: string) => {
    logInfo('Shutdown signal received', { signal });
    server.close(async () => {
      await prisma.$disconnect();
      process.exit(0);
    });
  };

  process.on('SIGINT', () => {
    void shutdown('SIGINT');
  });

  process.on('SIGTERM', () => {
    void shutdown('SIGTERM');
  });
}

void bootstrap();
