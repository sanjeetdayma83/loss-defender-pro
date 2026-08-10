import {
  Body,
  Controller,
  Delete,
  Get,
  Headers,
  Param,
  Post,
} from '@nestjs/common';
import { MarketplaceService } from './marketplace.service';
import { CurrentUser, AuthenticatedUser } from '../common/decorators/current-user.decorator';
import { Public } from '../common/decorators/public.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { Role } from '@prisma/client';
import { IsOptional, IsString } from 'class-validator';

class ConnectMarketplaceDto {
  @IsString() provider: string;
  @IsOptional() @IsString() storeName?: string;
  @IsOptional() @IsString() externalId?: string;
  @IsOptional() @IsString() externalAccountId?: string;
  @IsOptional() @IsString() accessToken?: string;
  @IsOptional() @IsString() refreshToken?: string;
  @IsOptional() @IsString() webhookSecret?: string;
  @IsOptional() credentials?: any;
}

class SyncDto {
  @IsOptional() @IsString() provider?: string;
}

const MARKETPLACE_MANAGERS = [
  Role.owner,
  Role.manager,
  Role.marketplace_manager,
  Role.super_admin,
];

@Controller('marketplace')
export class MarketplaceController {
  constructor(private readonly service: MarketplaceService) {}

  @Get('connections')
  @Roles(...MARKETPLACE_MANAGERS)
  list(@CurrentUser() u: AuthenticatedUser) {
    return this.service.list(u.companyId);
  }

  @Post('connect')
  @Roles(...MARKETPLACE_MANAGERS)
  connect(@CurrentUser() u: AuthenticatedUser, @Body() dto: ConnectMarketplaceDto) {
    return this.service.connect(u.companyId, dto);
  }

  @Delete('connections/:id')
  @Roles(...MARKETPLACE_MANAGERS)
  disconnect(@CurrentUser() u: AuthenticatedUser, @Param('id') id: string) {
    return this.service.disconnect(u.companyId, id);
  }

  @Post('sync')
  @Roles(...MARKETPLACE_MANAGERS)
  sync(@CurrentUser() u: AuthenticatedUser, @Body() body: SyncDto) {
    return this.service.syncOrders(u.companyId, body?.provider || 'amazon');
  }

  @Public()
  @Post('webhooks/:provider')
  webhook(
    @Param('provider') provider: string,
    @Body() body: any,
    @Headers('x-webhook-secret') secret?: string,
    @Headers('x-signature') signature?: string,
  ) {
    return this.service.handleWebhook(provider, body, secret || signature);
  }
}
