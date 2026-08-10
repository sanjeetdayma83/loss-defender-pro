import { Controller, Get } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CurrentUser, AuthenticatedUser } from '../common/decorators/current-user.decorator';

@Controller('supervisor')
export class SupervisorController {
  constructor(private readonly prisma: PrismaService) {}
  @Get('live')
  async live(@CurrentUser() u: AuthenticatedUser) {
    const companyId = u.companyId;
    const recordings = await this.prisma.recording.findMany({
      where: { companyId, status: { in: ['started', 'paused'] as any } },
      take: 20,
      orderBy: { updatedAt: 'desc' },
    });
    const orders = await this.prisma.order.findMany({
      where: { companyId, status: { in: ['packing', 'recording', 'scanned'] as any } },
      take: 30,
      orderBy: { updatedAt: 'desc' },
    });
    return {
      activeRecordings: recordings.length,
      packingOrders: orders.length,
      recordings,
      orders,
    };
  }
}
