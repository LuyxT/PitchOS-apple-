import { loadEnv } from './config/env';
import { logger } from './config/logger';
import { connectDatabase, disconnectDatabase } from './lib/prisma';
import { createApp } from './app';

// ── Global error handlers ──────────────────────────────────

process.on('uncaughtException', (error) => {
  logger.error('Uncaught exception — shutting down', {
    name: error.name,
    message: error.message,
    stack: error.stack,
  });
  process.exit(1);
});

process.on('unhandledRejection', (reason) => {
  logger.error('Unhandled rejection — shutting down', {
    reason: reason instanceof Error ? reason.message : String(reason),
    stack: reason instanceof Error ? reason.stack : undefined,
  });
  process.exit(1);
});

// ── Bootstrap ──────────────────────────────────────────────

async function bootstrap() {
  // 1. Validate environment — crashes immediately if invalid
  const env = loadEnv();
  logger.info('Environment validated', { nodeEnv: env.NODE_ENV, port: env.PORT });

  // 2. Connect to database
  try {
    await connectDatabase();
    logger.info('Database connection established');
  } catch (error) {
    logger.error('Database connection failed', {
      message: error instanceof Error ? error.message : 'Unknown database error',
    });
    process.exit(1);
  }

  // 3. Create Express app
  const app = createApp(env);

  // 4. Start HTTP server
  const server = app.listen(env.PORT, '0.0.0.0', () => {
    logger.info('Server started', {
      port: env.PORT,
      nodeEnv: env.NODE_ENV,
    });
  });

  // 5. Graceful shutdown
  const shutdown = async (signal: string) => {
    logger.info('Shutdown signal received', { signal });

    server.close(async () => {
      logger.info('HTTP server closed');
      await disconnectDatabase();
      logger.info('Database disconnected');
      process.exit(0);
    });

    // Force exit after 10 seconds if graceful shutdown fails
    setTimeout(() => {
      logger.error('Forced shutdown after timeout');
      process.exit(1);
    }, 10_000).unref();
  };

  process.on('SIGINT', () => void shutdown('SIGINT'));
  process.on('SIGTERM', () => void shutdown('SIGTERM'));
}

void bootstrap();
