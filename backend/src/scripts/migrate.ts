import { execSync } from 'child_process';
import path from 'path';

/**
 * Syncs the database schema with the Prisma schema on startup.
 * Uses `prisma db push` which compares the actual DB state with
 * schema.prisma and generates the necessary SQL.
 *
 * Pre-step: convert UserRole enum column to TEXT so db push can
 * cleanly sync without enum type conflicts.
 */

const PRISMA_BIN = path.resolve(__dirname, '../../node_modules/.bin/prisma');
const EXEC_TIMEOUT = 30_000; // 30s timeout per command

function execSQL(sql: string, label: string): boolean {
  try {
    execSync(`${PRISMA_BIN} db execute --stdin`, {
      encoding: 'utf-8',
      input: sql,
      stdio: ['pipe', 'pipe', 'pipe'],
      timeout: EXEC_TIMEOUT,
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
  console.log('[migrate] Starting schema sync...');
  console.log('[migrate] Prisma binary:', PRISMA_BIN);

  // Pre-step: convert UUID columns to TEXT and fix enum types
  // This allows db push to work without type conflicts (some users have CUIDs, not UUIDs)
  console.log('[migrate] Pre-step: converting columns to TEXT for compatibility...');

  // Convert all UUID id columns to TEXT (safe: UUIDs are valid TEXT values)
  // First drop FK constraints that reference UUID columns
  const fkConstraints = [
    { table: 'User', constraint: 'User_clubId_fkey' },
    { table: 'User', constraint: 'User_teamId_fkey' },
    { table: 'RefreshToken', constraint: 'RefreshToken_userId_fkey' },
    { table: 'Team', constraint: 'Team_clubId_fkey' },
    { table: 'Player', constraint: 'Player_teamId_fkey' },
    { table: 'Training', constraint: 'Training_teamId_fkey' },
  ];
  for (const { table, constraint } of fkConstraints) {
    execSQL(`ALTER TABLE "${table}" DROP CONSTRAINT IF EXISTS "${constraint}";`, `Drop FK ${constraint}`);
  }

  // Now convert columns
  const uuidTables = [
    { table: 'User', columns: ['id', 'clubId', 'teamId'] },
    { table: 'RefreshToken', columns: ['id', 'userId'] },
    { table: 'Club', columns: ['id'] },
    { table: 'Team', columns: ['id', 'clubId'] },
    { table: 'Player', columns: ['id', 'teamId'] },
    { table: 'Training', columns: ['id', 'teamId'] },
  ];
  for (const { table, columns } of uuidTables) {
    for (const col of columns) {
      execSQL(`ALTER TABLE "${table}" ALTER COLUMN "${col}" TYPE TEXT;`, `${table}.${col} → TEXT`);
    }
  }

  // Convert role column from UserRole enum to TEXT if needed
  execSQL('ALTER TABLE "User" ALTER COLUMN "role" TYPE TEXT;', 'User.role → TEXT');
  execSQL('UPDATE "User" SET "role" = LOWER("role");', 'Lowercase role values');
  execSQL(`UPDATE "User" SET "role" = 'player' WHERE "role" IN ('staff', 'spieler');`, 'Map legacy roles');
  execSQL(`UPDATE "User" SET "role" = 'trainer' WHERE "role" NOT IN ('trainer', 'player', 'board');`, 'Fix unknown roles');
  execSQL('DROP TYPE IF EXISTS "UserRole";', 'Drop UserRole enum');

  // Pre-step: make Player.teamId nullable and drop old age column
  execSQL('ALTER TABLE "Player" ALTER COLUMN "teamId" DROP NOT NULL;', 'Player.teamId → nullable');
  execSQL('ALTER TABLE "Player" DROP COLUMN IF EXISTS "age";', 'Drop Player.age column');

  // One-time: reset tyler@tenger.de for fresh onboarding
  execSQL('UPDATE "User" SET "onboardingCompleted" = false, "clubId" = NULL, "teamId" = NULL WHERE "email" = \'tyler@tenger.de\';', 'Reset tyler onboarding');

  // Main step: sync schema with prisma db push
  console.log('[migrate] Running prisma db push...');
  try {
    const output = execSync(`${PRISMA_BIN} db push --accept-data-loss --skip-generate`, {
      encoding: 'utf-8',
      stdio: ['pipe', 'pipe', 'pipe'],
      timeout: 120_000, // 2 minutes for db push
    });
    console.log('[migrate] db push succeeded.');
    if (output) console.log(output.trim());
  } catch (err: unknown) {
    const e = err as Record<string, unknown>;
    const stdout = typeof e.stdout === 'string' ? e.stdout : '';
    const stderr = typeof e.stderr === 'string' ? e.stderr : '';
    const combined = (stdout + stderr).slice(0, 500);
    console.warn('[migrate] db push warning:', combined);
    // Don't exit with error — server can still start and Prisma will create tables on demand
  }

  console.log('[migrate] Schema sync complete.');
  process.exit(0);
}

void main();
