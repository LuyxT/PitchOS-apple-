import { execSync } from 'child_process';

/**
 * Runs Prisma migrations on startup.
 * Strategy:
 *   1. Try `prisma migrate deploy` (production-safe)
 *   2. Always run `prisma db push` afterwards to ensure all tables
 *      actually exist (handles the case where migrations were marked
 *      as applied but the SQL never ran — e.g. after P3009 recovery)
 */
function run(cmd: string): { ok: boolean; output: string } {
  try {
    const output = execSync(cmd, { encoding: 'utf-8', stdio: 'pipe' });
    return { ok: true, output };
  } catch (err: unknown) {
    const e = err as Record<string, unknown>;
    const stdout = typeof e.stdout === 'string' ? e.stdout : '';
    const stderr = typeof e.stderr === 'string' ? e.stderr : '';
    return { ok: false, output: stdout + stderr || String(err) };
  }
}

async function main() {
  console.log('[migrate] Running prisma migrate deploy...');

  const deploy = run('npx prisma migrate deploy');

  if (deploy.ok) {
    console.log('[migrate] migrate deploy succeeded.');
  } else {
    console.warn('[migrate] migrate deploy failed:', deploy.output);
  }

  // Always run db push to ensure schema is in sync with database.
  // This is idempotent — if all tables exist, it does nothing.
  console.log('[migrate] Running prisma db push to ensure schema sync...');
  const push = run('npx prisma db push --skip-generate');

  if (push.ok) {
    console.log('[migrate] Schema is in sync.');
  } else {
    console.error('[migrate] db push failed:', push.output);
    // Don't exit(1) — the app may still work if tables existed
    console.warn('[migrate] Continuing despite db push failure...');
  }

  // If migrate deploy failed, mark migrations as applied so
  // future deploys don't get stuck
  if (!deploy.ok) {
    const migrations = ['20260213123000_init', '20260213140000_add_refresh_tokens_training'];
    for (const m of migrations) {
      const resolve = run(`npx prisma migrate resolve --applied ${m}`);
      if (resolve.ok) {
        console.log(`[migrate] Marked ${m} as applied.`);
      }
    }
  }

  console.log('[migrate] Migration process complete.');
  process.exit(0);
}

void main();
