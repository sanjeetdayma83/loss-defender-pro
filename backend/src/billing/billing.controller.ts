import { Controller, Get, Patch, Body } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CurrentUser, AuthenticatedUser } from '../common/decorators/current-user.decorator';
import { Public } from '../common/decorators/public.decorator';

const PLANS = [
  { id: 'free', name: 'Free', storageQuota: 10737418240 },
  { id: 'pro', name: 'Pro', storageQuota: 214748364800 },
  { id: 'enterprise', name: 'Enterprise', storageQuota: 2199023255552 },
];

@Controller('billing')
export class BillingController {
  constructor(private readonly prisma: PrismaService) {}

  @Public()
  @Get('plans')
  plans() { return PLANS; }

  @Get('subscription')
  async subscription(@CurrentUser() u: AuthenticatedUser) {
    const c = await this.prisma.company.findFirst({ where: { id: u.companyId } });
    return {
      plan: (c as any)?.plan || 'free',
      storageUsed: String((c as any)?.storageUsed ?? 0),
      storageQuota: String((c as any)?.storageQuota ?? 0),
      note: 'No payment provider — Company.plan field only',
    };
  }

  @Patch('subscription')
  async setPlan(@CurrentUser() u: AuthenticatedUser, @Body() body: { plan: string }) {
    const plan = PLANS.find((p) => p.id === body.plan);
    if (!plan) return { error: 'unknown plan' };
    await this.prisma.company.update({
      where: { id: u.companyId },
      data: { plan: plan.id as any, storageQuota: plan.storageQuota as any } as any,
    });
    return { plan: plan.id, message: 'updated' };
  }
}
