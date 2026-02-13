import { PrismaClient } from '@prisma/client';

let client: PrismaClient | null = null;

export function getPrisma(): PrismaClient {
  if (!client) {
    client = new PrismaClient({
      log:
        process.env.NODE_ENV === 'development'
          ? ['query', 'warn', 'error']
          : ['warn', 'error'],
    });
  }
  return client;
}

export async function connectDatabase(): Promise<void> {
  const prisma = getPrisma();
  await prisma.$connect();
}

export async function disconnectDatabase(): Promise<void> {
  if (client) {
    await client.$disconnect();
    client = null;
  }
}
