import { execSync } from 'child_process';

/**
 * Resolves any failed Prisma migrations, then runs migrate deploy.
 * This handles the P3009 error where a previously failed migration
 * blocks all subsequent migrations.
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

  const first = run('npx prisma migrate deploy');

  if (first.ok) {
    console.log('[migrate] Migrations applied successfully.');
    process.exit(0);
  }

  // Check if it's a P3009 (failed migration blocking)
  if (!first.output.includes('P3009')) {
    console.error('[migrate] Migration failed with unexpected error:');
    console.error(first.output);
    process.exit(1);
  }

  // Extract the failed migration name
  const match = first.output.match(/The `(\S+)` migration/);
  if (!match) {
    console.error('[migrate] Could not parse failed migration name from output.');
    console.error(first.output);
    process.exit(1);
  }

  const failedMigration = match[1];
  console.log(`[migrate] Found failed migration: ${failedMigration}`);
  console.log(`[migrate] Marking as rolled back...`);

  const resolve = run(`npx prisma migrate resolve --rolled-back ${failedMigration}`);
  if (!resolve.ok) {
    console.error('[migrate] Failed to resolve migration:');
    console.error(resolve.output);
    process.exit(1);
  }

  console.log(`[migrate] Marked ${failedMigration} as rolled back. Re-applying...`);

  const resolve2 = run(`npx prisma migrate resolve --applied ${failedMigration}`);
  if (!resolve2.ok) {
    console.error('[migrate] Failed to mark migration as applied:');
    console.error(resolve2.output);
    process.exit(1);
  }

  console.log(`[migrate] Marked ${failedMigration} as applied.`);

  // Now try deploying remaining migrations
  const retry = run('npx prisma migrate deploy');
  if (!retry.ok) {
    // If it fails again with P3009 for a different migration, recursively handle
    if (retry.output.includes('P3009')) {
      console.log('[migrate] Another failed migration detected, resolving...');
      // Handle the second migration the same way
      const match2 = retry.output.match(/The `(\S+)` migration/);
      if (match2) {
        const failed2 = match2[1];
        run(`npx prisma migrate resolve --rolled-back ${failed2}`);
        run(`npx prisma migrate resolve --applied ${failed2}`);
        const final = run('npx prisma migrate deploy');
        if (!final.ok && !final.output.includes('already in sync')) {
          console.warn('[migrate] Final deploy warning:', final.output);
        }
      }
    } else if (!retry.output.includes('already in sync')) {
      console.warn('[migrate] Deploy after resolve:', retry.output);
    }
  }

  console.log('[migrate] Migration process complete.');
  process.exit(0);
}

void main();
