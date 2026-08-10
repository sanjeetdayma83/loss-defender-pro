import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class AnalyticsService {
  constructor(private readonly prisma: PrismaService) {}
  async kpis(companyId: string) {
    const ordersTotal = await this.prisma.order.count({ where: { companyId } });
    const ordersDispatched = await this.prisma.order.count({ where: { companyId, status: 'dispatched' as any } });
    const evidence = await this.prisma.evidence.count({ where: { companyId } });
    const recordings = await this.prisma.recording.count({ where: { companyId } });
    const claimsOpen = await this.prisma.claim.count({ where: { companyId } }).catch(() => 0);
    const returnsOpen = await this.prisma.return.count({ where: { companyId } }).catch(() => 0);
    return {
      ordersTotal,
      ordersDispatched,
      evidence,
      recordings,
      claimsOpen,
      returnsOpen,
      evidenceCoverage: ordersTotal === 0 ? 0 : Math.round((evidence / ordersTotal) * 1000) / 10,
      dispatchRate: ordersTotal === 0 ? 0 : Math.round((ordersDispatched / ordersTotal) * 1000) / 10,
    };
  }
}
