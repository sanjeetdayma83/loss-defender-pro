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
}
