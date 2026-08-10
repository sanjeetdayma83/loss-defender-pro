import { ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

export async function assertUserQuota(prisma: PrismaService, companyId: string) {
  const c = await prisma.company.findFirst({ where: { id: companyId } });
  if (!c) return;
  const limit = (c as any).userLimit ?? (c as any).maxUsers;
  if (limit == null) return;
  const count = await prisma.user.count({ where: { companyId } });
  if (count >= Number(limit)) {
    throw new ForbiddenException(`User quota reached (${count}/${limit})`);
  }
}

export async function assertWarehouseQuota(prisma: PrismaService, companyId: string) {
  const c = await prisma.company.findFirst({ where: { id: companyId } });
  if (!c) return;
  const limit = (c as any).warehouseLimit ?? (c as any).maxWarehouses;
  if (limit == null) return;
  const count = await prisma.warehouse.count({ where: { companyId } });
  if (count >= Number(limit)) {
    throw new ForbiddenException(`Warehouse quota reached (${count}/${limit})`);
  }
}

export async function assertStorageQuota(prisma: PrismaService, companyId: string, addBytes = 0) {
  const c = await prisma.company.findFirst({ where: { id: companyId } });
  if (!c) return;
  const used = Number((c as any).storageUsed ?? 0);
  const quota = Number((c as any).storageQuota ?? 0);
  if (quota > 0 && used + addBytes > quota) {
    throw new ForbiddenException(`Storage quota exceeded (${used}/${quota})`);
  }
}
