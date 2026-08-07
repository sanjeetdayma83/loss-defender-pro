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
  [key: string]: any; // allow any extra fields
}

@Injectable()
export class AuditService {
  private readonly logger = new Logger(AuditService.name);

  constructor(private readonly prisma: PrismaService) {}

  /** Used by existing services & interceptor */
  async log(payload: AuditLogPayload) {
    try {
      const meta = {
        ...(payload.meta || {}),
        ...(payload.before !== undefined ? { before: payload.before } : {}),
        ...(payload.after !== undefined ? { after: payload.after } : {}),
      };

      await this.prisma.auditLog.create({
        data: {
          companyId: payload.companyId,
          actorId: payload.actorId ?? null,
          action: payload.action,
          entity: payload.entity,
          entityId: payload.entityId ?? null,
          meta,
          // if your schema has these columns, uncomment:
          // ipAddress: payload.ipAddress || payload.ip || null,
          // userAgent: payload.userAgent || null,
        } as any,
      });
    } catch (e: any) {
      this.logger.warn(`Audit log failed: ${e?.message}`);
    }
  }

  /** Used by AuditController */
  list(companyId: string, take = 50) {
    return this.prisma.auditLog.findMany({
      where: { companyId },
      orderBy: { createdAt: 'desc' },
      take,
    });
  }
}
