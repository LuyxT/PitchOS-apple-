import { Transform } from 'class-transformer';
import { IsInt, IsOptional, IsString, Max, Min } from 'class-validator';

export class PaginationQueryDto {
  @IsOptional()
  @IsString()
  cursor?: string;

  @IsOptional()
  @Transform(({ value }) => (value == null ? 50 : Number(value)))
  @IsInt()
  @Min(1)
  @Max(100)
  limit = 50;
}
