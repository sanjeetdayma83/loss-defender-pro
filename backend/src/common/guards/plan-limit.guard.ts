import { Injectable, CanActivate, ExecutionContext, ForbiddenException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { PrismaService } from '../../prisma/prisma.service';
import { AuthenticatedUser } from '../../common/decorators/current-user.decorator';

export const PLAN_LIMIT_KEY = 'planLimit';
export const RequirePlanLimit = (feature: string) => 
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  require('@nestjs/common').SetMetadata(PLAN_LIMIT_KEY, feature);

const PLAN_LIMITS = {
  free: {
    scansPerPeriod: 500,
    storageGb: 5,
    warehouses: 1,
    users: 2,
    videoRetentionDays: 7,
  },
  starter: {
    scansPerPeriod: 5100,
    storageGb: 50,
    warehouses: 1,
    users: 3,
    videoRetentionDays: 30,
  },
  professional: {
    scansPerPeriod: 22200,
    storageGb: 200,
    warehouses: 3,
    users: 10,
    videoRetentionDays: 30,
  },
  business: {
    scansPerPeriod: 56200,
    storageGb: 500,
    warehouses: 10,
    users: 25,
    videoRetentionDays: 30,
  },
  enterprise: {
    scansPerPeriod: -1, // unlimited
    storageGb: -1,
    warehouses: -1,
    users: -1,
    videoRetentionDays: 365,
  },
};

@Injectable()
export class PlanLimitGuard implements CanActivate {
  constructor(private readonly prisma: PrismaService, private readonly reflector: Reflector) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const feature = this.reflector.get<string>(PLAN_LIMIT_KEY, ctx.getHandler());
    if (!feature) return true;

    const req = ctx.switchToHttp().getRequest();
    const user = req.user as AuthenticatedUser;
    if (!user?.companyId) return true;

    const company = await this.prisma.company.findFirst({
      where: { id: user.companyId },
      select: { plan: true, storageUsed: true, storageQuota: true },
    });

    if (!company) return true;

    const plan = (company as any).plan || 'free';
    const limits = PLAN_LIMITS[plan as keyof typeof PLAN_LIMITS] || PLAN_LIMITS.free;

    // Check scan quota - use orders/items as proxy since scan tracking is per order item
    if (feature === 'scan' || feature === 'scanner') {
      const scanQuota = limits.scansPerPeriod;
      if (scanQuota > 0) {
        // Count total scanned items this period as proxy
        const scannedCount = await this.prisma.orderItem.count({
          where: { order: { companyId: user.companyId }, status: 'matched' },
        });
        if (scannedCount >= scanQuota) {
          throw new ForbiddenException({
            code: 'PLAN_LIMIT_EXCEEDED',
            message: `Scan limit reached (${scannedCount}/${scanQuota}). Upgrade your plan to continue scanning.`,
            feature: 'scan',
            current: scannedCount,
            limit: scanQuota,
            plan,
          });
        }
      }
    }

    // Check storage quota
    if (feature === 'storage' || feature === 'recording' || feature === 'evidence') {
      const storageQuota = Number((company as any).storageQuota ?? limits.storageGb * 1024 * 1024 * 1024);
      const storageUsed = Number((company as any).storageUsed ?? 0);
      if (storageQuota > 0 && storageUsed >= storageQuota) {
        throw new ForbiddenException({
          code: 'PLAN_LIMIT_EXCEEDED',
          message: `Storage limit reached (${this.formatBytes(storageUsed)}/${this.formatBytes(storageQuota)}). Upgrade your plan for more storage.`,
          feature: 'storage',
          current: storageUsed,
          limit: storageQuota,
          plan,
        });
      }
    }

    // Check warehouse limit
    if (feature === 'warehouse') {
      const warehouseCount = await this.prisma.warehouse.count({ where: { companyId: user.companyId, status: 'active' } });
      if (limits.warehouses > 0 && warehouseCount >= limits.warehouses) {
        throw new ForbiddenException({
          code: 'PLAN_LIMIT_EXCEEDED',
          message: `Warehouse limit reached (${warehouseCount}/${limits.warehouses}). Upgrade your plan to add more warehouses.`,
          feature: 'warehouse',
          current: warehouseCount,
          limit: limits.warehouses,
          plan,
        });
      }
    }

    // Check user limit
    if (feature === 'user') {
      const userCount = await this.prisma.user.count({ where: { companyId: user.companyId, status: { not: 'deleted' } } });
      if (limits.users > 0 && userCount >= limits.users) {
        throw new ForbiddenException({
          code: 'PLAN_LIMIT_EXCEEDED',
          message: `User limit reached (${userCount}/${limits.users}). Upgrade your plan to add more team members.`,
          feature: 'user',
          current: userCount,
          limit: limits.users,
          plan,
        });
      }
    }

    return true;
  }

  private formatBytes(bytes: number): string {
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    if (bytes < 1024 * 1024 * 1024) return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
    return `${(bytes / (1024 * 1024 * 1024)).toFixed(2)} GB`;
  }
}