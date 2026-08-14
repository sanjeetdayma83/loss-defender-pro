import { Injectable, NotFoundException, BadRequestException, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { warehouseScope, assertWarehouseAccess } from '../common/utils/warehouse-scope';

const ALLOWED: Record<string, string[]> = {
  requested: ['received', 'rejected', 'closed'],
  received: ['inspecting', 'rejected', 'closed'],
  inspecting: ['refunded', 'restocked', 'rejected', 'closed'],
  refunded: ['closed'],
  restocked: ['closed'],
  rejected: ['closed'],
  closed: [],
};

@Injectable()
export class ReturnsService {
  constructor(private readonly prisma: PrismaService) {}

  list(companyId: string, user?: { role?: string; warehouseId?: string | null }) {
    return this.prisma.return.findMany({
      where: { companyId, ...warehouseScope(user || {}, {}) },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
  }

  async create(companyId: string, data: { orderId: string; reason?: string; notes?: string }, user?: { role?: string; warehouseId?: string | null }) {
    const o = await this.prisma.order.findFirst({ where: { id: data.orderId, companyId } });
    if (!o) throw new NotFoundException('Order not found');
    assertWarehouseAccess(user || {}, o.warehouseId);
    return this.prisma.return.create({
      data: {
        companyId,
        orderId: data.orderId,
        reason: data.reason ?? 'customer_return',
        status: 'requested',
        conditionNote: data.notes,
      } as any,
    });
  }

  async updateStatus(companyId: string, id: string, status: string, user?: { role?: string; warehouseId?: string | null }) {
    const row = await this.prisma.return.findFirst({ 
      where: { id, companyId, ...warehouseScope(user || {}, {}) },
      include: { order: true }
    });
    if (!row) throw new NotFoundException('Return not found');
    assertWarehouseAccess(user || {}, (row as any).order?.warehouseId);
    const next = ALLOWED[row.status as string] || [];
    if (!next.includes(status)) {
      throw new BadRequestException(`Cannot ${row.status} → ${status}. Allowed: ${next.join(', ') || 'none'}`);
    }
    const data: any = { status };
    if (status === 'closed') data.closedAt = new Date();
    return this.prisma.return.update({ where: { id }, data });
  }
}