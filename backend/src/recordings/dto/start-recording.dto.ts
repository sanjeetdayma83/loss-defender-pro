import { IsString, IsOptional, IsUUID } from 'class-validator';

export class StartRecordingDto {
  @IsUUID()
  orderId: string;

  @IsUUID()
  warehouseId: string;

  @IsOptional()
  @IsUUID()
  stationId?: string;
}