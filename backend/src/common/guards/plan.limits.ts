import {
  Injectable, CanActivate, ExecutionContext, ForbiddenException,
} from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

const LIMITS: Record<string, { users: number; warehouses: number; storageGb: number }> = {
  free: { users: 5, warehouses: 1, storageGb: 5 },
  starter: { users: 25, warehouses: 5, storageGb: 50 },
  professional: { users: 100, warehouses: 20, storageGb: 500 },
  enterprise: { users: 10000, warehouses: 1000, storageGb: 10000 },
};

@Injectable()
export class PlanGuard implements CanActivate {
  constructor(private readonly prisma: PrismaService) {}

  /** Use as method-level check helper, not only guard */
  async assertCanAddUser(companyId: string) {
    const company = await this.prisma.company.findFirst({ where: { id: companyId } });
    const plan = String((company as any)?.plan || 'free');
    const limits = LIMITS[plan] || LIMITS.free;
    const count = await this.prisma.user.count({
      where: { companyId, status: { not: 'deleted' } },
    });
    if (count >= limits.users) {
      throw new ForbiddenException(`User limit reached for plan ${plan} (${limits.users})`);
    }
  }

  async assertCanAddWarehouse(companyId: string) {
    const company = await this.prisma.company.findFirst({ where: { id: companyId } });
    const plan = String((company as any)?.plan || 'free');
    const limits = LIMITS[plan] || LIMITS.free;
    const count = await this.prisma.warehouse.count({
      where: { companyId, status: { not: 'deleted' } as any },
    });
    if (count >= limits.warehouses) {
      throw new ForbiddenException(`Warehouse limit reached for plan ${plan}`);
    }
  }

  canActivate(_ctx: ExecutionContext) {
    return true; // optional route guard; prefer explicit service calls
  }
}
