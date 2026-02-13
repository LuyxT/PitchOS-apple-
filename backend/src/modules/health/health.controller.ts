import type { Request, Response } from 'express';
import { getPrisma } from '../../lib/prisma';

export async function healthCheck(_req: Request, res: Response) {
  let dbStatus = 'ok';

  try {
    await getPrisma().$queryRaw`SELECT 1`;
  } catch {
    dbStatus = 'unreachable';
  }

  const status = dbStatus === 'ok' ? 'ok' : 'degraded';
  const httpStatus = dbStatus === 'ok' ? 200 : 503;

  res.status(httpStatus).json({
    status,
    timestamp: new Date().toISOString(),
    services: {
      database: dbStatus,
    },
  });
}
