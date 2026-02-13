import dotenv from 'dotenv';

dotenv.config();

export type AppEnv = {
  DATABASE_URL: string;
  JWT_SECRET: string;
  PORT: number;
};

export function getEnv(): AppEnv {
  const DATABASE_URL = process.env.DATABASE_URL;
  const JWT_SECRET = process.env.JWT_SECRET ?? process.env.JWT_ACCESS_SECRET;
  const PORT_RAW = process.env.PORT ?? '3000';

  if (!DATABASE_URL) {
    throw new Error('Missing required env var: DATABASE_URL');
  }

  if (!JWT_SECRET) {
    throw new Error('Missing required env var: JWT_SECRET');
  }

  const PORT = Number(PORT_RAW);
  if (!Number.isFinite(PORT) || PORT <= 0) {
    throw new Error('Invalid PORT value. Expected positive number.');
  }

  return {
    DATABASE_URL,
    JWT_SECRET,
    PORT,
  };
}
