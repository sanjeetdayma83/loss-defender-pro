import { MarketplaceService } from './marketplace.service';
import { createHmac } from 'crypto';

describe('MarketplaceService', () => {
  const crypto = {
    encrypt: jest.fn((value?: string) => (value ? `enc:${value}` : undefined)),
    decrypt: jest.fn((value?: string) => (value ? String(value).replace(/^enc:/, '') : undefined)),
  } as any;

  it('list returns array', async () => {
    const prisma = {
      marketplaceConnection: { findMany: jest.fn().mockResolvedValue([]) },
    } as any;
    const svc = new MarketplaceService(prisma, crypto);
    const rows = await svc.list('c1');
    expect(Array.isArray(rows)).toBe(true);
  });

  it('refuses Amazon sync when required SP-API credentials are missing', async () => {
    const prisma = {
      marketplaceConnection: {
        findFirst: jest.fn().mockResolvedValue({
          id: 'mc1',
          companyId: 'c1',
          provider: 'amazon',
          status: 'connected',
          accessToken: 'enc:token',
          refreshToken: null,
          meta: null,
        }),
      },
    } as any;
    const svc = new MarketplaceService(prisma, crypto);
    await expect(svc.syncOrders('c1', 'amazon')).rejects.toThrow(
      'Amazon SP-API is not configured',
    );
  });

  it('refuses Meesho sync when official seller API configuration is missing', async () => {
    const prisma = {
      marketplaceConnection: {
        findFirst: jest.fn().mockResolvedValue({
          id: 'mc2',
          companyId: 'c1',
          provider: 'meesho',
          status: 'connected',
          accessToken: null,
          refreshToken: null,
          meta: null,
        }),
      },
    } as any;
    const svc = new MarketplaceService(prisma, crypto);
    await expect(svc.syncOrders('c1', 'meesho')).rejects.toThrow(
      'Meesho API is not configured',
    );
  });

  it('rejects webhook without a signature', async () => {
    const prisma = { marketplaceConnection: { findMany: jest.fn() } } as any;
    const svc = new MarketplaceService(prisma, crypto);
    await expect(svc.handleWebhook('amazon', { event: 'order.created', id: '1' })).rejects.toThrow('Webhook signature is required');
    expect(prisma.marketplaceConnection.findMany).not.toHaveBeenCalled();
  });

  it('accepts a correctly signed webhook', async () => {
    const secret = 'test-webhook-secret';
    const body = { event: 'order.created', id: '1' };
    const raw = JSON.stringify(body);
    const signature = createHmac('sha256', secret).update(raw).digest('hex');
    const prisma = {
      marketplaceConnection: {
        findMany: jest.fn().mockResolvedValue([
          { id: 'mc1', companyId: 'c1', webhookSecret: `enc:${secret}` },
        ]),
        update: jest.fn().mockResolvedValue({}),
      },
    } as any;
    const svc = new MarketplaceService(prisma, crypto);
    const res = await svc.handleWebhook('amazon', body, `sha256=${signature}`);
    expect(res.received).toBe(true);
    expect(res.companyId).toBe('c1');
    expect(prisma.marketplaceConnection.update).toHaveBeenCalled();
  });
});
