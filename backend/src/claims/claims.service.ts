import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

const ALLOWED: Record<string, string[]> = {
  open: ['under_review', 'approved', 'rejected', 'closed'],
  under_review: ['approved', 'rejected', 'closed'],
  approved: ['closed'],
  rejected: ['closed'],
  closed: [],
  // fallback for older statuses
  pending: ['under_review', 'approved', 'rejected', 'closed'],
};

@Injectable()
export class ClaimsService {
  constructor(private readonly prisma: PrismaService) {}

  list(companyId: string) {
    return this.prisma.claim.findMany({
      where: { companyId },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
  }

  async getOne(companyId: string, id: string) {
    const row = await this.prisma.claim.findFirst({ where: { id, companyId } });
    if (!row) throw new NotFoundException('Claim not found');
    return row;
  }

  async updateStatus(companyId: string, actorId: string, id: string, status: string, decisionNote?: string) {
    const row = await this.prisma.claim.findFirst({ where: { id, companyId } });
    if (!row) throw new NotFoundException('Claim not found');

    const cur = (row.status as string) || 'open';
    const next = ALLOWED[cur] || ALLOWED['open'] || [];
    if (!next.includes(status) && cur !== status) {
      throw new BadRequestException(`Cannot transition ${cur} → ${status}. Allowed: ${next.join(', ') || 'none'}`);
    }

    const data: any = { status };
    if (decisionNote) data.decisionNote = decisionNote;
    if (status === 'closed' || status === 'approved' || status === 'rejected') {
      data.closedAt = new Date();
    }

    const updated = await this.prisma.claim.update({ where: { id }, data });

    await this.writeAudit(companyId, actorId, 'claim.status', 'Claim', id, { from: cur, to: status });
    return updated;
  }

  private async writeAudit(companyId: string, actorId: string, action: string, entity: string, entityId: string, meta?: any) {
    try {
      await this.prisma.auditLog.create({
        data: {
          companyId,
          actorId,
          action,
          entity,
          entityId,
          meta: meta ?? {},
        } as any,
      });
    } catch (_) {}
  }
}
