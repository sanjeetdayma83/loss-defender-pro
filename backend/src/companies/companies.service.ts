import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { UpdateCompanyDto } from './dto/update-company.dto';
import { AuditService } from '../audit/audit.service';

@Injectable()
export class CompaniesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
  ) {}

  async getMine(companyId: string) {
    const company = await this.prisma.company.findFirst({
      where: { id: companyId, status: { not: 'deleted' } },
      select: {
        id: true,
        companyName: true,
        gst: true,
        pan: true,
        address: true,
        phone: true,
        email: true,
        website: true,
        timezone: true,
        currency: true,
        storageUsed: true,
        storageQuota: true,
        plan: true,
        logo: true,
        status: true,
        createdAt: true,
        updatedAt: true,
      },
    });
    if (!company) throw new NotFoundException('Company not found');
    return {
      ...company,
      storageUsed: company.storageUsed.toString(),
      storageQuota: company.storageQuota.toString(),
    };
  }

  async updateMine(companyId: string, actorId: string, dto: UpdateCompanyDto, ip?: string) {
    const before = await this.prisma.company.findFirst({
      where: { id: companyId, status: { not: 'deleted' } },
    });
    if (!before) throw new NotFoundException('Company not found');

    const data: Prisma.CompanyUpdateInput = {
      companyName: dto.companyName,
      gst: dto.gst,
      pan: dto.pan,
      phone: dto.phone,
      website: dto.website,
      timezone: dto.timezone,
      currency: dto.currency,
      logo: dto.logo,
    };
    if (dto.address !== undefined) {
      data.address = dto.address as Prisma.InputJsonValue;
    }

    const updated = await this.prisma.company.update({
      where: { id: companyId },
      data,
      select: {
        id: true,
        companyName: true,
        gst: true,
        pan: true,
        address: true,
        phone: true,
        email: true,
        website: true,
        timezone: true,
        currency: true,
        plan: true,
        logo: true,
        status: true,
        updatedAt: true,
      },
    });

    await this.audit.log({
      companyId,
      actorId,
      action: 'company.update',
      entity: 'Company',
      entityId: companyId,
      before: before as any,
      after: updated as any,
      ipAddress: ip,
    });

    return updated;
  }

  async exportCompanyData(companyId: string) {
    const [company, users, warehouses, orders, claims, recordings, evidence] =
      await Promise.all([
        this.prisma.company.findFirst({ where: { id: companyId } }),
        this.prisma.user.findMany({
          where: { companyId },
          select: {
            id: true, email: true, name: true, role: true, status: true,
            phone: true, createdAt: true, lastLoginAt: true,
          },
        }),
        this.prisma.warehouse.findMany({ where: { companyId } }),
        this.prisma.order.findMany({
          where: { companyId },
          take: 500,
          include: { items: true },
          orderBy: { createdAt: 'desc' },
        }),
        this.prisma.claim.findMany({ where: { companyId }, take: 200 }),
        this.prisma.recording.findMany({
          where: { companyId },
          take: 200,
          select: {
            id: true, orderId: true, status: true, durationSec: true,
            segmentCount: true, totalBytes: true, createdAt: true,
          },
        }),
        this.prisma.evidence.findMany({
          where: { companyId },
          take: 200,
          select: {
            id: true, recordingId: true, orderId: true, status: true,
            frameCount: true, packKey: true, createdAt: true,
          },
        }),
      ]);
    return {
      exportedAt: new Date().toISOString(),
      company, users, warehouses, orders, claims, recordings, evidence,
    };
  }
}