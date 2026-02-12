import { CashTransactionType, PaymentStatus } from '@prisma/client';
import { IsDateString, IsEnum, IsNumber, IsOptional, IsString } from 'class-validator';

export class CreateTransactionDto {
  @IsString()
  teamId!: string;

  @IsNumber()
  amount!: number;

  @IsDateString()
  date!: string;

  @IsString()
  category!: string;

  @IsOptional()
  @IsString()
  description?: string;

  @IsEnum(CashTransactionType)
  type!: CashTransactionType;

  @IsOptional()
  @IsString()
  playerId?: string;

  @IsOptional()
  @IsString()
  comment?: string;

  @IsOptional()
  @IsEnum(PaymentStatus)
  paymentStatus?: PaymentStatus;
}

export class UpdateTransactionDto {
  @IsOptional()
  @IsNumber()
  amount?: number;

  @IsOptional()
  @IsDateString()
  date?: string;

  @IsOptional()
  @IsString()
  category?: string;

  @IsOptional()
  @IsString()
  description?: string;

  @IsOptional()
  @IsEnum(CashTransactionType)
  type?: CashTransactionType;

  @IsOptional()
  @IsString()
  playerId?: string;

  @IsOptional()
  @IsString()
  comment?: string;

  @IsOptional()
  @IsEnum(PaymentStatus)
  paymentStatus?: PaymentStatus;
}

export class CreateCashGoalDto {
  @IsString()
  teamId!: string;

  @IsString()
  name!: string;

  @IsNumber()
  targetAmount!: number;

  @IsDateString()
  startDate!: string;

  @IsDateString()
  endDate!: string;
}

export class CreateMonthlyContributionDto {
  @IsString()
  teamId!: string;

  @IsString()
  playerId!: string;

  @IsNumber()
  amount!: number;

  @IsDateString()
  dueDate!: string;

  @IsOptional()
  @IsEnum(PaymentStatus)
  status?: PaymentStatus;
}
