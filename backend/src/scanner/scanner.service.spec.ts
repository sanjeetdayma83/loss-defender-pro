import { ScannerService } from './scanner.service';
import { ConflictException, NotFoundException } from '@nestjs/common';

describe('ScannerService', () => {
  const companyId = 'c1';
  const orderId = 'o1';
  const operatorId = 'u1';

  function mockPrisma(overrides: any = {}) {
    return {
      order: {
        findFirst: jest.fn(),
        update: jest.fn(),
      },
      orderItem: {
        update: jest.fn(),
      },
      scanEvent: {
        findFirst: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockImplementation(({ data }) =>
          Promise.resolve({ id: 'ev1', ...data, createdAt: new Date() }),
        ),
      },
      ...overrides,
    };
  }

  it('throws NotFound when order missing', async () => {
    const prisma = mockPrisma();
    prisma.order.findFirst.mockResolvedValue(null);
    const svc = new ScannerService(prisma as any);
    await expect(
      svc.scan(companyId, operatorId, orderId, 'SKU-1'),
    ).rejects.toBeInstanceOf(NotFoundException);
  });

  it('updates scannedQty on match', async () => {
    const item = {
      id: 'i1',
      sku: 'SKU-1',
      barcode: null,
      qty: 2,
      scannedQty: 0,
    };
    const prisma = mockPrisma();
    prisma.order.findFirst
      .mockResolvedValueOnce({
        id: orderId,
        status: 'queued',
        items: [item],
      })
      .mockResolvedValueOnce({
        id: orderId,
        status: 'packing',
        items: [{ ...item, scannedQty: 1 }],
      });
    prisma.orderItem.update.mockResolvedValue({});
    prisma.order.update.mockResolvedValue({});

    const svc = new ScannerService(prisma as any);
    const res = await svc.scan(companyId, operatorId, orderId, 'SKU-1');

    expect(res.result).toBe('matched');
    expect(res.scan.scannedQty).toBe(1);
    expect(prisma.orderItem.update).toHaveBeenCalled();
    expect(prisma.scanEvent.create).toHaveBeenCalled();
  });

  it('rejects duplicate barcode', async () => {
    const prisma = mockPrisma();
    prisma.order.findFirst.mockResolvedValue({
      id: orderId,
      status: 'packing',
      items: [{ id: 'i1', sku: 'SKU-1', qty: 2, scannedQty: 0 }],
    });
    prisma.scanEvent.findFirst.mockResolvedValue({
      id: 'old',
      createdAt: new Date(),
    });

    const svc = new ScannerService(prisma as any);
    await expect(
      svc.scan(companyId, operatorId, orderId, 'SKU-1'),
    ).rejects.toBeInstanceOf(ConflictException);
  });
});