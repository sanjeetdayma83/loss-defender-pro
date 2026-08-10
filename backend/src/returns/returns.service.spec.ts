import { ReturnsService } from './returns.service';
import { BadRequestException, NotFoundException } from '@nestjs/common';

describe('ReturnsService', () => {
  const companyId = 'c1';
  const orderId = 'o1';

  function mockPrisma() {
    return {
      order: { findFirst: jest.fn() },
      return: {
        findMany: jest.fn().mockResolvedValue([]),
        findFirst: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
      },
    };
  }

  it('creates return with requested status', async () => {
    const prisma = mockPrisma();
    prisma.order.findFirst.mockResolvedValue({ id: orderId });
    prisma.return.create.mockImplementation(({ data }) =>
      Promise.resolve({ id: 'r1', ...data }),
    );
    const svc = new ReturnsService(prisma as any);
    const row = await svc.create(companyId, { orderId, reason: 'damaged' });
    expect(row.status).toBe('requested');
    expect(prisma.return.create).toHaveBeenCalled();
  });

  it('blocks invalid transition', async () => {
    const prisma = mockPrisma();
    prisma.return.findFirst.mockResolvedValue({
      id: 'r1',
      companyId,
      status: 'received',
    });
    const svc = new ReturnsService(prisma as any);
    await expect(
      svc.updateStatus(companyId, 'r1', 'received'),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('allows received → inspecting', async () => {
    const prisma = mockPrisma();
    prisma.return.findFirst.mockResolvedValue({
      id: 'r1',
      companyId,
      status: 'received',
    });
    prisma.return.update.mockImplementation(({ data }) =>
      Promise.resolve({ id: 'r1', status: data.status }),
    );
    const svc = new ReturnsService(prisma as any);
    const row = await svc.updateStatus(companyId, 'r1', 'inspecting');
    expect(row.status).toBe('inspecting');
  });

  it('404 when missing', async () => {
    const prisma = mockPrisma();
    prisma.return.findFirst.mockResolvedValue(null);
    const svc = new ReturnsService(prisma as any);
    await expect(
      svc.updateStatus(companyId, 'x', 'inspecting'),
    ).rejects.toBeInstanceOf(NotFoundException);
  });
});
