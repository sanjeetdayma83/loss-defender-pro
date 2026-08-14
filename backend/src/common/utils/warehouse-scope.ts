import { ForbiddenException } from '@nestjs/common';

const OPEN_ROLES = new Set([
  'owner', 'admin', 'manager', 'super_admin', 'marketplace_manager', 'warehouse_manager',
]);

export function warehouseScope(
  user: { role?: string; warehouseId?: string | null },
  extra: Record<string, unknown> = {},
): Record<string, unknown> {
  if (user?.warehouseId && user.role && !OPEN_ROLES.has(user.role)) {
    return { warehouseId: user.warehouseId, ...extra };
  }
  return { ...extra };
}

export function assertWarehouseAccess(
  user: { role?: string; warehouseId?: string | null },
  resourceWarehouseId?: string | null,
) {
  if (!user?.warehouseId || !user.role || OPEN_ROLES.has(user.role)) return;
  if (resourceWarehouseId && resourceWarehouseId !== user.warehouseId) {
    throw new ForbiddenException('Warehouse scope denied');
  }
}
