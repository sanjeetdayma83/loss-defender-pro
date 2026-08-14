import { OrdersService } from '../orders/orders.service';
import { EvidenceService } from '../evidence/evidence.service';
import { ClaimsService } from '../claims/claims.service';
import { UsersService } from '../users/users.service';
import { ReturnsService } from '../returns/returns.service';
import { NotFoundException, ForbiddenException, BadRequestException } from '@nestjs/common';
import { Role, OrderStatus, Marketplace, OrderItemStatus, EvidenceStatus, ClaimStatus, ReturnStatus } from '@prisma/client';

function mockPrisma(overrides: any = {}) {
  return {
    order: {
      findMany: jest.fn(),
      findFirst: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
    },
    orderItem: {
      update: jest.fn(),
    },
    evidence: {
      findMany: jest.fn(),
      findFirst: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
    },
    claim: {
      findMany: jest.fn(),
      findFirst: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
    },
    user: {
      findMany: jest.fn(),
      findFirst: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
    },
    return: {
      findMany: jest.fn(),
      findFirst: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
    },
    warehouse: {
      findFirst: jest.fn(),
    },
    scanEvent: {
      findFirst: jest.fn().mockResolvedValue(null),
      create: jest.fn().mockImplementation(({ data }) =>
        Promise.resolve({ id: 'ev1', ...data, createdAt: new Date() }),
      ),
    },
    tokenBlacklist: {
      findFirst: jest.fn(),
    },
    auditLog: {
      create: jest.fn(),
    },
    inviteToken: {
      create: jest.fn(),
      findFirst: jest.fn(),
      update: jest.fn(),
    },
    ...overrides,
  };
}

