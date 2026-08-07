import {
  Injectable,
  NotFoundException,
  ConflictException,
  ForbiddenException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AuditService } from '../audit/audit.service';
import {
  CreateWarehouseDto,
  UpdateWarehouseDto,
  CreateStationDto,
  UpdateStationDto,
} from './dto/warehouse.dto';

@Injectable()
export class WarehousesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
  ) {}

  list(companyId: string) {
    return this.prisma.warehouse.findMany({
      where: { companyId },
      include: {
        stations: {
          select: {
            id: true,
            stationName: true,
            stationId: true,
            status: true,
            lastHeartbeatAt: true,
          },
        },
        _count: { select: { users: true, stations: true } },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async getOne(companyId: string, id: string) {
    const wh = await this.prisma.warehouse.findFirst({
      where: { id, companyId },
      include: { stations: true },
    });
    if (!wh) throw new NotFoundException('Warehouse not found');
    return wh;
  }

  async create(companyId: string, actorId: string, dto: CreateWarehouseDto, ip?: string) {
    const exists = await this.prisma.warehouse.findFirst({
      where: { companyId, code: dto.code },
    });
    if (exists) throw new ConflictException(`Warehouse code "${dto.code}" already exists`);

    const created = await this.prisma.warehouse.create({
      data: {
        companyId,
        name: dto.name,
        code: dto.code,
        address: dto.address as any,
        city: dto.city,
        state: dto.state,
        country: dto.country ?? 'India',
        timezone: dto.timezone,
      },
    });

    await this.audit.log({
      companyId,
      actorId,
      action: 'warehouse.create',
      entity: 'Warehouse',
      entityId: created.id,
      after: created as any,
      ipAddress: ip,
    });

    return created;
  }

  async update(
    companyId: string,
    id: string,
    actorId: string,
    dto: UpdateWarehouseDto,
    ip?: string,
  ) {
    const before = await this.prisma.warehouse.findFirst({ where: { id, companyId } });
    if (!before) throw new NotFoundException('Warehouse not found');

    const updated = await this.prisma.warehouse.update({
      where: { id },
      data: { ...dto, address: dto.address as any },
    });

    await this.audit.log({
      companyId,
      actorId,
      action: 'warehouse.update',
      entity: 'Warehouse',
      entityId: id,
      before: before as any,
      after: updated as any,
      ipAddress: ip,
    });

    return updated;
  }

  async createStation(
    companyId: string,
    warehouseId: string,
    actorId: string,
    dto: CreateStationDto,
    ip?: string,
  ) {
    const wh = await this.prisma.warehouse.findFirst({ where: { id: warehouseId, companyId } });
    if (!wh) throw new NotFoundException('Warehouse not found');

    const exists = await this.prisma.station.findFirst({
      where: { warehouseId, stationId: dto.stationId },
    });
    if (exists) throw new ConflictException(`Station ID "${dto.stationId}" already exists`);

    const created = await this.prisma.station.create({
      data: {
        warehouseId,
        stationName: dto.stationName,
        stationId: dto.stationId,
        camera: dto.camera as any,
        scanner: dto.scanner as any,
        printer: dto.printer as any,
      },
    });

    await this.audit.log({
      companyId,
      actorId,
      action: 'station.create',
      entity: 'Station',
      entityId: created.id,
      after: created as any,
      ipAddress: ip,
    });

    return created;
  }

  async updateStation(
    companyId: string,
    warehouseId: string,
    stationUuid: string,
    actorId: string,
    dto: UpdateStationDto,
    ip?: string,
  ) {
    const wh = await this.prisma.warehouse.findFirst({ where: { id: warehouseId, companyId } });
    if (!wh) throw new NotFoundException('Warehouse not found');

    const before = await this.prisma.station.findFirst({
      where: { id: stationUuid, warehouseId },
    });
    if (!before) throw new NotFoundException('Station not found');

    const updated = await this.prisma.station.update({
      where: { id: stationUuid },
      data: {
        ...dto,
        camera: dto.camera as any,
        scanner: dto.scanner as any,
        printer: dto.printer as any,
      },
    });

    await this.audit.log({
      companyId,
      actorId,
      action: 'station.update',
      entity: 'Station',
      entityId: stationUuid,
      before: before as any,
      after: updated as any,
      ipAddress: ip,
    });

    return updated;
  }

  async heartbeat(companyId: string, warehouseId: string, stationUuid: string) {
    const wh = await this.prisma.warehouse.findFirst({ where: { id: warehouseId, companyId } });
    if (!wh) throw new ForbiddenException('Warehouse not in your company');

    const station = await this.prisma.station.findFirst({
      where: { id: stationUuid, warehouseId },
    });
    if (!station) throw new NotFoundException('Station not found');

    return this.prisma.station.update({
      where: { id: stationUuid },
      data: { lastHeartbeatAt: new Date(), status: 'online' },
    });
  }
}
