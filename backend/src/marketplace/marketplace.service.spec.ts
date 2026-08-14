import { MarketplaceService } from './marketplace.service';
import * as crypto from 'crypto';

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

  it('syncOrders returns not_configured when no connection', async () => {
    const prisma = {
      marketplaceConnection: {
        findFirst: jest.fn().mockResolvedValue(null),
      },
    } as any;
    const svc = new MarketplaceService(prisma);
    const res = await svc.syncOrders('c1', 'amazon');
    expect(res.status).toBe('not_configured');
    expect(res.provider).toBe('amazon');
    expect(res.imported).toBe(0);
  });

  it('handleWebhook rejects when no secret configured', async () => {
    const prisma = { marketplaceConnection: { updateMany: jest.fn() } } as any;
    const svc = new MarketplaceService(prisma);
    delete process.env.WEBHOOK_SECRET;
    delete process.env.WEBHOOK_SECRET_AMAZON;
    await expect(
      svc.handleWebhook('amazon', { event: 'order.created', id: '1' }, 'any-sig'),
    ).rejects.toThrow('Webhook secret not configured');
  });

  it('handleWebhook rejects when signature header missing', async () => {
    const prisma = { marketplaceConnection: { updateMany: jest.fn() } } as any;
    const svc = new MarketplaceService(prisma);
    process.env.WEBHOOK_SECRET = 'test-secret';
    await expect(
      svc.handleWebhook('amazon', { event: 'order.created', id: '1' }, undefined),
    ).rejects.toThrow('Missing webhook signature');
  });

  it('handleWebhook rejects an invalid signature', async () => {
    const prisma = { marketplaceConnection: { updateMany: jest.fn() } } as any;
    const svc = new MarketplaceService(prisma);
    process.env.WEBHOOK_SECRET = 'test-secret';
    await expect(
      svc.handleWebhook('amazon', { event: 'order.created', id: '1' }, 'deadbeef'),
    ).rejects.toThrow('Invalid webhook signature');
  });

  it('handleWebhook accepts a correctly HMAC-signed payload', async () => {
    const prisma = {
      marketplaceConnection: {
        updateMany: jest.fn().mockResolvedValue({ count: 0 }),
      },
    } as any;
    const svc = new MarketplaceService(prisma);
    process.env.WEBHOOK_SECRET = 'test-secret';
    const body = { event: 'order.created', id: '1' };
    const sig = crypto
      .createHmac('sha256', 'test-secret')
      .update(JSON.stringify(body))
      .digest('hex');
    const res = await svc.handleWebhook('amazon', body, sig);
    expect(res.received).toBe(true);
    expect(res.provider).toBe('amazon');
  });
});