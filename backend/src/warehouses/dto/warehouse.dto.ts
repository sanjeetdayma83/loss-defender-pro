import { IsString, IsOptional, IsObject, IsEnum, MaxLength, MinLength } from 'class-validator';
import { WarehouseStatus, StationStatus } from '@prisma/client';

export class CreateWarehouseDto {
  @IsString() @MinLength(2) @MaxLength(120)
  name: string;

  @IsString() @MinLength(2) @MaxLength(32)
  code: string;

  @IsObject()
  address: Record<string, unknown>;

  @IsString() @MaxLength(80)
  city: string;

  @IsString() @MaxLength(80)
  state: string;

  @IsOptional() @IsString() @MaxLength(80)
  country?: string;

  @IsOptional() @IsString() @MaxLength(64)
  timezone?: string;
}

export class UpdateWarehouseDto {
  @IsOptional() @IsString() @MinLength(2) @MaxLength(120)
  name?: string;

  @IsOptional() @IsObject()
  address?: Record<string, unknown>;

  @IsOptional() @IsString() @MaxLength(80)
  city?: string;

  @IsOptional() @IsString() @MaxLength(80)
  state?: string;

  @IsOptional() @IsString() @MaxLength(80)
  country?: string;

  @IsOptional() @IsString() @MaxLength(64)
  timezone?: string;

  @IsOptional() @IsEnum(WarehouseStatus)
  status?: WarehouseStatus;
}

export class CreateStationDto {
  @IsString() @MinLength(2) @MaxLength(80)
  stationName: string;

  @IsString() @MinLength(2) @MaxLength(40)
  stationId: string;

  @IsOptional() @IsObject()
  camera?: Record<string, unknown>;

  @IsOptional() @IsObject()
  scanner?: Record<string, unknown>;

  @IsOptional() @IsObject()
  printer?: Record<string, unknown>;
}

export class UpdateStationDto {
  @IsOptional() @IsString() @MinLength(2) @MaxLength(80)
  stationName?: string;

  @IsOptional() @IsObject()
  camera?: Record<string, unknown>;

  @IsOptional() @IsObject()
  scanner?: Record<string, unknown>;

  @IsOptional() @IsObject()
  printer?: Record<string, unknown>;

  @IsOptional() @IsEnum(StationStatus)
  status?: StationStatus;
}
