import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class StationsService {
  constructor(private readonly prisma: PrismaService) {}

  private async assertWarehouse(companyId: string, warehouseId: string) {
    const wh = await this.prisma.warehouse.findFirst({ where: { id: warehouseId, companyId } });
    if (!wh) throw new BadRequestException('Warehouse not in your company');
    return wh;
  }

  async list(companyId: string, warehouseId?: string) {
    const warehouses = await this.prisma.warehouse.findMany({
      where: { companyId, ...(warehouseId ? { id: warehouseId } : {}) },
      select: { id: true },
    });
    const ids = warehouses.map((w) => w.id);
    if (!ids.length) return [];
    return this.prisma.station.findMany({
      where: { warehouseId: { in: ids } },
      orderBy: { createdAt: 'desc' },
      include: { warehouse: { select: { id: true, name: true, code: true } } },
    });
  }

  async create(
    companyId: string,
    data: { warehouseId: string; stationName: string; stationId: string; status?: string },
  ) {
    await this.assertWarehouse(companyId, data.warehouseId);
    return this.prisma.station.create({
      data: {
        warehouseId: data.warehouseId,
        stationName: data.stationName,
        stationId: data.stationId,
        status: (data.status as any) || 'offline',
      },
    });
  }

  async update(
    companyId: string,
    id: string,
    data: { stationName?: string; status?: string },
  ) {
    const row = await this.prisma.station.findFirst({
      where: { id },
      include: { warehouse: true },
    });
    if (!row || row.warehouse.companyId !== companyId) {
      throw new NotFoundException('Station not found');
    }
    return this.prisma.station.update({
      where: { id },
      data: {
        ...(data.stationName != null ? { stationName: data.stationName } : {}),
        ...(data.status != null ? { status: data.status as any } : {}),
      },
    });
  }
}