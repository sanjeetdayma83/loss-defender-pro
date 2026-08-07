import { IsString, IsOptional, IsUUID, IsArray } from 'class-validator';

export class CreateClaimDto {
  @IsUUID()
  orderId: string;

  @IsString()
  reason: string;

  @IsOptional()
  @IsString()
  marketplace?: string;

  @IsOptional()
  @IsString()
  description?: string;

  @IsOptional()
  @IsArray()
  evidenceIds?: string[];
}