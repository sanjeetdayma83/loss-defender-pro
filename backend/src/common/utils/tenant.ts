import { ForbiddenException } from '@nestjs/common';

export function tenantWhere(companyId: string, extra: Record<string, unknown> = {}) {
  if (!companyId) throw new ForbiddenException('Tenant context missing');
  return { companyId, ...extra };
}

export function assertSameTenant(resourceCompanyId: string, jwtCompanyId: string) {
  if (resourceCompanyId !== jwtCompanyId) {
    throw new ForbiddenException('Cross-tenant access denied');
  }
}
