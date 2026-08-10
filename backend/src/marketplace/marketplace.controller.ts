import {
  Body, Controller, Delete, Get, Headers, Param, Post,
} from '@nestjs/common';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';
import { MarketplaceService } from './marketplace.service';
import { CurrentUser, AuthenticatedUser } from '../common/decorators/current-user.decorator';
import { Public } from '../common/decorators/public.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { Role } from '@prisma/client';
import { IsOptional, IsString } from 'class-validator';
import { QUEUE_MARKETPLACE_SYNC } from './marketplace-sync.constants';

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
class SyncDto { @IsOptional() @IsString() provider?: string; }
const MARKETPLACE_MANAGERS = [Role.owner, Role.manager, Role.marketplace_manager, Role.super_admin];

@Controller('marketplace')
export class MarketplaceController {
  constructor(
    private readonly service: MarketplaceService,
    @InjectQueue(QUEUE_MARKETPLACE_SYNC) private readonly syncQueue: Queue,
  ) {}

  @Get('connections') @Roles(...MARKETPLACE_MANAGERS)
  list(@CurrentUser() u: AuthenticatedUser) { return this.service.list(u.companyId); }

  @Post('connect') @Roles(...MARKETPLACE_MANAGERS)
  connect(@CurrentUser() u: AuthenticatedUser, @Body() dto: ConnectMarketplaceDto) { return this.service.connect(u.companyId, dto); }

  @Delete('connections/:id') @Roles(...MARKETPLACE_MANAGERS)
  disconnect(@CurrentUser() u: AuthenticatedUser, @Param('id') id: string) { return this.service.disconnect(u.companyId, id); }

  @Post('sync') @Roles(...MARKETPLACE_MANAGERS)
  async sync(@CurrentUser() u: AuthenticatedUser, @Body() body: SyncDto) {
    const provider = body?.provider || 'amazon';
    const job = await this.syncQueue.add('sync-orders', { companyId: u.companyId, provider }, {
      jobId: `marketplace:${u.companyId}:${provider}:${Date.now()}`,
      attempts: 5,
      backoff: { type: 'exponential', delay: 5000 },
      removeOnComplete: { age: 86400, count: 1000 },
      removeOnFail: { age: 604800, count: 5000 },
    });
    return { queued: true, jobId: job.id, provider, status: 'queued' };
  }

  @Public() @Post('webhooks/:provider')
  webhook(@Param('provider') provider: string, @Body() body: any, @Headers('x-webhook-secret') secret?: string, @Headers('x-signature') signature?: string) {
    return this.service.handleWebhook(provider, body, secret || signature);
  }
}
