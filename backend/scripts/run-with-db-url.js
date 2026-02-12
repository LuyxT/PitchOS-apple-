const { spawnSync } = require('node:child_process');
const path = require('node:path');
const { applyDatabaseUrlToEnv } = require('./db-url');

const args = process.argv.slice(2);
if (args.length === 0) {
  console.error('Usage: node scripts/run-with-db-url.js <command> [args...]');
  process.exit(1);
}

const resolved = applyDatabaseUrlToEnv();
if (!resolved) {
  console.error('[db-url] Missing database connection. Set DATABASE_URL or Railway PG variables.');
  process.exit(1);
}

let cmd = args[0];
let cmdArgs = args.slice(1);

if (cmd === 'prisma') {
  cmd = path.join('node_modules', '.bin', process.platform === 'win32' ? 'prisma.cmd' : 'prisma');
}

const result = spawnSync(cmd, cmdArgs, {
  stdio: 'inherit',
  env: process.env,
});

process.exit(result.status ?? 0);
