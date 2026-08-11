import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { BillingService } from './billing.service';
import { RazorpayService } from './billing.service';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { TenantGuard } from '../common/guards/tenant.guard';
import { CurrentUser, AuthenticatedUser } from '../common/decorators/current-user.decorator';
import { Public } from '../common/decorators/public.decorator';

@Controller('billing')
export class BillingController {
  constructor(private readonly billing: BillingService) {}

  @Public()
  @Get('plans')
  plans() {
    return this.billing.catalog();
  }

  @UseGuards(JwtAuthGuard, TenantGuard)
  @Get('subscription')
  subscription(@CurrentUser() u: AuthenticatedUser) {
    return this.billing.subscription(u.companyId);
  }

  @UseGuards(JwtAuthGuard, TenantGuard)
  @Post('checkout/plan')
  checkoutPlan(@CurrentUser() u: AuthenticatedUser, @Body() body: { planId: string }) {
    return this.billing.createSubscriptionOrder(u.companyId, body.planId);
  }

  @UseGuards(JwtAuthGuard, TenantGuard)
  @Post('checkout/verify')
  verify(
    @CurrentUser() u: AuthenticatedUser,
    @Body()
    body: {
      planId: string;
      razorpay_order_id: string;
      razorpay_payment_id: string;
      razorpay_signature: string;
    },
  ) {
    return this.billing.verifyAndActivate(u.companyId, body);
  }

  @UseGuards(JwtAuthGuard, TenantGuard)
  @Post('checkout/scan-pack')
  scanPack(@CurrentUser() u: AuthenticatedUser, @Body() body: { packId: string }) {
    return this.billing.createScanPackOrder(u.companyId, body.packId);
  }
}
