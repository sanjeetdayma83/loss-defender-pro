import { ForbiddenException } from '@nestjs/common';

/** Operator/viewer limited to assigned warehouse when user.warehouseId set */
export function warehouseScope(
  user: { role?: string; warehouseId?: string | null },
  extra: Record<string, unknown> = {},
) {
  const open = ['owner', 'admin', 'manager', 'super_admin', 'marketplace_manager'];
  if (user.warehouseId && user.role && !open.includes(user.role)) {
    return { warehouseId: user.warehouseId, ...extra };
  }
  return extra;
}

export function assertWarehouseAccess(
  user: { role?: string; warehouseId?: string | null },
  resourceWarehouseId: string | null | undefined,
) {
  const open = ['owner', 'admin', 'manager', 'super_admin', 'marketplace_manager'];
  if (!user.warehouseId || !user.role || open.includes(user.role)) return;
  if (resourceWarehouseId && resourceWarehouseId !== user.warehouseId) {
    throw new ForbiddenException('Warehouse scope denied');
  }
}
