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

@Controller('marketplace')
export class MarketplaceController {
  constructor(private readonly service: MarketplaceService) {}

  @Get('connections')
  list(@CurrentUser() u: AuthenticatedUser) {
    return this.service.list(u.companyId);
  }

  @Post('connect')
  connect(@CurrentUser() u: AuthenticatedUser, @Body() dto: ConnectMarketplaceDto) {
    return this.service.connect(u.companyId, dto);
  }

  @Delete('connections/:id')
  disconnect(@CurrentUser() u: AuthenticatedUser, @Param('id') id: string) {
    return this.service.disconnect(u.companyId, id);
  }

  @Post('sync')
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
    return this.service.handleWebhook(
      provider,
      body,
      secret || signature,
    );
  }
}
