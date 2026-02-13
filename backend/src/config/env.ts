import dotenv from 'dotenv';

dotenv.config();

export interface AppEnv {
  NODE_ENV: 'development' | 'production' | 'test';
  PORT: number;
  DATABASE_URL: string;
  JWT_ACCESS_SECRET: string;
  JWT_REFRESH_SECRET: string;
  JWT_ACCESS_TTL: string;
  JWT_REFRESH_TTL: string;
  CORS_ORIGINS: string[];
}

function optional(name: string, fallback: string): string {
  const value = process.env[name];
  if (!value || value.trim() === '') return fallback;
  return value.trim();
}

export function loadEnv(): AppEnv {
  // DATABASE_URL — required, crash if missing
  // Railway may expose the URL under alternate names
  const DATABASE_URL =
    process.env.DATABASE_URL ||
    process.env.DATABASE_PRIVATE_URL ||
    process.env.DATABASE_PUBLIC_URL ||
    '';

  if (!DATABASE_URL) {
    console.error(
      'FATAL: Missing required environment variable: DATABASE_URL (also checked DATABASE_PRIVATE_URL, DATABASE_PUBLIC_URL)'
    );
    process.exit(1);
  }

  // JWT secrets — required, crash if missing
  // Support both JWT_SECRET (single shared secret) and JWT_ACCESS_SECRET/JWT_REFRESH_SECRET (split)
  const jwtSecret = process.env.JWT_SECRET || '';
  const JWT_ACCESS_SECRET = process.env.JWT_ACCESS_SECRET || jwtSecret;
  const JWT_REFRESH_SECRET = process.env.JWT_REFRESH_SECRET || jwtSecret;

  if (!JWT_ACCESS_SECRET) {
    console.error(
      'FATAL: Missing required environment variable: JWT_ACCESS_SECRET or JWT_SECRET'
    );
    process.exit(1);
  }

  if (!JWT_REFRESH_SECRET) {
    console.error(
      'FATAL: Missing required environment variable: JWT_REFRESH_SECRET or JWT_SECRET'
    );
    process.exit(1);
  }

  // PORT
  const portRaw = optional('PORT', '3000');
  const PORT = Number(portRaw);
  if (!Number.isFinite(PORT) || PORT <= 0 || PORT > 65535) {
    console.error(`FATAL: Invalid PORT value: "${portRaw}". Must be 1-65535.`);
    process.exit(1);
  }

  // NODE_ENV
  const nodeEnvRaw = optional('NODE_ENV', 'production');
  const NODE_ENV = (['development', 'production', 'test'].includes(nodeEnvRaw)
    ? nodeEnvRaw
    : 'production') as AppEnv['NODE_ENV'];

  // Token TTLs
  const JWT_ACCESS_TTL = optional('JWT_ACCESS_TTL', '15m');
  const JWT_REFRESH_TTL = optional('JWT_REFRESH_TTL', '30d');

  // CORS
  const corsRaw = optional('CORS_ORIGINS', '*');
  const CORS_ORIGINS = corsRaw === '*' ? ['*'] : corsRaw.split(',').map((s) => s.trim());

  return {
    NODE_ENV,
    PORT,
    DATABASE_URL,
    JWT_ACCESS_SECRET,
    JWT_REFRESH_SECRET,
    JWT_ACCESS_TTL,
    JWT_REFRESH_TTL,
    CORS_ORIGINS,
  };
}
