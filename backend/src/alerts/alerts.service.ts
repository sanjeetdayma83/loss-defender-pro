import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class AlertsService {
  constructor(private readonly prisma: PrismaService) {}

  async list(companyId: string) {
    // Prefer audit logs as alert feed if model exists
    try {
      const logs = await this.prisma.auditLog.findMany({
        where: { companyId },
        orderBy: { createdAt: 'desc' },
        take: 30,
      });
      return logs.map((l: any) => ({
        id: l.id,
        type: l.action ?? l.entity ?? 'audit',
        message: `${l.action ?? 'event'} on ${l.entity ?? 'resource'}`,
        severity: 'info',
        createdAt: l.createdAt,
      }));
    } catch {
      return [];
    }
  }
}
