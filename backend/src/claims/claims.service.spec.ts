import { ClaimsService } from './claims.service';

describe('ClaimsService', () => {
  it('list delegates to prisma', async () => {
    const prisma = {
      claim: { findMany: jest.fn().mockResolvedValue([{ id: '1' }]) },
    } as any;
    const svc = new ClaimsService(prisma);
    const rows = await svc.list('c1');
    expect(rows).toHaveLength(1);
  });
});
