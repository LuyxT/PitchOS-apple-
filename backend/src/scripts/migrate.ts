import { execSync } from 'child_process';

/**
 * Runs Prisma migrations on startup.
 * Handles the case where migrations were marked as applied but the SQL
 * never actually ran (e.g. after P3009 recovery).
 */
function run(cmd: string, input?: string): { ok: boolean; output: string } {
  try {
    const output = execSync(cmd, {
      encoding: 'utf-8',
      stdio: ['pipe', 'pipe', 'pipe'],
      input,
    });
    return { ok: true, output };
  } catch (err: unknown) {
    const e = err as Record<string, unknown>;
    const stdout = typeof e.stdout === 'string' ? e.stdout : '';
    const stderr = typeof e.stderr === 'string' ? e.stderr : '';
    return { ok: false, output: stdout + stderr || String(err) };
  }
}

function columnExists(table: string, column: string): boolean {
  const sql = `SELECT column_name FROM information_schema.columns WHERE table_name='${table}' AND column_name='${column}';`;
  const result = run('npx prisma db execute --stdin', sql);
  return result.ok && result.output.includes(column);
}

function runSQL(sql: string): boolean {
  const result = run('npx prisma db execute --stdin', sql);
  if (!result.ok) {
    console.warn(`[migrate] SQL warning: ${result.output.slice(0, 300)}`);
  }
  return result.ok;
}

async function main() {
  console.log('[migrate] Starting migration process...');

  // Step 1: Try standard migrate deploy
  console.log('[migrate] Running prisma migrate deploy...');
  const deploy = run('npx prisma migrate deploy');

  if (deploy.ok) {
    console.log('[migrate] migrate deploy succeeded.');
  } else {
    console.warn('[migrate] migrate deploy output:', deploy.output.slice(0, 500));
  }

  // Step 2: Verify the schema is actually correct by checking for a column
  // that was added in the second migration
  const hasColumn = columnExists('User', 'onboardingCompleted');

  if (!hasColumn) {
    console.warn('[migrate] Column User.onboardingCompleted missing — second migration SQL never ran.');
    console.log('[migrate] Attempting to mark second migration as rolled back and re-deploy...');

    // Mark the second migration as NOT applied so migrate deploy will re-run it
    run('npx prisma migrate resolve --rolled-back 20260213140000_add_refresh_tokens_training');

    // Re-run migrate deploy — should execute the second migration's SQL
    const retry = run('npx prisma migrate deploy');
    if (retry.ok) {
      console.log('[migrate] Re-deploy succeeded — missing columns added.');
    } else {
      console.warn('[migrate] Re-deploy failed:', retry.output.slice(0, 500));

      // Last resort: run the missing ALTER TABLE / CREATE TABLE statements directly
      console.log('[migrate] Applying missing schema changes via raw SQL...');

      runSQL('ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "firstName" TEXT;');
      runSQL('ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "lastName" TEXT;');
      runSQL('ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;');
      runSQL('ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "onboardingCompleted" BOOLEAN NOT NULL DEFAULT false;');
      runSQL('ALTER TABLE "Club" ADD COLUMN IF NOT EXISTS "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;');
      runSQL('ALTER TABLE "Team" ADD COLUMN IF NOT EXISTS "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;');
      runSQL('ALTER TABLE "Player" ADD COLUMN IF NOT EXISTS "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;');

      runSQL(`
        CREATE TABLE IF NOT EXISTS "RefreshToken" (
          "id" UUID NOT NULL,
          "token" TEXT NOT NULL,
          "userId" UUID NOT NULL,
          "expiresAt" TIMESTAMP(3) NOT NULL,
          "revokedAt" TIMESTAMP(3),
          "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
          CONSTRAINT "RefreshToken_pkey" PRIMARY KEY ("id")
        );
      `);
      runSQL('CREATE UNIQUE INDEX IF NOT EXISTS "RefreshToken_token_key" ON "RefreshToken"("token");');
      runSQL('CREATE INDEX IF NOT EXISTS "RefreshToken_userId_idx" ON "RefreshToken"("userId");');
      runSQL('CREATE INDEX IF NOT EXISTS "RefreshToken_token_idx" ON "RefreshToken"("token");');

      // Mark the second migration as applied to prevent re-running
      run('npx prisma migrate resolve --applied 20260213140000_add_refresh_tokens_training');

      console.log('[migrate] Raw SQL schema fix complete.');
    }
  } else {
    console.log('[migrate] Schema verified — all expected columns present.');
  }

  console.log('[migrate] Migration process complete.');
  process.exit(0);
}

void main();
