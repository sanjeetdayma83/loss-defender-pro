import { MarketplaceService } from './marketplace.service';

describe('MarketplaceService', () => {
  it('list returns array', async () => {
    const prisma = {
      marketplaceConnection: {
        findMany: jest.fn().mockResolvedValue([]),
      },
    } as any;
    const svc = new MarketplaceService(prisma);
    const rows = await svc.list('c1');
    expect(Array.isArray(rows)).toBe(true);
  });

  it('syncOrders returns queued stub', async () => {
    const svc = new MarketplaceService({} as any);
    const res = await svc.syncOrders('c1', 'amazon');
    expect(res.status).toBe('queued');
    expect(res.provider).toBe('amazon');
  });

  it('handleWebhook accepts payload', async () => {
    const prisma = {
      marketplaceConnection: {
        updateMany: jest.fn().mockResolvedValue({ count: 0 }),
      },
    } as any;
    const svc = new MarketplaceService(prisma);
    const res = await svc.handleWebhook('amazon', { event: 'order.created', id: '1' });
    expect(res.received).toBe(true);
  });
});
