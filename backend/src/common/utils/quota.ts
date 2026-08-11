import { ForbiddenException } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

const LIMITS: Record<string, { users: number; warehouses: number }> = {
  free: { users: 5, warehouses: 1 },
  starter: { users: 3, warehouses: 1 },
  growth: { users: 25, warehouses: 5 },
  enterprise: { users: 1000, warehouses: 100 },
};

export async function assertCanAddUser(prisma: PrismaClient, companyId: string) {
  const company = await prisma.company.findFirst({ where: { id: companyId } });
  const plan = String((company as any)?.plan || 'free').toLowerCase();
  const max = LIMITS[plan]?.users ?? LIMITS.free.users;
  const count = await prisma.user.count({
    where: { companyId, status: { not: 'deleted' } },
  });
  if (count >= max) {
    throw new ForbiddenException(`User limit reached for plan ${plan} (${max})`);
  }
}

export async function assertCanAddWarehouse(prisma: PrismaClient, companyId: string) {
  const company = await prisma.company.findFirst({ where: { id: companyId } });
  const plan = String((company as any)?.plan || 'free').toLowerCase();
  const max = LIMITS[plan]?.warehouses ?? 1;
  const count = await prisma.warehouse.count({
    where: { companyId } as any,
  });
  if (count >= max) {
    throw new ForbiddenException(`Warehouse limit reached for plan ${plan} (${max})`);
  }
}
