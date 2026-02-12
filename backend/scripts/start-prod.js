const { spawnSync } = require('node:child_process');
const path = require('node:path');
const { applyDatabaseUrlToEnv } = require('./db-url');

const resolved = applyDatabaseUrlToEnv();

if (!resolved) {
  console.error('[startup] Missing database connection. Set DATABASE_URL or Railway PG variables.');
  process.exit(1);
}

console.log('[startup] DATABASE_URL resolved for runtime.');

const prismaBin = path.join('node_modules', '.bin', process.platform === 'win32' ? 'prisma.cmd' : 'prisma');
const migrate = spawnSync(prismaBin, ['migrate', 'deploy'], {
  stdio: 'inherit',
  env: process.env,
});

if (migrate.status !== 0) {
  process.exit(migrate.status ?? 1);
}

const app = spawnSync('node', ['dist/main.js'], {
  stdio: 'inherit',
  env: process.env,
});

process.exit(app.status ?? 0);
