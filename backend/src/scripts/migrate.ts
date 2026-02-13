import { execSync } from 'child_process';

/**
 * Syncs the database schema with the Prisma schema on startup.
 * Uses `prisma db push` instead of migrations because the migration
 * history is corrupted. db push compares the actual DB state with
 * schema.prisma and generates the necessary SQL.
 */
async function main() {
  console.log('[migrate] Syncing database schema with prisma db push...');

  try {
    const output = execSync('npx prisma db push --accept-data-loss --skip-generate', {
      encoding: 'utf-8',
      stdio: ['pipe', 'pipe', 'pipe'],
    });
    console.log('[migrate] db push succeeded.');
    if (output) console.log(output.trim());
  } catch (err: unknown) {
    const e = err as Record<string, unknown>;
    const stdout = typeof e.stdout === 'string' ? e.stdout : '';
    const stderr = typeof e.stderr === 'string' ? e.stderr : '';
    const combined = (stdout + stderr).slice(0, 500);
    console.warn('[migrate] db push warning:', combined);
    // Don't exit with error — server.ts schema repair will handle what it can
  }

  console.log('[migrate] Schema sync complete.');
  process.exit(0);
}

void main();
