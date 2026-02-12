import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(PrismaService.name);

  async onModuleInit(): Promise<void> {
    if (!process.env.DATABASE_URL) {
      this.logger.warn('DATABASE_URL is not set. Running in degraded mode.');
      return;
    }

    try {
      await this.$connect();
      this.logger.log('Prisma connected');
    } catch (error) {
      this.logger.error('Prisma connection failed, continuing in degraded mode', error as Error);
    }
  }

  async onModuleDestroy(): Promise<void> {
    await this.$disconnect();
  }
}
