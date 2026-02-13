import { loadEnv } from './config/env';
import { logger } from './config/logger';
import { getPrisma, connectDatabase, disconnectDatabase } from './lib/prisma';
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

// ── Schema repair ──────────────────────────────────────────

async function ensureSchemaColumns(): Promise<void> {
  const prisma = getPrisma();

  const result = await prisma.$queryRaw<Array<{ column_name: string }>>`
    SELECT column_name FROM information_schema.columns
    WHERE table_name = 'User' AND column_name = 'onboardingCompleted'
  `;

  if (result.length > 0) {
    logger.info('Schema check: all expected columns present');
    return;
  }

  logger.warn('Schema check: User.onboardingCompleted missing — applying fixes...');

  const statements = [
    `ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "firstName" TEXT`,
    `ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "lastName" TEXT`,
    `ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP`,
    `ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "onboardingCompleted" BOOLEAN NOT NULL DEFAULT false`,
    `ALTER TABLE "Club" ADD COLUMN IF NOT EXISTS "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP`,
    `ALTER TABLE "Team" ADD COLUMN IF NOT EXISTS "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP`,
    `ALTER TABLE "Player" ADD COLUMN IF NOT EXISTS "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP`,
    `CREATE TABLE IF NOT EXISTS "RefreshToken" (
      "id" UUID NOT NULL,
      "token" TEXT NOT NULL,
      "userId" UUID NOT NULL,
      "expiresAt" TIMESTAMP(3) NOT NULL,
      "revokedAt" TIMESTAMP(3),
      "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
      CONSTRAINT "RefreshToken_pkey" PRIMARY KEY ("id")
    )`,
    `CREATE UNIQUE INDEX IF NOT EXISTS "RefreshToken_token_key" ON "RefreshToken"("token")`,
    `CREATE INDEX IF NOT EXISTS "RefreshToken_userId_idx" ON "RefreshToken"("userId")`,
    `CREATE INDEX IF NOT EXISTS "RefreshToken_token_idx" ON "RefreshToken"("token")`,
    `CREATE TABLE IF NOT EXISTS "Training" (
      "id" UUID NOT NULL,
      "title" TEXT NOT NULL,
      "description" TEXT,
      "date" TIMESTAMP(3) NOT NULL,
      "teamId" UUID NOT NULL,
      "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
      "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
      CONSTRAINT "Training_pkey" PRIMARY KEY ("id")
    )`,
    `CREATE INDEX IF NOT EXISTS "Training_teamId_idx" ON "Training"("teamId")`,
  ];

  for (const sql of statements) {
    try {
      await prisma.$executeRawUnsafe(sql);
    } catch (err) {
      logger.warn('Schema fix SQL warning', {
        sql: sql.slice(0, 100),
        error: err instanceof Error ? err.message : String(err),
      });
    }
  }

  logger.info('Schema fix complete — missing columns and tables added');
}

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

  // 2b. Ensure schema columns exist (handles botched migrations)
  try {
    await ensureSchemaColumns();
  } catch (error) {
    logger.error('Schema repair failed', {
      message: error instanceof Error ? error.message : 'Unknown error',
    });
    // Don't exit — the app may still work if columns exist
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