describe('Cross-Tenant IDOR Unit Tests', () => {
  const companyA = 'company-a';
  const companyB = 'company-b';
  const warehouseA = 'warehouse-a';
  const warehouseB = 'warehouse-b';
  const userA = { id: 'user-a', companyId: companyA, role: Role.owner, warehouseId: warehouseA };
  const userB = { id: 'user-b', companyId: companyB, role: Role.owner, warehouseId: warehouseB };
  const operatorA = { id: 'op-a', companyId: companyA, role: Role.packing_operator, warehouseId: warehouseA };
  const operatorA2 = { id: 'op-a2', companyId: companyA, role: Role.packing_operator, warehouseId: 'warehouse-a2' };

  describe('OrdersService - Tenant Isolation', () => {
    let service: OrdersService;
    let prisma: any;

    beforeEach(() => {
      prisma = mockPrisma();
      service = new OrdersService(prisma as any);
    });

    it('list - returns only orders for user companyId', async () => {
      prisma.order.findMany.mockResolvedValue([
        { id: 'order-1', companyId: companyA, warehouseId: warehouseA },
        { id: 'order-2', companyId: companyA, warehouseId: warehouseA },
      ]);

      const result = await service.list(companyA, undefined, userA);

      expect(prisma.order.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({ companyId: companyA }),
        })
      );
      expect(result.every((o: any) => o.companyId === companyA)).toBe(true);
    });

    it('list - operator sees only their warehouse orders', async () => {
      prisma.order.findMany.mockResolvedValue([
        { id: 'order-1', companyId: companyA, warehouseId: warehouseA },
      ]);

      const result = await service.list(companyA, undefined, operatorA);

      expect(prisma.order.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({ companyId: companyA, warehouseId: warehouseA }),
        })
      );
      expect(result.every((o: any) => o.warehouseId === warehouseA)).toBe(true);
    });

    it('getOne - throws NotFound when order belongs to different company', async () => {
      prisma.order.findFirst.mockResolvedValue(null);

      await expect(service.getOne(companyA, 'order-b')).rejects.toThrow(NotFoundException);
      expect(prisma.order.findFirst).toHaveBeenCalledWith({
        where: { id: 'order-b', companyId: companyA },
        include: { items: true, warehouse: true },
      });
    });

    it('create - throws BadRequest when warehouseId belongs to different company', async () => {
      prisma.warehouse.findFirst.mockResolvedValue(null);

      await expect(
        service.create(companyA, userA.id, {
          warehouseId: warehouseB,
          items: [{ sku: 'SKU-1', name: 'Item', qty: 1 }],
        })
      ).rejects.toThrow(BadRequestException);
    });

    it('assign - throws NotFound when order belongs to different company', async () => {
      prisma.order.findFirst.mockResolvedValue(null);

      await expect(
        service.assign(companyA, 'order-b', userA.id, { operatorId: operatorA.id })
      ).rejects.toThrow(NotFoundException);
    });

    it('updateStatus - throws NotFound when order belongs to different company', async () => {
      prisma.order.findFirst.mockResolvedValue(null);

      await expect(
        service.updateStatus(companyA, 'order-b', userA.id, { status: OrderStatus.packing })
      ).rejects.toThrow(NotFoundException);
    });

    it('scan - throws NotFound when order belongs to different company', async () => {
      prisma.order.findFirst.mockResolvedValue(null);

      await expect(
        service.scan(companyA, 'order-b', userA.id, { barcodeOrSku: 'SKU-1' })
      ).rejects.toThrow(NotFoundException);
    });

    it('dispatch - throws NotFound when order belongs to different company', async () => {
      prisma.order.findFirst.mockResolvedValue(null);

      await expect(
        service.dispatch(companyA, 'order-b', 'AWB123')
      ).rejects.toThrow(NotFoundException);
    });
  });

  describe('EvidenceService - Tenant Isolation', () => {
    let service: EvidenceService;
    let prisma: any;

    beforeEach(() => {
      prisma = mockPrisma();
      service = new EvidenceService(prisma as any, {} as any);
    });

    it('list - returns only evidence for user companyId', async () => {
      prisma.evidence.findMany.mockResolvedValue([
        { id: 'ev-1', companyId: companyA },
        { id: 'ev-2', companyId: companyA },
      ]);

      const result = await service.list(companyA);

      expect(prisma.evidence.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({ companyId: companyA }),
        })
      );
      expect(result.every((e: any) => e.companyId === companyA)).toBe(true);
    });

    it('getOne - throws NotFound when evidence belongs to different company', async () => {
      prisma.evidence.findFirst.mockResolvedValue(null);

      await expect(service.getOne(companyA, 'ev-b')).rejects.toThrow(NotFoundException);
      expect(prisma.evidence.findFirst).toHaveBeenCalledWith({
        where: { id: 'ev-b', companyId: companyA },
        include: expect.any(Object),
      });
    });
  });

  describe('ClaimsService - Tenant Isolation', () => {
    let service: ClaimsService;
    let prisma: any;

    beforeEach(() => {
      prisma = mockPrisma();
      service = new ClaimsService(prisma as any);
    });

    it('list - returns only claims for user companyId', async () => {
      prisma.claim.findMany.mockResolvedValue([
        { id: 'claim-1', companyId: companyA },
        { id: 'claim-2', companyId: companyA },
      ]);

      const result = await service.list(companyA);

      expect(prisma.claim.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({ companyId: companyA }),
        })
      );
      expect(result.every((c: any) => c.companyId === companyA)).toBe(true);
    });

    it('getOne - throws NotFound when claim belongs to different company', async () => {
      prisma.claim.findFirst.mockResolvedValue(null);

      await expect(service.getOne(companyA, 'claim-b')).rejects.toThrow(NotFoundException);
      expect(prisma.claim.findFirst).toHaveBeenCalledWith({
        where: { id: 'claim-b', companyId: companyA },
      });
    });

    it('updateStatus - throws NotFound when claim belongs to different company', async () => {
      prisma.claim.findFirst.mockResolvedValue(null);

      await expect(
        service.updateStatus(companyA, 'actor', 'claim-b', 'closed')
      ).rejects.toThrow(NotFoundException);
    });
  });

  describe('UsersService - Tenant Isolation', () => {
    let service: UsersService;
    let prisma: any;

    beforeEach(() => {
      prisma = mockPrisma();
      service = new UsersService(prisma as any, {} as any, {} as any);
    });

    it('list - returns only users for user companyId', async () => {
      prisma.user.findMany.mockResolvedValue([
        { id: 'user-1', companyId: companyA },
        { id: 'user-2', companyId: companyA },
      ]);

      const result = await service.list(companyA);

      expect(prisma.user.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({ 
            companyId: companyA,
            status: { not: 'deleted' },
          }),
        })
      );
      expect(result.every((u: any) => u.companyId === companyA)).toBe(true);
    });

    it('getOne - throws NotFound when user belongs to different company', async () => {
      prisma.user.findFirst.mockResolvedValue(null);

      await expect(service.getOne(companyA, 'user-b')).rejects.toThrow(NotFoundException);
      expect(prisma.user.findFirst).toHaveBeenCalledWith({
        where: { id: 'user-b', companyId: companyA, status: { not: 'deleted' } },
        select: expect.any(Object),
      });
    });
  });

  describe('ReturnsService - Tenant Isolation', () => {
    let service: ReturnsService;
    let prisma: any;

    beforeEach(() => {
      prisma = mockPrisma();
      service = new ReturnsService(prisma as any);
    });

    it('list - returns only returns for user companyId', async () => {
      prisma.return.findMany.mockResolvedValue([
        { id: 'ret-1', companyId: companyA },
        { id: 'ret-2', companyId: companyA },
      ]);

      const result = await service.list(companyA);

      expect(prisma.return.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({ companyId: companyA }),
        })
      );
      expect(result.every((r: any) => r.companyId === companyA)).toBe(true);
    });

    it('updateStatus - throws NotFound when return belongs to different company', async () => {
      prisma.return.findFirst.mockResolvedValue(null);

      await expect(
        service.updateStatus(companyA, 'ret-b', 'received')
      ).rejects.toThrow(NotFoundException);
    });
  });

  describe('Warehouse Scope - Operator Isolation', () => {
    let service: OrdersService;
    let prisma: any;

    beforeEach(() => {
      prisma = mockPrisma();
      service = new OrdersService(prisma as any);
    });

    it('operator sees only their warehouse orders', async () => {
      prisma.order.findMany.mockResolvedValue([
        { id: 'order-1', companyId: companyA, warehouseId: warehouseA },
      ]);

      const result = await service.list(companyA, undefined, operatorA);

      expect(prisma.order.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({ 
            companyId: companyA, 
            warehouseId: warehouseA 
          }),
        })
      );
    });

    it('operator from different warehouse cannot see orders', async () => {
      prisma.order.findMany.mockResolvedValue([]);

      const result = await service.list(companyA, undefined, operatorA2);

      expect(prisma.order.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({ 
            companyId: companyA, 
            warehouseId: 'warehouse-a2' 
          }),
        })
      );
      expect(result).toEqual([]);
    });

    it('owner sees all warehouse orders', async () => {
      prisma.order.findMany.mockResolvedValue([
        { id: 'order-1', companyId: companyA, warehouseId: warehouseA },
        { id: 'order-2', companyId: companyA, warehouseId: 'warehouse-a2' },
      ]);

      const result = await service.list(companyA, undefined, userA);

      expect(prisma.order.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({ 
            companyId: companyA 
          }),
        })
      );
      expect(result.length).toBe(2);
    });

    it('operator cannot access order from different warehouse by ID', async () => {
      prisma.order.findFirst.mockResolvedValue(null);

      await expect(service.getOne(companyA, 'order-other-warehouse')).rejects.toThrow(NotFoundException);
      expect(prisma.order.findFirst).toHaveBeenCalledWith({
        where: { id: 'order-other-warehouse', companyId: companyA },
        include: { items: true, warehouse: true },
      });
    });
  });
});