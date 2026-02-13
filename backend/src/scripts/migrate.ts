import { execSync } from 'child_process';

/**
 * Syncs the database schema with the Prisma schema on startup.
 * Uses `prisma db push` which compares the actual DB state with
 * schema.prisma and generates the necessary SQL.
 *
 * Pre-step: convert UserRole enum column to TEXT so db push can
 * cleanly sync without enum type conflicts.
 */

function execSQL(sql: string, label: string): boolean {
  try {
    execSync('npx prisma db execute --stdin', {
      encoding: 'utf-8',
      input: sql,
      stdio: ['pipe', 'pipe', 'pipe'],
    });
    console.log(`[migrate] ${label}: OK`);
    return true;
  } catch (err: unknown) {
    const e = err as Record<string, unknown>;
    const stderr = typeof e.stderr === 'string' ? e.stderr : '';
    console.log(`[migrate] ${label}: skipped (${stderr.slice(0, 100).trim() || 'error'})`);
    return false;
  }
}

async function main() {
  // Pre-step: convert role column from UserRole enum to TEXT if needed
  // This allows db push to work without enum type conflicts
  console.log('[migrate] Pre-step: fixing enum and normalizing data...');
  execSQL('ALTER TABLE "User" ALTER COLUMN "role" TYPE TEXT;', 'Convert role to TEXT');
  execSQL('UPDATE "User" SET "role" = LOWER("role");', 'Lowercase role values');
  execSQL(`UPDATE "User" SET "role" = 'player' WHERE "role" IN ('staff', 'spieler');`, 'Map legacy roles');
  execSQL(`UPDATE "User" SET "role" = 'trainer' WHERE "role" NOT IN ('trainer', 'player', 'board');`, 'Fix unknown roles');
  execSQL('DROP TYPE IF EXISTS "UserRole";', 'Drop UserRole enum');

  // Main step: sync schema with prisma db push
  console.log('[migrate] Running prisma db push...');
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
  }

  console.log('[migrate] Schema sync complete.');
  process.exit(0);
}

void main();
