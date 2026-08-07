import { IsString, IsInt, IsOptional, Min } from 'class-validator';

export class AddSegmentDto {
  @IsInt()
  @Min(0)
  sequence: number;

  @IsString()
  b2Key: string;

  @IsString()
  sizeBytes: string; // BigInt as string

  @IsOptional()
  @IsInt()
  durationSec?: number;

  @IsOptional()
  @IsString()
  checksum?: string;
}