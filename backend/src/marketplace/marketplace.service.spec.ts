import { MarketplaceService } from './marketplace.service';

describe('MarketplaceService', () => {
  it('list calls findMany with companyId', async () => {
    const prisma = {
      marketplaceConnection: {
        findMany: jest.fn().mockResolvedValue([]),
      },
    };
    const svc = new MarketplaceService(prisma as any);
    await svc.list('company-1');
    expect(prisma.marketplaceConnection.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { companyId: 'company-1' },
      }),
    );
  });
});