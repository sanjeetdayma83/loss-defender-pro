import { IsOptional, IsString, IsObject, MaxLength } from 'class-validator';

export class UpdateCompanyDto {
  @IsOptional() @IsString() @MaxLength(200)
  companyName?: string;

  @IsOptional() @IsString() @MaxLength(20)
  gst?: string;

  @IsOptional() @IsString() @MaxLength(20)
  pan?: string;

  @IsOptional() @IsObject()
  address?: Record<string, unknown>;

  @IsOptional() @IsString() @MaxLength(20)
  phone?: string;

  @IsOptional() @IsString() @MaxLength(200)
  website?: string;

  @IsOptional() @IsString() @MaxLength(64)
  timezone?: string;

  @IsOptional() @IsString() @MaxLength(8)
  currency?: string;

  @IsOptional() @IsString()
  logo?: string;
}
