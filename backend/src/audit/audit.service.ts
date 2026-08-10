import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

export interface AuditLogPayload {
  companyId: string;
  actorId?: string | null;
  action: string;
  entity: string;
  entityId?: string | null;
  meta?: any;
  ip?: string | null;
  ipAddress?: string | null;
  userAgent?: string | null;
  before?: any;
  after?: any;
  [key: string]: any;
}

@Injectable()
export class AuditService {
  private readonly logger = new Logger(AuditService.name);

  constructor(private readonly prisma: PrismaService) {}

  async log(payload: AuditLogPayload) {
    try {
      await this.prisma.auditLog.create({
        data: {
          companyId: payload.companyId,
          actorId: payload.actorId ?? null,
          action: payload.action,
          entity: payload.entity,
          entityId: payload.entityId ?? null,
          before: payload.before ?? null,
          after: payload.after ?? payload.meta ?? null,
          ipAddress: payload.ipAddress || payload.ip || null,
        },
      });
    } catch (e: any) {
      this.logger.warn(`Audit log failed: ${e?.message}`);
    }
  }

  list(companyId: string, take = 50) {
    return this.prisma.auditLog.findMany({
      where: { companyId },
      orderBy: { createdAt: 'desc' },
      take,
    });
  }
}
