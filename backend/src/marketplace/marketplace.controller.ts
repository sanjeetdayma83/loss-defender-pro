import {
  Body, Controller, Delete, Get, Headers, Param, Post, UseGuards,
} from '@nestjs/common';
import { MarketplaceService } from './marketplace.service';
import { ConnectMarketplaceDto } from './dto/connect-marketplace.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { TenantGuard } from '../common/guards/tenant.guard';
import { CurrentUser, AuthenticatedUser } from '../common/decorators/current-user.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { Role } from '@prisma/client';
import { Public } from '../common/decorators/public.decorator';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';

@ApiTags('marketplace')
@Controller('marketplace')
export class MarketplaceController {
  constructor(private readonly service: MarketplaceService) {}

  @Get('oauth/:provider/start')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, TenantGuard)
  oauthStart(
    @Param('provider') provider: string,
    @CurrentUser() u: AuthenticatedUser,
  ) {
    const state = Buffer.from(
      [u.companyId, provider, String(Date.now())].join(':'),
    ).toString('base64url');
    return {
      provider,
      state,
      url:
        'https://example.com/oauth/' +
        provider +
        '?state=' +
        state +
        '&client_id=PENDING',
      note: 'Stub — wire real OAuth credentials later',
    };
  }

  @Get('connections')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, TenantGuard)
  list(@CurrentUser() u: AuthenticatedUser) {
    return this.service.list(u.companyId);
  }

  @Post('connect')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, TenantGuard)
  @Roles(Role.owner, Role.manager, Role.marketplace_manager, Role.super_admin)
  connect(
    @CurrentUser() u: AuthenticatedUser,
    @Body() dto: ConnectMarketplaceDto,
  ) {
    return this.service.connect(u.companyId, dto);
  }

  @Delete('connections/:id')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, TenantGuard)
  @Roles(Role.owner, Role.manager, Role.marketplace_manager, Role.super_admin)
  disconnect(
    @CurrentUser() u: AuthenticatedUser,
    @Param('id') id: string,
  ) {
    return this.service.disconnect(u.companyId, id);
  }

  @Public()
  @Post('webhooks/:provider')
  webhook(
    @Param('provider') provider: string,
    @Body() body: Record<string, unknown>,
    @Headers('x-webhook-secret') secret?: string,
  ) {
    return this.service.handleWebhook(provider, body, secret);
  }
}