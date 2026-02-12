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

export function getEnv(): AppEnv {
  if (cachedEnv) {
    return cachedEnv;
  }

  const env: AppEnv = {
    NODE_ENV: process.env.NODE_ENV ?? 'development',
    PORT: process.env.PORT ?? '3000',
    DATABASE_URL: requireVariable('DATABASE_URL'),
    JWT_ACCESS_SECRET:
      process.env.JWT_ACCESS_SECRET ?? 'local_access_secret_change_me',
    JWT_REFRESH_SECRET:
      process.env.JWT_REFRESH_SECRET ?? 'local_refresh_secret_change_me',
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
