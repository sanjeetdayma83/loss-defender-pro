import { BadRequestException, ForbiddenException, Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

export const PLAN_LIMITS = {
  free: { storageQuota: 10 * 1024 ** 3, monthlyOrders: 500 },
  starter: { storageQuota: 50 * 1024 ** 3, monthlyOrders: 5000 },
  professional: { storageQuota: 200 * 1024 ** 3, monthlyOrders: 25000 },
  business: { storageQuota: 1024 * 1024 ** 3, monthlyOrders: 100000 },
  enterprise: { storageQuota: 5 * 1024 ** 4, monthlyOrders: Number.MAX_SAFE_INTEGER },
} as const;

@Injectable()
export class BillingService {
  constructor(private readonly prisma: PrismaService) {}

  async getCompany(companyId: string) {
    const company = await this.prisma.company.findFirst({ where: { id: companyId, status: 'active' } });
    if (!company) throw new BadRequestException('Company not found');
    const plan = PLAN_LIMITS[company.plan as keyof typeof PLAN_LIMITS] ?? PLAN_LIMITS.free;
    return { company, limits: plan };
  }

  async assertOrderQuota(companyId: string) {
    const { company, limits } = await this.getCompany(companyId);
    const start = new Date(); start.setUTCDate(1); start.setUTCHours(0, 0, 0, 0);
    const count = await this.prisma.order.count({ where: { companyId, createdAt: { gte: start } } });
    if (count >= limits.monthlyOrders) throw new ForbiddenException('Monthly order quota exceeded for the current plan');
    return { allowed: true, used: count, limit: limits.monthlyOrders };
  }

  async assertStorageQuota(companyId: string, additionalBytes: number) {
    if (!Number.isFinite(additionalBytes) || additionalBytes < 0) throw new BadRequestException('Invalid storage increment');
    const { company, limits } = await this.getCompany(companyId);
    const used = Number(company.storageUsed);
    if (used + additionalBytes > limits.storageQuota) throw new ForbiddenException('Storage quota exceeded for the current plan');
    return { allowed: true, used, additionalBytes, limit: limits.storageQuota };
  }

  async usage(companyId: string) {
    const { company, limits } = await this.getCompany(companyId);
    const start = new Date(); start.setUTCDate(1); start.setUTCHours(0, 0, 0, 0);
    const monthlyOrders = await this.prisma.order.count({ where: { companyId, createdAt: { gte: start } } });
    return { plan: company.plan, storageUsed: Number(company.storageUsed), storageQuota: limits.storageQuota, monthlyOrders, monthlyOrderQuota: limits.monthlyOrders };
  }
}
