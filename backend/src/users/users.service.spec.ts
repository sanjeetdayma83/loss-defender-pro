import { UsersService } from './users.service';

describe('UsersService role security', () => {
  it('revokes all sessions when role changes', async () => {
    const before = {
      id: 'u1', companyId: 'c1', role: 'packing_operator', name: 'User', phone: '',
    };
    const updated = {
      id: 'u1', email: 'u@example.com', name: 'User', phone: '',
      role: 'manager', status: 'active', warehouseId: null, updatedAt: new Date(),
    };
    const prisma = {
      user: {
        findFirst: jest.fn().mockResolvedValue(before),
        update: jest.fn().mockResolvedValue(updated),
        findMany: jest.fn(),
      },
      warehouse: { findFirst: jest.fn() },
    } as any;
    const audit = { log: jest.fn().mockResolvedValue(undefined) } as any;
    const emailService = { sendInvite: jest.fn() } as any;
    const authService = { revokeAllSessions: jest.fn().mockResolvedValue({ revoked: true }) } as any;
    const service = new UsersService(prisma, audit, emailService, authService);

    await service.update('c1', 'u1', 'actor', { role: 'manager' } as any);

    expect(authService.revokeAllSessions).toHaveBeenCalledWith('u1');
    expect(audit.log).toHaveBeenCalledWith(expect.objectContaining({ action: 'user.role_changed' }));
  });

  it('does not revoke sessions for a non-role profile update', async () => {
    const before = {
      id: 'u1', companyId: 'c1', role: 'packing_operator', name: 'User', phone: '',
    };
    const updated = {
      id: 'u1', email: 'u@example.com', name: 'Updated', phone: '',
      role: 'packing_operator', status: 'active', warehouseId: null, updatedAt: new Date(),
    };
    const prisma = {
      user: { findFirst: jest.fn().mockResolvedValue(before), update: jest.fn().mockResolvedValue(updated) },
      warehouse: { findFirst: jest.fn() },
    } as any;
    const audit = { log: jest.fn().mockResolvedValue(undefined) } as any;
    const emailService = { sendInvite: jest.fn() } as any;
    const authService = { revokeAllSessions: jest.fn() } as any;
    const service = new UsersService(prisma, audit, emailService, authService);

    await service.update('c1', 'u1', 'actor', { name: 'Updated' } as any);

    expect(authService.revokeAllSessions).not.toHaveBeenCalled();
  });
});
