export interface AppEnv {
  NODE_ENV: string;
  PORT: number;
  API_PREFIX: string;
  APP_VERSION: string;
  DATABASE_URL?: string;
  JWT_ACCESS_SECRET: string;
  JWT_REFRESH_SECRET: string;
  JWT_ACCESS_EXPIRES_IN: string;
  JWT_REFRESH_EXPIRES_IN: string;
  REFRESH_TOKEN_PEPPER: string;
  JOIN_CODE_PEPPER: string;
  CORS_ORIGINS: string;
  RATE_LIMIT_TTL: number;
  RATE_LIMIT_LIMIT: number;
  AUTH_RATE_LIMIT_TTL: number;
  AUTH_RATE_LIMIT_LIMIT: number;
  TEAM_DEFAULT_QUOTA_BYTES: bigint;
}

function toInt(value: string | undefined, fallback: number): number {
  if (!value) return fallback;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

export function validateEnv(): AppEnv {
  const env: AppEnv = {
    NODE_ENV: process.env.NODE_ENV || 'development',
    PORT: toInt(process.env.PORT, 3000),
    API_PREFIX: process.env.API_PREFIX || '/api/v1',
    APP_VERSION: process.env.APP_VERSION || '1.0.0',
    DATABASE_URL: process.env.DATABASE_URL,
    JWT_ACCESS_SECRET: process.env.JWT_ACCESS_SECRET || 'replace_me_access',
    JWT_REFRESH_SECRET: process.env.JWT_REFRESH_SECRET || 'replace_me_refresh',
    JWT_ACCESS_EXPIRES_IN: process.env.JWT_ACCESS_EXPIRES_IN || '15m',
    JWT_REFRESH_EXPIRES_IN: process.env.JWT_REFRESH_EXPIRES_IN || '30d',
    REFRESH_TOKEN_PEPPER: process.env.REFRESH_TOKEN_PEPPER || 'replace_me_refresh_pepper',
    JOIN_CODE_PEPPER: process.env.JOIN_CODE_PEPPER || 'replace_me_join_code_pepper',
    CORS_ORIGINS: process.env.CORS_ORIGINS || '*',
    RATE_LIMIT_TTL: toInt(process.env.RATE_LIMIT_TTL, 60),
    RATE_LIMIT_LIMIT: toInt(process.env.RATE_LIMIT_LIMIT, 120),
    AUTH_RATE_LIMIT_TTL: toInt(process.env.AUTH_RATE_LIMIT_TTL, 60),
    AUTH_RATE_LIMIT_LIMIT: toInt(process.env.AUTH_RATE_LIMIT_LIMIT, 20),
    TEAM_DEFAULT_QUOTA_BYTES: BigInt(process.env.TEAM_DEFAULT_QUOTA_BYTES || '5368709120'),
  };

  if (!env.JWT_ACCESS_SECRET || !env.JWT_REFRESH_SECRET) {
    throw new Error('JWT secrets are required');
  }

  return env;
}
