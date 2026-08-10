import { BillingService } from './billing.service';

describe('BillingService quota enforcement', () => {
  it('rejects a company over monthly order quota', async () => {
    const prisma = {
      company: { findFirst: jest.fn().mockResolvedValue({ id: 'c1', plan: 'free', storageUsed: 0 }) },
      order: { count: jest.fn().mockResolvedValue(500) },
    } as any;
    const service = new BillingService(prisma);
    await expect(service.assertOrderQuota('c1')).rejects.toThrow('Monthly order quota exceeded');
  });

  it('rejects storage above plan limit', async () => {
    const prisma = { company: { findFirst: jest.fn().mockResolvedValue({ id: 'c1', plan: 'free', storageUsed: BigInt(10 * 1024 ** 3) }) } } as any;
    const service = new BillingService(prisma);
    await expect(service.assertStorageQuota('c1', 1)).rejects.toThrow('Storage quota exceeded');
  });
});
