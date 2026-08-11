import { ForbiddenException } from '@nestjs/common';
import { planById, PLANS } from '../../billing/plans.catalog';

export async function assertUserQuota(prisma: any, companyId: string) {
  const c = await prisma.company.findFirst({ where: { id: companyId } });
  const planId = (c as any)?.plan || 'starter';
  const plan = planById(planId) || PLANS[0];
  const count = await prisma.user.count({ where: { companyId } });
  if (count >= plan.userLimit) {
    throw new ForbiddenException(`User limit reached for plan ${plan.name} (${plan.userLimit})`);
  }
}

export async function assertWarehouseQuota(prisma: any, companyId: string) {
  const c = await prisma.company.findFirst({ where: { id: companyId } });
  const planId = (c as any)?.plan || 'starter';
  const plan = planById(planId) || PLANS[0];
  const count = await prisma.warehouse.count({ where: { companyId } });
  if (count >= plan.warehouseLimit) {
    throw new ForbiddenException(`Warehouse limit reached for plan ${plan.name} (${plan.warehouseLimit})`);
  }
}
