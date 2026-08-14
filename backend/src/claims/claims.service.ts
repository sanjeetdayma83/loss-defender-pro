import { Injectable, NotFoundException, BadRequestException, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { warehouseScope, assertWarehouseAccess } from '../common/utils/warehouse-scope';

const ALLOWED: Record<string, string[]> = {
  open: ['under_review', 'approved', 'rejected', 'closed'],
  under_review: ['approved', 'rejected', 'closed'],
  approved: ['closed'],
  rejected: ['closed'],
  closed: [],
  pending: ['under_review', 'approved', 'rejected', 'closed'],
};

@Injectable()
export class ClaimsService {
  constructor(private readonly prisma: PrismaService) {}

  list(companyId: string, user?: { role?: string; warehouseId?: string | null }) {
    return this.prisma.claim.findMany({
      where: { companyId, ...warehouseScope(user || {}, {}) },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
  }

  async getOne(companyId: string, id: string, user?: { role?: string; warehouseId?: string | null }) {
    const row = await this.prisma.claim.findFirst({ 
      where: { id, companyId, ...warehouseScope(user || {}, {}) },
      include: { order: true }
    });
    if (!row) throw new NotFoundException('Claim not found');
    assertWarehouseAccess(user || {}, (row as any).order?.warehouseId);
    return row;
  }

  async create(
    companyId: string,
    actorId: string,
    data: { orderId: string; reason?: string; description?: string; marketplace?: string },
    user?: { role?: string; warehouseId?: string | null },
  ) {
    const order = await this.prisma.order.findFirst({ where: { id: data.orderId, companyId } });
    if (!order) throw new NotFoundException('Order not found');
    assertWarehouseAccess(user || {}, order.warehouseId);

    const claim = await this.prisma.claim.create({
      data: {
        companyId,
        orderId: data.orderId,
        reason: data.reason ?? 'unspecified',
        description: data.description,
        marketplace: data.marketplace,
        status: 'open',
      } as any,
    });

    await this.writeAudit(companyId, actorId, 'claim.create', 'Claim', claim.id, {
      orderId: data.orderId,
      reason: data.reason,
    });

    return claim;
  }

  async updateStatus(
    companyId: string,
    actorId: string,
    id: string,
    status: string,
    decisionNote?: string,
    user?: { role?: string; warehouseId?: string | null },
  ) {
    const row = await this.prisma.claim.findFirst({ 
      where: { id, companyId, ...warehouseScope(user || {}, {}) },
      include: { order: true }
    });
    if (!row) throw new NotFoundException('Claim not found');
    assertWarehouseAccess(user || {}, (row as any).order?.warehouseId);

    const cur = (row.status as string) || 'open';
    const next = ALLOWED[cur] || ALLOWED['open'] || [];
    if (!next.includes(status) && cur !== status) {
      throw new BadRequestException(
        `Cannot transition ${cur} → ${status}. Allowed: ${next.join(', ') || 'none'}`,
      );
    }

    const data: any = { status };
    if (decisionNote) data.decisionNote = decisionNote;
    if (['closed', 'approved', 'rejected'].includes(status)) {
      data.closedAt = new Date();
    }

    const updated = await this.prisma.claim.update({ where: { id }, data });

    await this.writeAudit(companyId, actorId, 'claim.status', 'Claim', id, {
      from: cur,
      to: status,
    });

    return updated;
  }

  private async writeAudit(
    companyId: string,
    actorId: string | null,
    action: string,
    entity: string,
    entityId: string,
    after?: any,
  ) {
    try {
      await this.prisma.auditLog.create({
        data: {
          companyId,
          actorId: actorId || null,
          action,
          entity,
          entityId,
          after: after ?? null,
        },
      });
    } catch (e: any) {
      console.warn('audit write failed', e?.message);
    }
  }
}
