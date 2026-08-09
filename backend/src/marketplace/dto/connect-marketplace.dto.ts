import { IsEnum, IsOptional, IsString, MinLength } from 'class-validator';
import { MarketplaceProvider } from '@prisma/client';

export class ConnectMarketplaceDto {
  @IsEnum(MarketplaceProvider)
  provider: MarketplaceProvider;

  @IsOptional() @IsString()
  storeName?: string;

  @IsOptional() @IsString()
  externalId?: string;

  @IsOptional() @IsString() @MinLength(4)
  accessToken?: string;

  @IsOptional() @IsString()
  refreshToken?: string;

  @IsOptional() @IsString()
  webhookSecret?: string;
}