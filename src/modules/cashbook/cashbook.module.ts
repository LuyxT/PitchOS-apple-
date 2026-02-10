import { Module } from '@nestjs/common';
import { CashModule } from '../cash/cash.module';

@Module({
  imports: [CashModule],
  exports: [CashModule],
})
export class CashbookModule {}
