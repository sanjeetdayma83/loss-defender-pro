import { Controller, Get, Patch, Body, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CurrentUser, AuthenticatedUser } from '../common/decorators/current-user.decorator';
import { Public } from '../common/decorators/public.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { Role } from '@prisma/client';
import { BillingService } from './billing.service';

const PLANS = [
  { id: 'free', name: 'Free', storageQuota: 10 * 1024 ** 3, monthlyOrders: 500 },
  { id: 'starter', name: 'Starter', storageQuota: 50 * 1024 ** 3, monthlyOrders: 5000 },
  { id: 'professional', name: 'Professional', storageQuota: 200 * 1024 ** 3, monthlyOrders: 25000 },
  { id: 'business', name: 'Business', storageQuota: 1024 * 1024 ** 3, monthlyOrders: 100000 },
  { id: 'enterprise', name: 'Enterprise', storageQuota: 5 * 1024 ** 4, monthlyOrders: Number.MAX_SAFE_INTEGER },
];

@Controller('billing')
export class BillingController {
  constructor(private readonly prisma: PrismaService, private readonly billing: BillingService) {}
  @Public() @Get('plans') plans() { return PLANS; }
  @Get('subscription') async subscription(@CurrentUser() u: AuthenticatedUser) { return this.billing.usage(u.companyId); }
  @Patch('subscription') @Roles(Role.owner, Role.super_admin)
  async setPlan(@CurrentUser() u: AuthenticatedUser, @Body() body: { plan: string }) {
    const plan = PLANS.find((p) => p.id === body.plan); if (!plan) throw new ForbiddenException('Unknown plan');
    await this.prisma.company.update({ where: { id: u.companyId }, data: { plan: plan.id as any, storageQuota: plan.storageQuota as any } });
    return { plan: plan.id, storageQuota: plan.storageQuota, monthlyOrders: plan.monthlyOrders, message: 'updated' };
  }
}
