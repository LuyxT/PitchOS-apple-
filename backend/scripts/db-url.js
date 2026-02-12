const { URL } = require('node:url');
require('dotenv').config();

function firstNonEmpty(keys) {
  for (const key of keys) {
    const value = process.env[key];
    if (value && value.trim().length > 0) {
      return value.trim();
    }
  }
  return null;
}

function normalizeUrl(urlValue) {
  try {
    const parsed = new URL(urlValue);
    if (!parsed.searchParams.has('schema') && parsed.protocol.startsWith('postgres')) {
      parsed.searchParams.set('schema', 'public');
    }
    return parsed.toString();
  } catch {
    return null;
  }
}

function buildFromParts() {
  const host = firstNonEmpty(['PGHOST', 'POSTGRES_HOST', 'DB_HOST']);
  const port = firstNonEmpty(['PGPORT', 'POSTGRES_PORT', 'DB_PORT']) || '5432';
  const database = firstNonEmpty(['PGDATABASE', 'POSTGRES_DB', 'DB_NAME']);
  const user = firstNonEmpty(['PGUSER', 'POSTGRES_USER', 'DB_USER']);
  const password = firstNonEmpty(['PGPASSWORD', 'POSTGRES_PASSWORD', 'DB_PASSWORD']) || '';

  if (!host || !database || !user) {
    return null;
  }

  const encodedUser = encodeURIComponent(user);
  const encodedPassword = encodeURIComponent(password);
  const credentials = password ? `${encodedUser}:${encodedPassword}` : encodedUser;

  return `postgresql://${credentials}@${host}:${port}/${database}?schema=public`;
}

function resolveDatabaseUrl() {
  const direct = firstNonEmpty([
    'DATABASE_URL',
    'DATABASE_PRIVATE_URL',
    'DATABASE_PUBLIC_URL',
    'POSTGRES_URL',
    'POSTGRESQL_URL',
    'PG_URL',
  ]);

  if (direct) {
    const normalized = normalizeUrl(direct);
    if (normalized) {
      return normalized;
    }
  }

  const built = buildFromParts();
  if (built) {
    return built;
  }

  return null;
}

function applyDatabaseUrlToEnv() {
  const resolved = resolveDatabaseUrl();

  if (!resolved) {
    return null;
  }

  process.env.DATABASE_URL = resolved;
  return resolved;
}

module.exports = {
  applyDatabaseUrlToEnv,
  resolveDatabaseUrl,
};
