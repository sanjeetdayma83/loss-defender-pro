import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

function jsonSafe(v: any): any {
  if (v === null || v === undefined) return v;
  if (typeof v === 'bigint') return v.toString();
  if (v instanceof Date) return v.toISOString();
  if (Array.isArray(v)) return v.map(jsonSafe);
  if (typeof v === 'object') {
    const o: any = {};
    for (const [k, val] of Object.entries(v)) o[k] = jsonSafe(val);
    return o;
  }
  return v;
}

@Injectable()
export class CompaniesService {
  constructor(private readonly prisma: PrismaService) {}

  async getMine(companyId: string) {
    const company = await this.prisma.company.findFirst({ where: { id: companyId } });
    if (!company) throw new NotFoundException('Company not found');
    return jsonSafe(company);
  }

  async updateMine(companyId: string, userId: string, dto: any, ip?: string) {
    const data: any = {};
    for (const k of ['name', 'displayName', 'logoUrl', 'primaryColor', 'phone', 'address']) {
      if (dto[k] !== undefined) data[k] = dto[k];
    }
    const company = await this.prisma.company.update({
      where: { id: companyId },
      data,
    });
    return jsonSafe(company);
  }

  async exportCompanyData(companyId: string) {
    const company = await this.prisma.company.findFirst({ where: { id: companyId } });
    if (!company) throw new NotFoundException('Company not found');

    const safe = async <T>(fn: () => Promise<T>, fallback: T): Promise<T> => {
      try { return await fn(); } catch { return fallback; }
    };

    const [users, warehouses, orders, claims, recordings, evidence] = await Promise.all([
      safe(() => this.prisma.user.findMany({
        where: { companyId },
        select: {
          id: true, email: true, name: true, role: true, status: true,
          phone: true, createdAt: true, lastLoginAt: true,
        },
      }), []),
      safe(() => this.prisma.warehouse.findMany({ where: { companyId } }), []),
      safe(() => this.prisma.order.findMany({
        where: { companyId },
        take: 500,
        include: { items: true },
        orderBy: { createdAt: 'desc' },
      }), []),
      safe(() => this.prisma.claim.findMany({ where: { companyId }, take: 200 }), []),
      safe(() => this.prisma.recording.findMany({
        where: { companyId },
        take: 200,
        select: {
          id: true, orderId: true, status: true, durationSec: true,
          segmentCount: true, totalBytes: true, createdAt: true,
        },
      }), []),
      safe(() => this.prisma.evidence.findMany({
        where: { companyId },
        take: 200,
        select: {
          id: true, recordingId: true, orderId: true, status: true,
          frameCount: true, packKey: true, createdAt: true,
        },
      }), []),
    ]);

    return jsonSafe({
      exportedAt: new Date().toISOString(),
      company,
      users,
      warehouses,
      orders,
      claims,
      recordings,
      evidence,
    });
  }
}
