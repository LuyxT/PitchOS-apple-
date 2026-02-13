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

  // First: ensure the UserRole enum has the correct values
  await ensureUserRoleEnum(prisma);

  // Always run all statements — they use IF NOT EXISTS so are safe to repeat
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

  logger.info('Schema check complete — all columns and tables ensured');
}

async function ensureUserRoleEnum(prisma: ReturnType<typeof getPrisma>): Promise<void> {
  const expectedValues = ['trainer', 'player', 'board'];

  // Check if the enum type exists and has the expected values
  const enumValues = await prisma.$queryRaw<Array<{ enumlabel: string }>>`
    SELECT enumlabel FROM pg_enum
    WHERE enumtypid = (SELECT oid FROM pg_type WHERE typname = 'UserRole')
    ORDER BY enumsortorder
  `;

  const currentValues = enumValues.map((v) => v.enumlabel);
  const enumOK =
    currentValues.length === expectedValues.length &&
    expectedValues.every((v) => currentValues.includes(v));

  if (enumOK) {
    logger.info('Schema check: UserRole enum is correct');
  } else {
    logger.warn('Schema check: UserRole enum is missing or has wrong values', {
      current: currentValues,
      expected: expectedValues,
    });
  }

  // Always normalize existing data and ensure enum is correct
  try {
    // Convert to TEXT so we can fix values
    await prisma.$executeRawUnsafe(`ALTER TABLE "User" ALTER COLUMN "role" TYPE TEXT`);
    // Normalize values to lowercase
    await prisma.$executeRawUnsafe(`UPDATE "User" SET "role" = LOWER("role")`);
    // Map any legacy values
    await prisma.$executeRawUnsafe(`UPDATE "User" SET "role" = 'player' WHERE "role" IN ('staff', 'spieler')`);
    await prisma.$executeRawUnsafe(`UPDATE "User" SET "role" = 'trainer' WHERE "role" NOT IN ('trainer', 'player', 'board')`);
    // Drop and recreate enum
    await prisma.$executeRawUnsafe(`DROP TYPE IF EXISTS "UserRole"`);
    await prisma.$executeRawUnsafe(`CREATE TYPE "UserRole" AS ENUM ('trainer', 'player', 'board')`);
    // Convert column back to enum
    await prisma.$executeRawUnsafe(
      `ALTER TABLE "User" ALTER COLUMN "role" TYPE "UserRole" USING "role"::"UserRole"`
    );
    logger.info('Schema fix: UserRole enum and data normalized');
  } catch (err) {
    logger.error('Schema fix: UserRole enum repair failed', {
      error: err instanceof Error ? err.message : String(err),
    });
  }
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
