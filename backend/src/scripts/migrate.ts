import { execSync } from 'child_process';

/**
 * Runs Prisma migrations on startup.
 * Schema repair (missing columns/tables) is handled by server.ts at runtime.
 */
async function main() {
  console.log('[migrate] Running prisma migrate deploy...');

  try {
    const output = execSync('npx prisma migrate deploy', {
      encoding: 'utf-8',
      stdio: ['pipe', 'pipe', 'pipe'],
    });
    console.log('[migrate] migrate deploy succeeded.');
    if (output) console.log(output.trim());
  } catch (err: unknown) {
    const e = err as Record<string, unknown>;
    const stdout = typeof e.stdout === 'string' ? e.stdout : '';
    const stderr = typeof e.stderr === 'string' ? e.stderr : '';
    console.warn('[migrate] migrate deploy warning:', (stdout + stderr).slice(0, 500));
    // Don't exit with error — server.ts schema repair will handle missing tables/columns
  }

  console.log('[migrate] Migration process complete.');
  process.exit(0);
}

void main();
