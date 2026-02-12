import { INestApplication, Injectable, OnModuleInit } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit {
  private connected = false;

  async onModuleInit(): Promise<void> {
    if (!process.env.DATABASE_URL) {
      console.error('PRISMA_CONNECT_SKIPPED', 'DATABASE_URL is missing');
      return;
    }

    try {
      await this.$connect();
      this.connected = true;
      console.log('PRISMA_CONNECT_OK');
    } catch (error) {
      console.error('PRISMA_CONNECT_FAILED', error);
    }
  }

  async enableShutdownHooks(app: INestApplication): Promise<void> {
    process.once('beforeExit', async () => {
      await app.close();
    });
  }

  isConnected(): boolean {
    return this.connected;
  }
}
