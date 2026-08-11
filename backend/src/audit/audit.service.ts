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

const SENSITIVE_KEYS = new Set([
  'password',
  'passwordhash',
  'currentpassword',
  'newpassword',
  'temppassword',
  'temporarypassword',
  'devcode',
  'invitetoken',
  'refreshtoken',
  'accesstoken',
  'secret',
  'webhooksecret',
  'clientsecret',
  'apisecret',
  'awssecretaccesskey',
]);

function redact(value: any, depth = 0): any {
  if (depth > 8 || value == null) return value;
  if (Array.isArray(value)) return value.map((item) => redact(item, depth + 1));
  if (typeof value !== 'object') return value;
  const out: any = {};
  for (const [key, val] of Object.entries(value)) {
    if (SENSITIVE_KEYS.has(key.toLowerCase())) continue;
    out[key] = redact(val, depth + 1);
  }
  return out;
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
          before: redact(payload.before ?? null),
          after: redact(payload.after ?? payload.meta ?? null),
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