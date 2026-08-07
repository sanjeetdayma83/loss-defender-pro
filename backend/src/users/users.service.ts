import {
  Injectable, NotFoundException, ConflictException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AuditService } from '../audit/audit.service';
import { InviteUserDto, UpdateUserDto } from './dto/user.dto';
import * as bcrypt from 'bcrypt';
import { randomBytes } from 'crypto';

@Injectable()
export class UsersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
  ) {}

  async list(companyId: string) {
    return this.prisma.user.findMany({
      where: {
        companyId,
        status: { not: 'deleted' },
      },
      select: {
        id: true,
        employeeId: true,
        email: true,
        name: true,
        phone: true,
        role: true,
        status: true,
        warehouseId: true,
        profilePhoto: true,
        joiningDate: true,
        lastLoginAt: true,
        createdAt: true,
        warehouse: { select: { id: true, name: true, code: true } },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async me(userId: string, companyId: string) {
    let user = await this.prisma.user.findFirst({
      where: {
        id: userId,
        companyId,
        status: { not: 'deleted' },
      },
      select: {
        id: true,
        employeeId: true,
        email: true,
        name: true,
        phone: true,
        role: true,
        status: true,
        warehouseId: true,
        profilePhoto: true,
        joiningDate: true,
        lastLoginAt: true,
        createdAt: true,
        warehouse: { select: { id: true, name: true, code: true } },
        company: { select: { id: true, companyName: true, plan: true } },
      },
    });

    if (!user) {
      user = await this.prisma.user.findFirst({
        where: {
          companyId,
          role: 'owner',
          status: { not: 'deleted' },
        },
        select: {
          id: true,
          employeeId: true,
          email: true,
          name: true,
          phone: true,
          role: true,
          status: true,
          warehouseId: true,
          profilePhoto: true,
          joiningDate: true,
          lastLoginAt: true,
          createdAt: true,
          warehouse: { select: { id: true, name: true, code: true } },
          company: { select: { id: true, companyName: true, plan: true } },
        },
      });
    }

    if (!user) throw new NotFoundException('User not found');
    return user;
  }

  async getOne(companyId: string, id: string) {
    const user = await this.prisma.user.findFirst({
      where: { id, companyId, status: { not: 'deleted' } },
      select: {
        id: true,
        employeeId: true,
        email: true,
        name: true,
        phone: true,
        role: true,
        status: true,
        warehouseId: true,
        profilePhoto: true,
        joiningDate: true,
        lastLoginAt: true,
        createdAt: true,
        warehouse: { select: { id: true, name: true, code: true } },
      },
    });
    if (!user) throw new NotFoundException('User not found');
    return user;
  }

  async invite(companyId: string, actorId: string, dto: InviteUserDto, ip?: string) {
    const exists = await this.prisma.user.findFirst({ where: { email: dto.email } });
    if (exists) throw new ConflictException('Email already registered');

    if (dto.warehouseId) {
      const wh = await this.prisma.warehouse.findFirst({
        where: { id: dto.warehouseId, companyId },
      });
      if (!wh) throw new NotFoundException('Warehouse not found');
    }

    const tempPass = randomBytes(8).toString('hex');
    const hash = await bcrypt.hash(tempPass, 12);

    const created = await this.prisma.user.create({
      data: {
        companyId,
        email: dto.email,
        name: dto.name,
        phone: dto.phone ?? '',
        role: dto.role,
        warehouseId: dto.warehouseId,
        passwordHash: hash,
        status: 'pending',
      },
      select: {
        id: true,
        email: true,
        name: true,
        phone: true,
        role: true,
        status: true,
        warehouseId: true,
        createdAt: true,
      },
    });

    await this.audit.log({
      companyId,
      actorId,
      action: 'user.invite',
      entity: 'User',
      entityId: created.id,
      after: created as any,
      ipAddress: ip,
    });

    return { ...created, tempPassword: tempPass };
  }

  async update(
    companyId: string,
    id: string,
    actorId: string,
    dto: UpdateUserDto,
    ip?: string,
  ) {
    const before = await this.prisma.user.findFirst({
      where: { id, companyId, status: { not: 'deleted' } },
    });
    if (!before) throw new NotFoundException('User not found');

    if (dto.warehouseId) {
      const wh = await this.prisma.warehouse.findFirst({
        where: { id: dto.warehouseId, companyId },
      });
      if (!wh) throw new NotFoundException('Warehouse not found');
    }

    const data: Record<string, unknown> = {};
    if (dto.name !== undefined) data.name = dto.name;
    if (dto.phone !== undefined) data.phone = dto.phone;
    if (dto.role !== undefined) data.role = dto.role;
    if (dto.warehouseId !== undefined) data.warehouseId = dto.warehouseId;
    if (dto.status !== undefined) data.status = dto.status;

    const updated = await this.prisma.user.update({
      where: { id },
      data,
      select: {
        id: true,
        email: true,
        name: true,
        phone: true,
        role: true,
        status: true,
        warehouseId: true,
        updatedAt: true,
      },
    });

    await this.audit.log({
      companyId,
      actorId,
      action: 'user.update',
      entity: 'User',
      entityId: id,
      before: before as any,
      after: updated as any,
      ipAddress: ip,
    });

    return updated;
  }
}
