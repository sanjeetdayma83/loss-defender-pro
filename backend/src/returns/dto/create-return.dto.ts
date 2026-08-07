import { IsString, IsOptional, IsUUID } from 'class-validator';

export class CreateReturnDto {
  @IsUUID()
  orderId: string;

  @IsOptional()
  @IsString()
  reason?: string;
}