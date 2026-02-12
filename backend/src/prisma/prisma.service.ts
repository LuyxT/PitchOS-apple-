import { Injectable, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';
import { structuredLog } from '../common/logging/structured-log';

@Injectable()
export class PrismaService
  extends PrismaClient
  implements OnModuleInit, OnModuleDestroy
{
  async onModuleInit(): Promise<void> {
    try {
      await this.$connect();
      structuredLog('info', 'database.connected');
    } catch (error) {
      structuredLog('error', 'database.connection_failed', {
        message: error instanceof Error ? error.message : 'unknown',
      });
      throw error;
    }
  }

  async onModuleDestroy(): Promise<void> {
    await this.$disconnect();
    structuredLog('info', 'database.disconnected');
  }
}
