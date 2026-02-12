export interface AppEnv {
  NODE_ENV: string;
  PORT: string;
  DATABASE_URL: string;
  JWT_ACCESS_SECRET: string;
  JWT_REFRESH_SECRET: string;
  JWT_ACCESS_TTL: string;
  JWT_REFRESH_TTL: string;
  CORS_ORIGINS: string;
}

let cachedEnv: AppEnv | null = null;

function requireVariable(name: string): string {
  const value = process.env[name];

  if (!value || value.trim().length === 0) {
    throw new Error(`Missing required environment variable: ${name}`);
  }

  return value;
}

function firstNonEmpty(keys: string[]): string | null {
  for (const key of keys) {
    const value = process.env[key];
    if (value && value.trim().length > 0) {
      return value.trim();
    }
  }

  return null;
}

function resolveDatabaseUrlFromEnv(): string {
  const databaseUrl = firstNonEmpty([
    'DATABASE_URL',
    'DATABASE_PRIVATE_URL',
    'DATABASE_PUBLIC_URL',
    'POSTGRES_URL',
    'POSTGRESQL_URL',
    'PG_URL',
  ]);

  if (!databaseUrl) {
    return requireVariable('DATABASE_URL');
  }

  process.env.DATABASE_URL = databaseUrl;
  return databaseUrl;
}

export function getEnv(): AppEnv {
  if (cachedEnv) {
    return cachedEnv;
  }

  const env: AppEnv = {
    NODE_ENV: process.env.NODE_ENV ?? 'development',
    PORT: process.env.PORT ?? '3000',
    DATABASE_URL: resolveDatabaseUrlFromEnv(),
    JWT_ACCESS_SECRET:
      process.env.JWT_ACCESS_SECRET ??
      process.env.JWT_SECRET ??
      'local_access_secret_change_me',
    JWT_REFRESH_SECRET:
      process.env.JWT_REFRESH_SECRET ??
      process.env.REFRESH_SECRET ??
      'local_refresh_secret_change_me',
    JWT_ACCESS_TTL: process.env.JWT_ACCESS_TTL ?? '15m',
    JWT_REFRESH_TTL: process.env.JWT_REFRESH_TTL ?? '30d',
    CORS_ORIGINS: process.env.CORS_ORIGINS ?? '*',
  };

  cachedEnv = env;
  return env;
}

export function getCorsOrigins(): true | string[] {
  const value = getEnv().CORS_ORIGINS;

  if (value === '*') {
    return true;
  }

  return value
    .split(',')
    .map((origin) => origin.trim())
    .filter((origin) => origin.length > 0);
}
